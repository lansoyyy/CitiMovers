import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'booking_service.dart';
import 'storage_service.dart';

// ─────────────────────────── enums ───────────────────────────

enum DeliveryQueueOpType { photoUpload, statusUpdate, photoRecord }

enum DeliverySyncStatus {
  /// Queue is empty and nothing is in flight.
  idle,

  /// Actively trying to flush the queue.
  syncing,

  /// Queue has items but is not currently syncing.
  hasPending,
}

// ─────────────────────────── model ───────────────────────────

class DeliveryQueueEntry {
  final String id;
  final DeliveryQueueOpType type;
  final String bookingId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;

  const DeliveryQueueEntry({
    required this.id,
    required this.type,
    required this.bookingId,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  DeliveryQueueEntry copyWith({int? retryCount}) => DeliveryQueueEntry(
        id: id,
        type: type,
        bookingId: bookingId,
        payload: payload,
        createdAt: createdAt,
        retryCount: retryCount ?? this.retryCount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'bookingId': bookingId,
        'payload': payload,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'retryCount': retryCount,
      };

  factory DeliveryQueueEntry.fromJson(Map<String, dynamic> j) =>
      DeliveryQueueEntry(
        id: j['id'] as String,
        type: DeliveryQueueOpType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => DeliveryQueueOpType.photoUpload,
        ),
        bookingId: j['bookingId'] as String,
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
        retryCount: (j['retryCount'] as int?) ?? 0,
      );
}

// ─────────────────────────── service ───────────────────────────

/// Offline-first delivery operation queue.
///
/// All Firebase Storage photo uploads that occur from **Pick-up Arrival**
/// onwards are persisted locally in [GetStorage] and automatically retried
/// every [syncIntervalMinutes] minutes (default: 10).
///
/// The queue also reacts to connectivity-restored events, attempting a flush
/// immediately when the device goes back online.
///
/// Firestore status writes go through Firebase's own built-in offline
/// persistence, so they are already handled without this queue.
class DeliveryQueueService {
  // ─── singleton ───
  static final DeliveryQueueService instance = DeliveryQueueService._();
  DeliveryQueueService._();

  // ─── config ───
  static const _queueKey = 'delivery_queue_v1';
  static const int syncIntervalMinutes = 10;

  // ─── dependencies ───
  final GetStorage _box = GetStorage();
  final StorageService _storageService = StorageService();
  final BookingService _bookingService = BookingService();
  final Connectivity _connectivity = Connectivity();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── state ───
  Timer? _syncTimer;
  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  final ValueNotifier<int> pendingCountNotifier = ValueNotifier(0);
  final ValueNotifier<DeliverySyncStatus> statusNotifier =
      ValueNotifier(DeliverySyncStatus.idle);
  final ValueNotifier<DateTime?> lastSyncNotifier = ValueNotifier(null);

  /// Callbacks fired when a queued photo resolves a Cloud Storage URL.
  /// Key format: `'${bookingId}__${firestoreStage}'`
  final _urlCallbacks = <String, void Function(String url)>{};

  // ─────────────────────────── lifecycle ───────────────────────────

