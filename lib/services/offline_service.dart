import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_storage/get_storage.dart';

/// Offline Service for CitiMovers
/// Provides offline support with connectivity monitoring, local caching, and operation queuing
class OfflineService {
  // Private constructor to prevent instantiation
  OfflineService._();

  // Singleton pattern
  static final OfflineService _instance = OfflineService._();
  factory OfflineService() => _instance;

  // Storage keys
  static const String _storageKey = 'offline_cache';
  static const String _queueKey = 'offline_queue';
  static const String _lastSyncKey = 'last_sync_time';

  // Cache expiration times (in minutes)
  static const int _cacheExpiryMedium = 30; // 30 minutes

  late final GetStorage _storage;
  late final Connectivity _connectivity;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  bool _isOnline = true;
  bool _isInitialized = false;

  // Connectivity status stream
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;

  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;

  /// Initialize the offline service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize GetStorage
      await GetStorage.init();
      _storage = GetStorage();

      // Initialize connectivity
      _connectivity = Connectivity();

      // Check initial connectivity status
      final result = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(result);

      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectivityStatus,
      );

      // Process any pending operations when coming online
      if (_isOnline) {
        _processPendingOperations();
      }

      _isInitialized = true;
      debugPrint('OfflineService: Initialized successfully');
    } catch (e) {
      debugPrint('OfflineService: Error initializing: $e');
    }
  }

  /// Update connectivity status
  void _updateConnectivityStatus(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    if (wasOnline != _isOnline) {
      debugPrint(
          'OfflineService: Connectivity changed to ${_isOnline ? "online" : "offline"}');
      _connectivityController.add(_isOnline);

      // Process pending operations when coming online
      if (_isOnline && !wasOnline) {
        _processPendingOperations();
      }
    }
  }

  /// Cache data locally with expiration
  Future<void> cacheData(
    String key,
    dynamic data, {
    int expiryMinutes = _cacheExpiryMedium,
  }) async {
    try {
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiry': expiryMinutes,
      };

      await _storage.write('$_storageKey.$key', json.encode(cacheData));
      debugPrint('OfflineService: Cached data for key: $key');
    } catch (e) {
      debugPrint('OfflineService: Error caching data: $e');
    }
  }

  /// Get cached data
  Future<T?> getCachedData<T>(String key) async {
    try {
      final cachedJson = await _storage.read('$_storageKey.$key');
      if (cachedJson == null) return null;

      final cacheData = json.decode(cachedJson) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      final expiry = cacheData['expiry'] as int;

      // Check if cache has expired
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      final expiryMs = expiry * 60 * 1000;

      if (cacheAge > expiryMs) {
        debugPrint('OfflineService: Cache expired for key: $key');
        await removeCachedData(key);
        return null;
      }

      debugPrint('OfflineService: Retrieved cached data for key: $key');
      return cacheData['data'] as T;
    } catch (e) {
      debugPrint('OfflineService: Error getting cached data: $e');
      return null;
    }
  }

  /// Remove cached data
  Future<void> removeCachedData(String key) async {
    try {
      await _storage.remove('$_storageKey.$key');
      debugPrint('OfflineService: Removed cached data for key: $key');
    } catch (e) {
      debugPrint('OfflineService: Error removing cached data: $e');
    }
  }

  /// Clear all cached data
  Future<void> clearAllCache() async {
    try {
      // Get all keys that start with storage key prefix
      final allKeys = await _storage.getKeys();
      final cacheKeys = <String>[];

      if (allKeys != null) {
        // Handle both List and single Object cases
        if (allKeys is List) {
          for (final key in allKeys) {
            if (key is String && key.startsWith('$_storageKey.')) {
              cacheKeys.add(key);
            }
          }
        } else if (allKeys is String) {
          if (allKeys.startsWith('$_storageKey.')) {
            cacheKeys.add(allKeys);
          }
        }
      }

      for (final key in cacheKeys) {
        await _storage.remove(key);
      }

      debugPrint('OfflineService: Cleared all cached data');
    } catch (e) {
      debugPrint('OfflineService: Error clearing cache: $e');
    }
  }

  /// Queue an operation for when online
  Future<void> queueOperation(OfflineOperation operation) async {
    try {
      final operations = await getPendingOperations();
      operations.add(operation);
      await _storage.write(_queueKey, json.encode(operations));
      debugPrint('OfflineService: Queued operation: ${operation.type}');
    } catch (e) {
      debugPrint('OfflineService: Error queuing operation: $e');
    }
  }

  /// Get all pending operations
  Future<List<OfflineOperation>> getPendingOperations() async {
    try {
      final queueJson = await _storage.read(_queueKey);
      if (queueJson == null) return [];

      final operationsList = json.decode(queueJson) as List;
      return operationsList
          .map((op) => OfflineOperation.fromJson(op as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('OfflineService: Error getting pending operations: $e');
      return [];
    }
  }

  /// Process all pending operations
  Future<void> _processPendingOperations() async {
    try {
      final operations = await getPendingOperations();
      if (operations.isEmpty) return;

      debugPrint(
          'OfflineService: Processing ${operations.length} pending operations');

      final successfulOperations = <String>[];
      final failedOperations = <OfflineOperation>[];

      for (final operation in operations) {
        try {
          final success = await _executeOperation(operation);
          if (success) {
            successfulOperations.add(operation.id);
          } else {
            failedOperations.add(operation);
          }
        } catch (e) {
          debugPrint('OfflineService: Error executing operation: $e');
          failedOperations.add(operation);
        }
      }

      // Remove successful operations from queue
      if (successfulOperations.isNotEmpty) {
        final remainingOperations = operations
            .where((op) => !successfulOperations.contains(op.id))
            .toList();
        await _storage.write(_queueKey, json.encode(remainingOperations));
        debugPrint(
            'OfflineService: Processed ${successfulOperations.length} operations');
      }

      // Update last sync time
      await _storage.write(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('OfflineService: Error processing pending operations: $e');
    }
  }

  /// Execute a single operation
  Future<bool> _executeOperation(OfflineOperation operation) async {
    debugPrint('OfflineService: Executing operation: ${operation.type}');

    // This is a placeholder - actual implementation would depend on operation type
    // Each operation type would have its own execution logic
    switch (operation.type) {
      case OfflineOperationType.createBooking:
        // TODO: Implement booking creation
        return true;
      case OfflineOperationType.updateBookingStatus:
        // TODO: Implement booking status update
        return true;
      case OfflineOperationType.uploadImage:
        // TODO: Implement image upload
        return true;
      case OfflineOperationType.updateProfile:
        // TODO: Implement profile update
        return true;
      default:
        return false;
    }
  }

  /// Clear all pending operations
  Future<void> clearPendingOperations() async {
    try {
      await _storage.remove(_queueKey);
      debugPrint('OfflineService: Cleared all pending operations');
    } catch (e) {
      debugPrint('OfflineService: Error clearing pending operations: $e');
    }
  }

  /// Get last sync time
  DateTime? getLastSyncTime() {
    try {
      final timestamp = _storage.read(_lastSyncKey) as int?;
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      debugPrint('OfflineService: Error getting last sync time: $e');
      return null;
    }
  }

  /// Force sync now
  Future<void> syncNow() async {
    if (!_isOnline) {
      debugPrint('OfflineService: Cannot sync while offline');
      return;
    }

    debugPrint('OfflineService: Forced sync initiated');
    await _processPendingOperations();
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final allKeys = await _storage.getKeys();
      final cacheKeys = <String>[];

      if (allKeys != null) {
        // Handle both List and single Object cases
        if (allKeys is List) {
          for (final key in allKeys) {
            if (key is String && key.startsWith('$_storageKey.')) {
              cacheKeys.add(key);
            }
          }
        } else if (allKeys is String) {
          if (allKeys.startsWith('$_storageKey.')) {
            cacheKeys.add(allKeys);
          }
        }
      }

      final operations = await getPendingOperations();
      final lastSync = getLastSyncTime();

      return {
        'cachedItems': cacheKeys.length,
        'pendingOperations': operations.length,
        'lastSyncTime': lastSync?.toIso8601String(),
        'isOnline': _isOnline,
      };
    } catch (e) {
      debugPrint('OfflineService: Error getting cache stats: $e');
      return {};
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }
}

/// Offline Operation Model
class OfflineOperation {
  final String id;
  final OfflineOperationType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;

  OfflineOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      id: json['id'] as String,
      type: OfflineOperationType.values.firstWhere(
        (e) => e.toString() == 'OfflineOperationType.${json['type']}',
        orElse: () => OfflineOperationType.unknown,
      ),
      data: json['data'] as Map<String, dynamic>,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'data': data,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'retryCount': retryCount,
    };
  }

  OfflineOperation copyWith({
    String? id,
    OfflineOperationType? type,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    int? retryCount,
  }) {
    return OfflineOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

/// Offline Operation Types
enum OfflineOperationType {
  createBooking,
  updateBookingStatus,
  uploadImage,
  updateProfile,
  unknown,
}

/// Offline Cache Helper
class OfflineCacheHelper {
  static const String bookingsKey = 'bookings';
  static const String savedLocationsKey = 'saved_locations';
  static const String userProfileKey = 'user_profile';
  static const String vehicleTypesKey = 'vehicle_types';
  static const String notificationsKey = 'notifications';

  /// Cache bookings
  static Future<void> cacheBookings(List<Map<String, dynamic>> bookings) async {
    final service = OfflineService();
    await service.cacheData(bookingsKey, bookings, expiryMinutes: 5);
  }

  /// Get cached bookings
  static Future<List<Map<String, dynamic>>?> getCachedBookings() async {
    final service = OfflineService();
    return await service.getCachedData<List<Map<String, dynamic>>>(bookingsKey);
  }

  /// Cache saved locations
  static Future<void> cacheSavedLocations(
      List<Map<String, dynamic>> locations) async {
    final service = OfflineService();
    await service.cacheData(savedLocationsKey, locations, expiryMinutes: 30);
  }

  /// Get cached saved locations
  static Future<List<Map<String, dynamic>>?> getCachedSavedLocations() async {
    final service = OfflineService();
    return await service
        .getCachedData<List<Map<String, dynamic>>>(savedLocationsKey);
  }

  /// Cache user profile
  static Future<void> cacheUserProfile(Map<String, dynamic> profile) async {
    final service = OfflineService();
    await service.cacheData(userProfileKey, profile, expiryMinutes: 30);
  }

  /// Get cached user profile
  static Future<Map<String, dynamic>?> getCachedUserProfile() async {
    final service = OfflineService();
    return await service.getCachedData<Map<String, dynamic>>(userProfileKey);
  }

  /// Cache vehicle types
  static Future<void> cacheVehicleTypes(
      List<Map<String, dynamic>> vehicles) async {
    final service = OfflineService();
    await service.cacheData(vehicleTypesKey, vehicles, expiryMinutes: 120);
  }

  /// Get cached vehicle types
  static Future<List<Map<String, dynamic>>?> getCachedVehicleTypes() async {
    final service = OfflineService();
    return await service
        .getCachedData<List<Map<String, dynamic>>>(vehicleTypesKey);
  }

  /// Cache notifications
  static Future<void> cacheNotifications(
      List<Map<String, dynamic>> notifications) async {
    final service = OfflineService();
    await service.cacheData(notificationsKey, notifications, expiryMinutes: 5);
  }

  /// Get cached notifications
  static Future<List<Map<String, dynamic>>?> getCachedNotifications() async {
    final service = OfflineService();
    return await service
        .getCachedData<List<Map<String, dynamic>>>(notificationsKey);
  }
}