  /// Start the background sync service. Call once in screen [initState].
  Future<void> start() async {
    await GetStorage.init();
    _updatePendingCount();

    // React to connectivity changes
    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        debugPrint('[DeliveryQueue] Connectivity restored — flushing queue.');
        _flush();
      }
    });

    // Periodic 10-minute flush
    _syncTimer = Timer.periodic(
      const Duration(minutes: syncIntervalMinutes),
      (_) {
        debugPrint('[DeliveryQueue] 10-min timer fired — flushing queue.');
        _flush();
      },
    );

    // Best-effort immediate flush in case items remain from a previous session
    _flush();
  }

  /// Stop the service and release resources. Call in screen [dispose].
  void stop() {
    _syncTimer?.cancel();
    _connectivitySub?.cancel();
    _urlCallbacks.clear();
    debugPrint('[DeliveryQueue] Service stopped.');
  }

  // ─────────────────────────── public API ───────────────────────────

  /// Register a callback that fires once [firestoreStage] URL is resolved for
  /// [bookingId].  The callback is **not** cleared automatically after firing;
  /// call [removeUrlCallback] in [dispose] to prevent memory leaks.
  void onUrlResolved(
    String bookingId,
    String firestoreStage,
    void Function(String url) callback,
  ) {
    _urlCallbacks['${bookingId}__$firestoreStage'] = callback;
  }

  void removeUrlCallback(String bookingId, String firestoreStage) {
    _urlCallbacks.remove('${bookingId}__$firestoreStage');
  }

  /// Queue a Firebase Storage upload for [localFilePath].
  ///
  /// [storageStage] is used as the folder/filename hint in Firebase Storage
  /// (e.g. `'Start Loading'`).
  ///
  /// [firestoreStage] is the key stored in `deliveryPhotos` in Firestore
  /// (e.g. `'start_loading'`).
  ///
  /// After queuing, an immediate upload attempt is made.
  Future<void> enqueuePhotoUpload({
    required String bookingId,
    required String storageStage,
    required String firestoreStage,
    required String localFilePath,
  }) async {
    final entry = DeliveryQueueEntry(
      id: '${bookingId}__${firestoreStage}__${DateTime.now().millisecondsSinceEpoch}',
      type: DeliveryQueueOpType.photoUpload,
      bookingId: bookingId,
      payload: {
        'storageStage': storageStage,
        'firestoreStage': firestoreStage,
        'localFilePath': localFilePath,
      },
      createdAt: DateTime.now(),
    );
    await _enqueue(entry);
    _flush(); // best-effort immediate attempt
  }

  /// Queue a Firestore delivery-photo record when the URL is already known.
  Future<void> enqueuePhotoRecord({
    required String bookingId,
    required String firestoreStage,
    required String photoUrl,
  }) async {
    final entry = DeliveryQueueEntry(
      id: '${bookingId}__record_${firestoreStage}__${DateTime.now().millisecondsSinceEpoch}',
      type: DeliveryQueueOpType.photoRecord,
      bookingId: bookingId,
      payload: {
        'firestoreStage': firestoreStage,
        'photoUrl': photoUrl,
      },
      createdAt: DateTime.now(),
    );
    await _enqueue(entry);
    _flush();
  }

  /// Queue a booking status update for offline-first sync.
  Future<void> enqueueStatusUpdate({
    required String bookingId,
    required String status,
    String? driverId,
    String? subStep,
  }) async {
    final entry = DeliveryQueueEntry(
      id: '${bookingId}__status_${status}_${DateTime.now().millisecondsSinceEpoch}',
      type: DeliveryQueueOpType.statusUpdate,
      bookingId: bookingId,
      payload: {
        'status': status,
        'driverId': driverId,
        'subStep': subStep,
      },
      createdAt: DateTime.now(),
    );
    await _enqueue(entry);
    _flush(); // best-effort immediate attempt
  }

  // ─────────────────────────── force sync ───────────────────────────

  /// Block (poll) until all pending entries for [bookingId] are flushed or
  /// [timeout] expires.  Returns `true` when fully synced.
  Future<bool> forceSyncForBooking(
    String bookingId, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await _flush(specificBookingId: bookingId);
      final remaining = await _pendingForBooking(bookingId);
      if (remaining.isEmpty) return true;
      // Brief pause before retry
      await Future.delayed(const Duration(seconds: 4));
    }
    return (await _pendingForBooking(bookingId)).isEmpty;
  }

  /// Returns the number of pending entries for a specific booking.
  Future<int> pendingCountForBooking(String bookingId) async {
    return (await _pendingForBooking(bookingId)).length;
  }

  /// Returns a persistent directory for local delivery files.
  ///
  /// Unlike [Directory.systemTemp], files here survive app restarts.
  static Future<Directory> getLocalDeliveryDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/delivery_uploads');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  // ─────────────────────────── internals ───────────────────────────

  Future<List<DeliveryQueueEntry>> _pendingForBooking(String bookingId) async {
    return (await _loadQueue()).where((e) => e.bookingId == bookingId).toList();
  }

  Future<void> _enqueue(DeliveryQueueEntry entry) async {
    final queue = await _loadQueue();
    queue.add(entry);
    await _saveQueue(queue);
    _updatePendingCount();
    debugPrint(
        '[DeliveryQueue] Queued ${entry.type.name} for ${entry.bookingId}. '
        'Total pending: ${queue.length}');
  }

  Future<void> _flush({String? specificBookingId}) async {
    if (_isSyncing) return;
    _isSyncing = true;
    statusNotifier.value = DeliverySyncStatus.syncing;

    try {
      final queue = await _loadQueue();
      if (queue.isEmpty) {
        statusNotifier.value = DeliverySyncStatus.idle;
        _isSyncing = false;
        return;
      }

      final toProcess = specificBookingId != null
          ? queue.where((e) => e.bookingId == specificBookingId).toList()
          : List<DeliveryQueueEntry>.from(queue);

      final successIds = <String>{};

      for (final entry in toProcess) {
        try {
          final ok = await _executeEntry(entry);
          if (ok) {
            successIds.add(entry.id);
            debugPrint('[DeliveryQueue] ✅ ${entry.type.name} ${entry.id} done');
          } else {
            debugPrint(
                '[DeliveryQueue] ⏳ ${entry.type.name} ${entry.id} deferred');
          }
        } catch (e) {
          debugPrint(
              '[DeliveryQueue] ❌ ${entry.type.name} ${entry.id} error: $e');
        }
      }

      if (successIds.isNotEmpty) {
        final remaining =
            queue.where((e) => !successIds.contains(e.id)).toList();
        await _saveQueue(remaining);
        _updatePendingCount();
        lastSyncNotifier.value = DateTime.now();
      }

      final afterQueue = await _loadQueue();
      statusNotifier.value = afterQueue.isEmpty
          ? DeliverySyncStatus.idle
          : DeliverySyncStatus.hasPending;
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _executeEntry(DeliveryQueueEntry entry) async {
    switch (entry.type) {
      case DeliveryQueueOpType.photoUpload:
        return _executePhotoUpload(entry);
      case DeliveryQueueOpType.photoRecord:
        return _executePhotoRecord(entry);
      case DeliveryQueueOpType.statusUpdate:
        return _executeStatusUpdate(entry);
    }
  }

  Future<bool> _executePhotoUpload(DeliveryQueueEntry entry) async {
    final p = entry.payload;
    final storageStage = p['storageStage'] as String;
    final firestoreStage = p['firestoreStage'] as String;
    final localFilePath = p['localFilePath'] as String;

    final file = File(localFilePath);
    if (!file.existsSync()) {
      debugPrint(
          '[DeliveryQueue] Local file missing ($localFilePath) — dropping entry.');
      return true; // remove from queue; nothing to retry
    }

    final url = await _storageService.uploadDeliveryPhoto(
      file,
      entry.bookingId,
      storageStage,
    );

    if (url == null) return false; // keep in queue for next retry

    // Persist the URL to Firestore (offline-safe)
    await _bookingService.addDeliveryPhoto(
      bookingId: entry.bookingId,
      stage: firestoreStage,
      photoUrl: url,
    );

    // Notify any registered UI callback
    final cbKey = '${entry.bookingId}__$firestoreStage';
    _urlCallbacks[cbKey]?.call(url);

    return true;
  }

  Future<bool> _executePhotoRecord(DeliveryQueueEntry entry) async {
    final p = entry.payload;
    return _bookingService.addDeliveryPhoto(
      bookingId: entry.bookingId,
      stage: p['firestoreStage'] as String,
      photoUrl: p['photoUrl'] as String,
    );
  }

  Future<bool> _executeStatusUpdate(DeliveryQueueEntry entry) async {
    try {
      final p = entry.payload;
      final bookingId = entry.bookingId;
      final status = p['status'] as String?;
      final driverId = p['driverId'] as String?;
      final subStep = p['subStep'] as String?;

      if (status == null) {
        debugPrint('[DeliveryQueue] Status update missing status field');
        return true; // Remove from queue - invalid data
      }

      // Update booking status via BookingService
      final success = await _bookingService.updateBookingStatus(
        bookingId,
        status,
        driverId: driverId,
      );

      if (success) {
        debugPrint('[DeliveryQueue] ✅ Status updated: $bookingId -> $status');

        // If there's a subStep, update that as well (for loading/unloading steps)
        if (subStep != null) {
          await _firestore.collection('bookings').doc(bookingId).update({
            'currentSubStep': subStep,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        return true;
      } else {
        debugPrint(
            '[DeliveryQueue] ❌ Status update failed: $bookingId -> $status');
        return false; // Keep in queue for retry
      }
    } catch (e) {
      debugPrint('[DeliveryQueue] ❌ Status update error: $e');
      return false; // Keep in queue for retry
    }
  }

  // ─────────────────────────── storage helpers ───────────────────────────

  Future<List<DeliveryQueueEntry>> _loadQueue() async {
    try {
      final raw = _box.read(_queueKey);
      if (raw == null) return [];
      final list = (raw is String ? json.decode(raw) : raw) as List;
      return list
          .whereType<Map>()
          .map((m) => DeliveryQueueEntry.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      debugPrint('[DeliveryQueue] Error loading queue: $e');
      return [];
    }
  }

  Future<void> _saveQueue(List<DeliveryQueueEntry> queue) async {
    try {
      await _box.write(
          _queueKey, json.encode(queue.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('[DeliveryQueue] Error saving queue: $e');
    }
  }

  void _updatePendingCount() async {
    final q = await _loadQueue();
    pendingCountNotifier.value = q.length;
  }
}
