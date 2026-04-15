import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class AdminRepository {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const int _batchWriteLimit = 400;
  static const double _partnerNetRate = 0.80;
  static const double _adminFeeRate = 0.20;
  static const double _vatRate = 0.02;

  static bool _isMissing(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    return false;
  }

  static bool _needsUserBackfill(Map<String, dynamic> raw) {
    return !raw.containsKey('isSuspended') ||
        _isMissing(raw['accountStatus']) ||
        raw['walletBalance'] == null;
  }

  static bool _needsRiderDocumentsBackfill(Map<String, dynamic> raw) {
    final docs = _asMap(raw['documents']);
    for (final value in docs.values) {
      if (value is String) return true;
      final docMap = _asMap(value);
      if (_isMissing(docMap['status']) ||
          !docMap.containsKey('reviewedAt') ||
          !docMap.containsKey('reviewedBy') ||
          !docMap.containsKey('rejectionReason')) {
        return true;
      }
    }
    return false;
  }

  static bool _needsRiderBackfill(Map<String, dynamic> raw) {
    return !raw.containsKey('isSuspended') ||
        _isMissing(raw['accountStatus']) ||
        !raw.containsKey('isApproved') ||
        _needsRiderDocumentsBackfill(raw);
  }

  static bool _needsBookingBackfill(Map<String, dynamic> raw) {
    return _isMissing(raw['customerId']) ||
        _isMissing(raw['userId']) ||
        (!_isMissing(raw['riderId']) && _isMissing(raw['driverId'])) ||
        (!_isMissing(raw['driverId']) && _isMissing(raw['riderId'])) ||
        !raw.containsKey('issueNotesCount') ||
        !raw.containsKey('issueStatus') ||
        !raw.containsKey('reconciliationStatus') ||
        _isMissing(raw['tripNumber']) ||
        _isMissing(raw['tripDateKey']) ||
        _asInt(raw['tripSequence']) <= 0 ||
        raw['grossAmount'] == null ||
        raw['partnerNetRate'] == null ||
        raw['partnerNetAmount'] == null ||
        raw['adminFeeRate'] == null ||
        raw['adminFeeAmount'] == null ||
        raw['vatRate'] == null ||
        raw['vatAmount'] == null ||
        raw['adminNetAmount'] == null;
  }

  static String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month$day';
  }

  static String _normalizeTripDateKeyParts(
    String year,
    String first,
    String second, {
    DateTime? fallbackDate,
  }) {
    if (fallbackDate != null) {
      final month = fallbackDate.month.toString().padLeft(2, '0');
      final day = fallbackDate.day.toString().padLeft(2, '0');
      if ((first == month && second == day) ||
          (first == day && second == month)) {
        return '$year-$month$day';
      }
    }

    final firstInt = int.tryParse(first);
    final secondInt = int.tryParse(second);
    if (firstInt != null && secondInt != null) {
      if (firstInt > 12 && secondInt <= 12) {
        return '$year-$second$first';
      }
      if (secondInt > 12 && firstInt <= 12) {
        return '$year-$first$second';
      }
    }

    return '$year-$first$second';
  }

  static String _normalizeTripDateKey(
    dynamic rawValue, {
    DateTime? fallbackDate,
  }) {
    final value = _asString(rawValue);
    if (value.isNotEmpty) {
      final compactMatch = RegExp(r'^(\d{4})-(\d{4})$').firstMatch(value);
      if (compactMatch != null) return value;

      final dashedMatch = RegExp(
        r'^(\d{4})-(\d{2})-(\d{2})$',
      ).firstMatch(value);
      if (dashedMatch != null) {
        return _normalizeTripDateKeyParts(
          dashedMatch.group(1)!,
          dashedMatch.group(2)!,
          dashedMatch.group(3)!,
          fallbackDate: fallbackDate,
        );
      }

      final plainMatch = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(value);
      if (plainMatch != null) {
        return '${plainMatch.group(1)!}-${plainMatch.group(2)!}${plainMatch.group(3)!}';
      }
    }

    return fallbackDate != null ? _dateKey(fallbackDate) : '';
  }

  static String _normalizeTripNumber(
    dynamic rawValue, {
    required String tripDateKey,
    required int tripSequence,
    DateTime? fallbackDate,
  }) {
    final value = _asString(rawValue);
    if (value.isNotEmpty) {
      final compactMatch = RegExp(
        r'^(\d{4})-(\d{4})-(\d{5})$',
      ).firstMatch(value);
      if (compactMatch != null) {
        return value;
      }

      final dashedMatch = RegExp(
        r'^(\d{4})-(\d{2})-(\d{2})-(\d{5})$',
      ).firstMatch(value);
      if (dashedMatch != null) {
        final normalizedDateKey = _normalizeTripDateKeyParts(
          dashedMatch.group(1)!,
          dashedMatch.group(2)!,
          dashedMatch.group(3)!,
          fallbackDate: fallbackDate,
        );
        return '$normalizedDateKey-${dashedMatch.group(4)!}';
      }
    }

    if (tripDateKey.isNotEmpty && tripSequence > 0) {
      return _buildTripNumber(tripDateKey, tripSequence);
    }

    return '';
  }

  static String _buildTripNumber(String dateKey, int sequence) {
    return '$dateKey-${sequence.toString().padLeft(5, '0')}';
  }

  static Map<String, dynamic> _resolveBookingAccountingFields(
    String bookingId,
    Map<String, dynamic> raw,
  ) {
    final createdAt =
        parseTimestamp(raw['createdAt']) ??
        parseTimestamp(raw['scheduledDateTime']) ??
        DateTime.now();
    final tripDateKey = _normalizeTripDateKey(
      raw['tripDateKey'],
      fallbackDate: createdAt,
    );
    final tripSequence = _asInt(raw['tripSequence']);
    final estimatedFare = _asDouble(raw['estimatedFare']);
    final loadingDemurrageFee = _asDouble(raw['loadingDemurrageFee']);
    final unloadingDemurrageFee = _asDouble(raw['unloadingDemurrageFee']);
    final tipAmount = _asDouble(raw['tipAmount']);
    final computedFinalFare =
        estimatedFare + loadingDemurrageFee + unloadingDemurrageFee + tipAmount;
    final persistedFinalFare = _asDouble(raw['finalFare']);
    final persistedGrossAmount = _asDouble(raw['grossAmount']);
    final resolvedGrossAmount = [
      computedFinalFare,
      persistedFinalFare,
      persistedGrossAmount,
    ].reduce((a, b) => a > b ? a : b);
    final adminFeeAmount = raw['adminFeeAmount'] != null
        ? _asDouble(raw['adminFeeAmount'])
        : resolvedGrossAmount * _adminFeeRate;
    final vatAmount = raw['vatAmount'] != null
        ? _asDouble(raw['vatAmount'])
        : resolvedGrossAmount * _vatRate;
    final partnerNetAmount = raw['partnerNetAmount'] != null
        ? _asDouble(raw['partnerNetAmount'])
        : resolvedGrossAmount * _partnerNetRate;

    return {
      'tripDateKey': tripDateKey,
      'tripSequence': tripSequence,
      'tripNumber': _coalesceString([
        _normalizeTripNumber(
          _coalesceString([raw['tripNumber'], raw['trip_number']]),
          tripDateKey: tripDateKey,
          tripSequence: tripSequence,
          fallbackDate: createdAt,
        ),
        bookingId,
      ]),
      'grossAmount': resolvedGrossAmount,
      'partnerNetRate': raw['partnerNetRate'] ?? _partnerNetRate,
      'partnerNetAmount': partnerNetAmount,
      'adminFeeRate': raw['adminFeeRate'] ?? _adminFeeRate,
      'adminFeeAmount': adminFeeAmount,
      'vatRate': raw['vatRate'] ?? _vatRate,
      'vatAmount': vatAmount,
      'adminNetAmount': raw['adminNetAmount'] ?? (adminFeeAmount - vatAmount),
    };
  }

  // ─── Timestamp normalization ─────────────────────────────────────────────
  static DateTime? parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return <String, dynamic>{};
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static double? _asOptionalDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((entry) => entry?.toString().trim() ?? '')
          .where((entry) => entry.isNotEmpty)
          .toList();
    }
    if (value is Map) {
      return value.values
          .map((entry) => entry?.toString().trim() ?? '')
          .where((entry) => entry.isNotEmpty)
          .toList();
    }
    final single = _asString(value);
    return single.isEmpty ? <String>[] : <String>[single];
  }

  static String _coalesceString(List<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      final resolved = _asString(value);
      if (resolved.isNotEmpty) return resolved;
    }
    return fallback;
  }

  static String resolveRiderUnitName(Map<String, dynamic> raw) {
    final vehicle = _asMap(raw['vehicle']);
    return _coalesceString([
      raw['unitName'],
      raw['unitLabel'],
      raw['partnerName'],
      raw['companyName'],
      raw['fleetName'],
      raw['warehouseName'],
      raw['warehouse'],
      raw['groupName'],
      raw['teamName'],
      raw['operatorName'],
      vehicle['unitName'],
      vehicle['fleetName'],
      vehicle['companyName'],
    ], fallback: 'Independent Units');
  }

  static Map<String, dynamic> _normalizeRiderDocuments(dynamic rawDocuments) {
    final docs = _asMap(rawDocuments);
    return docs.map((key, value) {
      if (value is String) {
        return MapEntry(key, {
          'url': value,
          'status': 'uploaded',
          'reviewedAt': null,
          'reviewedBy': null,
          'rejectionReason': null,
        });
      }

      final mapValue = _asMap(value);
      return MapEntry(key, {
        ...mapValue,
        'url': _coalesceString([
          mapValue['url'],
          mapValue['imageUrl'],
          mapValue['downloadUrl'],
        ]),
        'status': _coalesceString([
          mapValue['status'],
          mapValue['reviewStatus'],
        ], fallback: 'uploaded'),
        'reviewedAt': mapValue['reviewedAt'],
        'reviewedBy': _asString(mapValue['reviewedBy']),
        'rejectionReason': _asString(mapValue['rejectionReason']),
      });
    });
  }

  static String _normalizeBookingStatus(dynamic rawStatus) {
    final status = _asString(rawStatus, fallback: 'pending');
    if (AdminConstants.bookingStatuses.contains(status)) return status;
    if (status == 'payment_pending') return 'awaiting_payment';
    if (status == 'driver_assigned' || status == 'assigned') return 'accepted';
    if (status == 'driver_arrived') return 'arrived_at_pickup';
    if (status == 'loading_started') return 'loading';
    if (status == 'loading_finished') return 'loading_complete';
    if (status == 'in_progress') return 'in_transit';
    if (status == 'transit' || status == 'on_the_way') return 'in_transit';
    if (status == 'driver_arrived_destination') return 'arrived_at_dropoff';
    if (status == 'unloading_started') return 'unloading';
    if (status == 'unloading_finished') return 'unloading_complete';
    if (status == 'delivered') return 'completed';
    if (status == 'rider_cancelled') return 'cancelled_by_rider';
    if (status == 'customer_cancelled') return 'cancelled_by_customer';
    return status.isEmpty ? 'pending' : status;
  }

  static bool canAssignBookingStatus(dynamic rawStatus) {
    const assignableStatuses = [
      'pending',
      'awaiting_payment',
      'payment_locked',
      'accepted',
    ];
    return assignableStatuses.contains(_normalizeBookingStatus(rawStatus));
  }

  static bool isLiveAssignedBookingStatus(dynamic rawStatus) {
    const liveStatuses = [
      'pending',
      'awaiting_payment',
      'payment_locked',
      'accepted',
      'arrived_at_pickup',
      'loading',
      'loading_complete',
      'in_transit',
      'arrived_at_dropoff',
      'unloading',
      'unloading_complete',
    ];
    return liveStatuses.contains(_normalizeBookingStatus(rawStatus));
  }

  static bool canCancelBookingStatus(dynamic rawStatus) {
    const nonCancellableStatuses = [
      'completed',
      'cancelled',
      'cancelled_by_rider',
      'cancelled_by_customer',
    ];
    return !nonCancellableStatuses.contains(_normalizeBookingStatus(rawStatus));
  }

  static Future<bool> _riderHasOtherLiveBooking(
    String riderId, {
    String? excludingBookingId,
  }) async {
    final snapshot = await _db
        .collection(AdminConstants.colBookings)
        .where('driverId', isEqualTo: riderId)
        .get();

    for (final doc in snapshot.docs) {
      if (excludingBookingId != null && doc.id == excludingBookingId) {
        continue;
      }

      if (isLiveAssignedBookingStatus(doc.data()['status'])) {
        return true;
      }
    }

    return false;
  }

  static List<String> _normalizeDeliveryPhotos(dynamic rawPhotos) {
    if (rawPhotos is Map) {
      return rawPhotos.values
          .map((entry) {
            // Rider app stores photos as { 'url': '...', 'uploadedAt': ... }
            if (entry is Map) {
              return (entry['url'] ?? entry['imageUrl'] ?? '')
                  .toString()
                  .trim();
            }
            return entry?.toString().trim() ?? '';
          })
          .where((url) => url.startsWith('http'))
          .toList();
    }
    return _asStringList(
      rawPhotos,
    ).where((url) => url.startsWith('http')).toList();
  }

  static Map<String, dynamic> normalizeUserData(
    String userId,
    Map<String, dynamic> raw,
  ) {
    final isSuspended =
        _asBool(raw['isSuspended']) ||
        _asString(raw['accountStatus']) == 'suspended';
    final accountStatus = isSuspended
        ? 'suspended'
        : _coalesceString([
            raw['accountStatus'],
            raw['status'],
          ], fallback: 'active');

    return {
      ...raw,
      'id': userId,
      'userId': userId,
      'name': _coalesceString([
        raw['name'],
        raw['fullName'],
        raw['displayName'],
      ], fallback: 'Unknown'),
      'phoneNumber': _coalesceString([
        raw['phoneNumber'],
        raw['phone'],
        raw['mobileNumber'],
      ]),
      'email': _coalesceString([raw['email'], raw['emailAddress']]),
      'walletBalance': _asDouble(raw['walletBalance']),
      'isSuspended': isSuspended,
      'accountStatus': accountStatus,
      'createdAt':
          parseTimestamp(raw['createdAt']) ?? parseTimestamp(raw['updatedAt']),
      'updatedAt': parseTimestamp(raw['updatedAt']),
    };
  }

  static Map<String, dynamic> normalizeRiderData(
    String riderId,
    Map<String, dynamic> raw,
  ) {
    final currentLocation = _asMap(raw['currentLocation']);
    final currentLatitude =
        _asOptionalDouble(currentLocation['latitude']) ??
        _asOptionalDouble(raw['currentLatitude']) ??
        _asOptionalDouble(raw['latitude']);
    final currentLongitude =
        _asOptionalDouble(currentLocation['longitude']) ??
        _asOptionalDouble(raw['currentLongitude']) ??
        _asOptionalDouble(raw['longitude']);
    final locationUpdatedAt =
        parseTimestamp(currentLocation['updatedAt']) ??
        parseTimestamp(raw['lastActive']) ??
        parseTimestamp(raw['updatedAt']);
    final isApproved = _asBool(raw['isApproved']);
    final isSuspended =
        _asBool(raw['isSuspended']) ||
        _asString(raw['accountStatus']) == 'suspended';
    final accountStatus = isSuspended
        ? 'suspended'
        : _coalesceString([
            raw['accountStatus'],
            raw['status'],
            isApproved ? 'active' : 'pending',
          ], fallback: 'pending');

    return {
      ...raw,
      'id': riderId,
      'riderId': riderId,
      'name': _coalesceString([
        raw['name'],
        raw['fullName'],
        raw['displayName'],
      ], fallback: 'Unknown Rider'),
      'phoneNumber': _coalesceString([raw['phoneNumber'], raw['phone']]),
      'vehicleType': _coalesceString([
        raw['vehicleType'],
        raw['truckType'],
        _asMap(raw['vehicle'])['name'],
        _asMap(raw['vehicle'])['type'],
      ]),
      'unitName': resolveRiderUnitName(raw),
      'plateNumber': _coalesceString([
        raw['plateNumber'],
        raw['vehiclePlateNumber'],
      ]),
      'accountStatus': accountStatus,
      'isApproved': isApproved,
      'isSuspended': isSuspended,
      'isOnline': _asBool(raw['isOnline']) || _asBool(raw['online']),
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
      'locationAddress': _coalesceString([
        currentLocation['address'],
        currentLocation['label'],
        raw['currentAddress'],
        raw['address'],
      ]),
      'locationUpdatedAt': locationUpdatedAt,
      'hasLiveLocation': currentLatitude != null && currentLongitude != null,
      'documents': _normalizeRiderDocuments(raw['documents']),
      'averageRating': _asDouble(raw['averageRating'] ?? raw['rating']),
      'rating': _asDouble(raw['rating'] ?? raw['averageRating']),
      'createdAt':
          parseTimestamp(raw['createdAt']) ?? parseTimestamp(raw['updatedAt']),
      'updatedAt': parseTimestamp(raw['updatedAt']),
    };
  }

  static Map<String, dynamic> normalizeBookingData(
    String bookingId,
    Map<String, dynamic> raw,
  ) {
    final status = _normalizeBookingStatus(raw['status']);
    final issueNotesCount = _asInt(raw['issueNotesCount']);
    final issueStatus = _coalesceString([
      raw['issueStatus'],
      issueNotesCount > 0 ? 'flagged' : '',
    ]);
    final paymentStatus = _coalesceString([
      raw['paymentStatus'],
      raw['status'],
    ], fallback: 'pending');
    final deliveryPhotos = _normalizeDeliveryPhotos(raw['deliveryPhotos']);
    final estimatedFare = _asDouble(raw['estimatedFare']);
    final tipAmount = _asDouble(raw['tipAmount']);
    final accountingFields = _resolveBookingAccountingFields(bookingId, raw);
    final resolvedFinalFare = accountingFields['grossAmount'] as double;

    return {
      ...raw,
      'id': bookingId,
      'bookingId': bookingId,
      'tripNumber': accountingFields['tripNumber'],
      'tripDateKey': accountingFields['tripDateKey'],
      'tripSequence': accountingFields['tripSequence'],
      'status': status,
      'customerId': _coalesceString([raw['customerId'], raw['userId']]),
      'userId': _coalesceString([raw['userId'], raw['customerId']]),
      'riderId': _coalesceString([raw['riderId'], raw['driverId']]),
      'driverId': _coalesceString([raw['driverId'], raw['riderId']]),
      'customerName': _coalesceString([
        raw['customerName'],
        raw['userName'],
      ], fallback: 'Unknown Customer'),
      'userName': _coalesceString([
        raw['userName'],
        raw['customerName'],
      ], fallback: 'Unknown Customer'),
      'customerPhone': _coalesceString([
        raw['customerPhone'],
        raw['userPhone'],
      ]),
      'userPhone': _coalesceString([raw['userPhone'], raw['customerPhone']]),
      'riderName': _coalesceString([
        raw['riderName'],
        raw['driverName'],
      ], fallback: 'Unassigned'),
      'pickupAddress': _coalesceString([
        raw['pickupAddress'],
        _asMap(raw['pickupLocation'])['address'],
      ]),
      'dropoffAddress': _coalesceString([
        raw['dropoffAddress'],
        _asMap(raw['dropoffLocation'])['address'],
      ]),
      'vehicleType': _coalesceString([
        raw['vehicleType'],
        raw['truckType'],
        _asMap(raw['vehicle'])['name'],
        _asMap(raw['vehicle'])['type'],
      ]),
      'distance': _asDouble(raw['distance']),
      'estimatedFare': estimatedFare,
      'grossAmount': accountingFields['grossAmount'],
      'finalFare': resolvedFinalFare,
      'tipAmount': tipAmount,
      'partnerNetRate': accountingFields['partnerNetRate'],
      'partnerNetAmount': accountingFields['partnerNetAmount'],
      'adminFeeRate': accountingFields['adminFeeRate'],
      'adminFeeAmount': accountingFields['adminFeeAmount'],
      'vatRate': accountingFields['vatRate'],
      'vatAmount': accountingFields['vatAmount'],
      'adminNetAmount': accountingFields['adminNetAmount'],
      'paymentStatus': paymentStatus,
      'reconciliationStatus': _coalesceString([
        raw['reconciliationStatus'],
        raw['paymentReconciliationStatus'],
      ]),
      'issueStatus': issueStatus,
      'issueOwner': _coalesceString([
        raw['issueOwner'],
        raw['issueAssignedTo'],
      ]),
      'issueAssignedAt':
          parseTimestamp(raw['issueAssignedAt']) ??
          parseTimestamp(raw['issueClaimedAt']),
      'issueNotesCount': issueNotesCount,
      'deliveryPhotos': deliveryPhotos,
      'createdAt':
          parseTimestamp(raw['createdAt']) ?? parseTimestamp(raw['updatedAt']),
      'updatedAt': parseTimestamp(raw['updatedAt']),
      'cancelledAt': parseTimestamp(raw['cancelledAt']),
      'cancellationReason': _asString(raw['cancellationReason']),
      'paymentRefundedAt': parseTimestamp(raw['paymentRefundedAt']),
      'refundedAmount': _asDouble(
        raw['refundedAmount'] ?? raw['paymentRefundedAmount'],
      ),
    };
  }

  static Map<String, dynamic> normalizeWalletTransactionData(
    String transactionId,
    Map<String, dynamic> raw,
  ) {
    final previousBalance = _asDouble(raw['previousBalance']);
    final newBalance = _asDouble(raw['newBalance'] ?? raw['balance']);
    final inferredAmount = raw['amount'] != null
        ? _asDouble(raw['amount'])
        : (newBalance != 0 || previousBalance != 0)
        ? newBalance - previousBalance
        : _asDouble(raw['balance']);

    return {
      ...raw,
      'id': transactionId,
      'userId': _coalesceString([raw['userId'], raw['riderId']]),
      'riderId': _coalesceString([raw['riderId'], raw['userId']]),
      'type': _coalesceString([
        raw['type'],
        raw['transactionType'],
      ], fallback: 'transaction'),
      'transactionType': _coalesceString([
        raw['transactionType'],
        raw['type'],
      ], fallback: 'transaction'),
      'amount': inferredAmount,
      'previousBalance': previousBalance,
      'newBalance': newBalance,
      'balance': newBalance,
      'description': _coalesceString([raw['description'], raw['remarks']]),
      'remarks': _coalesceString([raw['remarks'], raw['description']]),
      'reconciliationStatus': _coalesceString([raw['reconciliationStatus']]),
      'createdAt':
          parseTimestamp(raw['createdAt']) ?? parseTimestamp(raw['updatedAt']),
    };
  }

  static Map<String, dynamic> normalizePaymentData(
    String paymentId,
    Map<String, dynamic> raw,
  ) {
    return {
      ...raw,
      'id': paymentId,
      'amount': _asDouble(raw['amount'] ?? raw['finalFare']),
      'paymentMethod': _coalesceString([raw['paymentMethod'], raw['method']]),
      'method': _coalesceString([raw['method'], raw['paymentMethod']]),
      'paymentStatus': _coalesceString([
        raw['paymentStatus'],
        raw['status'],
      ], fallback: 'pending'),
      'status': _coalesceString([
        raw['status'],
        raw['paymentStatus'],
      ], fallback: 'pending'),
      'reconciliationStatus': _coalesceString([raw['reconciliationStatus']]),
      'createdAt':
          parseTimestamp(raw['createdAt']) ?? parseTimestamp(raw['updatedAt']),
    };
  }

  static Map<String, dynamic> normalizeBookingNoteData(
    String noteId,
    Map<String, dynamic> raw,
  ) {
    return {
      ...raw,
      'id': noteId,
      'noteId': _coalesceString([raw['noteId'], noteId]),
      'entityType': _coalesceString([raw['entityType']], fallback: 'booking'),
      'entityId': _coalesceString([raw['entityId']]),
      'noteType': _coalesceString([raw['noteType']], fallback: 'support'),
      'body': _coalesceString([raw['body'], raw['note']]),
      'note': _coalesceString([raw['note'], raw['body']]),
      'createdBy': _coalesceString([raw['createdBy'], raw['addedBy']]),
      'addedBy': _coalesceString([raw['addedBy'], raw['createdBy']]),
      'createdAt':
          parseTimestamp(raw['createdAt']) ?? parseTimestamp(raw['addedAt']),
      'addedAt':
          parseTimestamp(raw['addedAt']) ?? parseTimestamp(raw['createdAt']),
    };
  }

  static Map<String, dynamic> _buildAuditEntry({
    required String action,
    required String entityType,
    required String entityId,
    String? reason,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) {
    return {
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'reason': reason ?? '',
      'before': before ?? <String, dynamic>{},
      'after': after ?? <String, dynamic>{},
      'performedBy': AdminConstants.adminUsername,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  // ─── Users ───────────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamUsers({String? searchQuery}) {
    var query = _db
        .collection(AdminConstants.colUsers)
        .orderBy('createdAt', descending: true)
        .limit(200);
    return query.snapshots();
  }

  static Future<DocumentSnapshot> getUser(String userId) =>
      _db.collection(AdminConstants.colUsers).doc(userId).get();

  static Future<Map<String, dynamic>?> getNormalizedUser(String userId) async {
    final doc = await getUser(userId);
    if (!doc.exists) return null;
    return normalizeUserData(userId, _asMap(doc.data()));
  }

  static Future<void> updateUser(String userId, Map<String, dynamic> data) =>
      _db.collection(AdminConstants.colUsers).doc(userId).update(data);

  static Stream<QuerySnapshot> streamCustomerBookings(String customerId) => _db
      .collection(AdminConstants.colBookings)
      .where('customerId', isEqualTo: customerId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();

  static Stream<QuerySnapshot> streamSavedLocations(String userId) => _db
      .collection(AdminConstants.colSavedLocations)
      .where('userId', isEqualTo: userId)
      .limit(20)
      .snapshots();

  static Future<void> setUserSuspended({
    required String userId,
    required bool isSuspended,
  }) async {
    final userRef = _db.collection(AdminConstants.colUsers).doc(userId);
    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();
    final nextStatus = isSuspended ? 'suspended' : 'active';

    await _db.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final beforeData = _asMap(userSnap.data());

      transaction.set(userRef, {
        'isSuspended': isSuspended,
        'accountStatus': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(
        auditRef,
        _buildAuditEntry(
          action: isSuspended
              ? AdminConstants.auditSuspendUser
              : AdminConstants.auditReactivateUser,
          entityType: 'user',
          entityId: userId,
          before: {
            'isSuspended': beforeData['isSuspended'] == true,
            'accountStatus': beforeData['accountStatus'] ?? 'active',
          },
          after: {'isSuspended': isSuspended, 'accountStatus': nextStatus},
        ),
      );
    });
  }

  static Future<Map<String, double>> adjustUserWallet({
    required String userId,
    required double amount,
    required String reason,
  }) async {
    final userRef = _db.collection(AdminConstants.colUsers).doc(userId);
    final walletRef = _db
        .collection(AdminConstants.colWalletTransactions)
        .doc();
    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();

    return _db.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final userData = _asMap(userSnap.data());
      final previousBalance = _asDouble(userData['walletBalance']);
      final newBalance = previousBalance + amount;

      transaction.set(userRef, {
        'walletBalance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(walletRef, {
        'userId': userId,
        'amount': amount,
        'balance': newBalance,
        'newBalance': newBalance,
        'previousBalance': previousBalance,
        'type': 'admin_adjustment',
        'transactionType': 'admin_adjustment',
        'description': reason,
        'remarks': reason,
        'performedBy': AdminConstants.adminUsername,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        auditRef,
        _buildAuditEntry(
          action: AdminConstants.auditWalletAdjust,
          entityType: 'user',
          entityId: userId,
          reason: reason,
          before: {'walletBalance': previousBalance},
          after: {'walletBalance': newBalance, 'adjustmentAmount': amount},
        ),
      );

      return {'previousBalance': previousBalance, 'newBalance': newBalance};
    });
  }

  // ─── Riders ──────────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamRiders({String? statusFilter}) {
    var ref = _db.collection(AdminConstants.colRiders);
    Query query = statusFilter != null && statusFilter.isNotEmpty
        ? ref.where('accountStatus', isEqualTo: statusFilter)
        : ref;
    return query.orderBy('createdAt', descending: true).limit(200).snapshots();
  }

  static Stream<List<Map<String, dynamic>>> streamDispatchableRiders({
    int limit = 300,
  }) {
    return _db
        .collection(AdminConstants.colRiders)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final riders = snapshot.docs
              .map((doc) => normalizeRiderData(doc.id, _asMap(doc.data())))
              .where(
                (rider) =>
                    _asString(rider['accountStatus'], fallback: 'pending') ==
                        'active' &&
                    rider['isSuspended'] != true,
              )
              .toList();

          riders.sort((a, b) {
            final unitCompare = _asString(
              a['unitName'],
            ).toLowerCase().compareTo(_asString(b['unitName']).toLowerCase());
            if (unitCompare != 0) return unitCompare;

            final onlineCompare =
                (_asBool(b['isOnline']) ? 1 : 0) -
                (_asBool(a['isOnline']) ? 1 : 0);
            if (onlineCompare != 0) return onlineCompare;

            return _asString(
              a['name'],
            ).toLowerCase().compareTo(_asString(b['name']).toLowerCase());
          });

          return riders;
        });
  }

  static Future<DocumentSnapshot> getRider(String riderId) =>
      _db.collection(AdminConstants.colRiders).doc(riderId).get();

  static Future<Map<String, dynamic>?> getNormalizedRider(
    String riderId,
  ) async {
    final doc = await getRider(riderId);
    if (!doc.exists) return null;
    return normalizeRiderData(riderId, _asMap(doc.data()));
  }

  static Future<void> updateRider(String riderId, Map<String, dynamic> data) =>
      _db.collection(AdminConstants.colRiders).doc(riderId).update(data);

  static Stream<QuerySnapshot> streamRiderBookings(String riderId) => _db
      .collection(AdminConstants.colBookings)
      .where('driverId', isEqualTo: riderId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();

  static Future<void> approveRider(String riderId) async {
    final riderRef = _db.collection(AdminConstants.colRiders).doc(riderId);
    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();

    await _db.runTransaction((transaction) async {
      final riderSnap = await transaction.get(riderRef);
      final beforeData = _asMap(riderSnap.data());

      transaction.set(riderRef, {
        'status': 'active',
        'accountStatus': 'active',
        'isApproved': true,
        'isSuspended': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(
        auditRef,
        _buildAuditEntry(
          action: AdminConstants.auditApproveRider,
          entityType: 'rider',
          entityId: riderId,
          before: {
            'accountStatus': beforeData['accountStatus'],
            'isApproved': beforeData['isApproved'] == true,
          },
          after: {'accountStatus': 'active', 'isApproved': true},
        ),
      );
    });
  }

  static Future<void> setRiderSuspended({
    required String riderId,
    required bool isSuspended,
  }) async {
    final riderRef = _db.collection(AdminConstants.colRiders).doc(riderId);
    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();
    final nextStatus = isSuspended ? 'suspended' : 'active';

    await _db.runTransaction((transaction) async {
      final riderSnap = await transaction.get(riderRef);
      final beforeData = _asMap(riderSnap.data());

      transaction.set(riderRef, {
        'accountStatus': nextStatus,
        'isSuspended': isSuspended,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(
        auditRef,
        _buildAuditEntry(
          action: isSuspended
              ? AdminConstants.auditSuspendRider
              : AdminConstants.auditReactivateRider,
          entityType: 'rider',
          entityId: riderId,
          before: {
            'accountStatus': beforeData['accountStatus'],
            'isSuspended': beforeData['isSuspended'] == true,
          },
          after: {'accountStatus': nextStatus, 'isSuspended': isSuspended},
        ),
      );
    });
  }

  static Future<void> rejectRiderDocument({
    required String riderId,
    required String docKey,
    required String reason,
  }) async {
    final riderRef = _db.collection(AdminConstants.colRiders).doc(riderId);
    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();

    await _db.runTransaction((transaction) async {
      final riderSnap = await transaction.get(riderRef);
      final riderData = _asMap(riderSnap.data());
      final documents = Map<String, dynamic>.from(
        _asMap(riderData['documents']),
      );
      final previousDocument = _asMap(documents[docKey]);

      documents[docKey] = {
        ...previousDocument,
        'status': 'rejected',
        'rejectionReason': reason,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': AdminConstants.adminUsername,
      };

      transaction.set(riderRef, {
        'documents': documents,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(
        auditRef,
        _buildAuditEntry(
          action: AdminConstants.auditRejectRiderDoc,
          entityType: 'rider',
          entityId: riderId,
          reason: reason,
          before: {'documentKey': docKey, 'document': previousDocument},
          after: {
            'documentKey': docKey,
            'document': {
              ...previousDocument,
              'status': 'rejected',
              'rejectionReason': reason,
              'reviewedBy': AdminConstants.adminUsername,
            },
          },
        ),
      );
    });
  }

  // ─── Bookings ─────────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamBookings({
    String? statusFilter,
    String? issueFilter,
    int limit = 100,
  }) {
    Query query = _db.collection(AdminConstants.colBookings);
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  static Stream<List<Map<String, dynamic>>> streamDispatchQueue({
    int limit = 120,
  }) {
    return _db
        .collection(AdminConstants.colBookings)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => normalizeBookingData(doc.id, _asMap(doc.data())))
              .where((booking) {
                final riderId = _coalesceString([
                  booking['driverId'],
                  booking['riderId'],
                ]);
                return riderId.isEmpty &&
                    canAssignBookingStatus(booking['status']);
              })
              .toList();
        });
  }

  static Stream<List<Map<String, dynamic>>> streamActiveAssignedBookings({
    int limit = 200,
  }) {
    return _db
        .collection(AdminConstants.colBookings)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => normalizeBookingData(doc.id, _asMap(doc.data())))
              .where((booking) {
                final riderId = _coalesceString([
                  booking['driverId'],
                  booking['riderId'],
                ]);
                return riderId.isNotEmpty &&
                    isLiveAssignedBookingStatus(booking['status']);
              })
              .toList();
        });
  }

  static Future<DocumentSnapshot> getBooking(String bookingId) =>
      _db.collection(AdminConstants.colBookings).doc(bookingId).get();

  static Future<Map<String, dynamic>?> getNormalizedBooking(
    String bookingId,
  ) async {
    final doc = await getBooking(bookingId);
    if (!doc.exists) return null;
    return normalizeBookingData(bookingId, _asMap(doc.data()));
  }

  static Future<void> updateBooking(
    String bookingId,
    Map<String, dynamic> data,
  ) => _db.collection(AdminConstants.colBookings).doc(bookingId).update(data);

  static Future<void> assignRiderToBooking({
    required String bookingId,
    required String riderId,
    required String reason,
  }) async {
    if (await _riderHasOtherLiveBooking(
      riderId,
      excludingBookingId: bookingId,
    )) {
      throw StateError('This rider already has another live booking assigned.');
    }

    final bookingRef = _db
        .collection(AdminConstants.colBookings)
        .doc(bookingId);
    final deliveryRequestRef = _db
        .collection(AdminConstants.colDeliveryRequests)
        .doc(bookingId);
    final riderRef = _db.collection(AdminConstants.colRiders).doc(riderId);
    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();

    await _db.runTransaction((transaction) async {
      final bookingSnap = await transaction.get(bookingRef);
      if (!bookingSnap.exists) {
        throw StateError('Booking not found.');
      }

      final riderSnap = await transaction.get(riderRef);
      if (!riderSnap.exists) {
        throw StateError('Rider not found.');
      }

      final beforeData = normalizeBookingData(
        bookingId,
        _asMap(bookingSnap.data()),
      );
      final riderData = normalizeRiderData(riderId, _asMap(riderSnap.data()));
      final riderActiveBookingId = _asString(riderData['activeBookingId']);

      final currentStatus = _asString(
        beforeData['status'],
        fallback: 'pending',
      );
      if (!canAssignBookingStatus(currentStatus)) {
        throw StateError(
          'Only pending or accepted bookings can be assigned from admin.',
        );
      }

      final riderStatus = _asString(
        riderData['accountStatus'],
        fallback: 'pending',
      );
      if (riderStatus != 'active') {
        throw StateError('Only active riders can be assigned.');
      }

      final currentRiderId = _coalesceString([
        beforeData['driverId'],
        beforeData['riderId'],
      ]);
      if (currentRiderId == riderId) {
        throw StateError('Booking is already assigned to this rider.');
      }

      if (riderActiveBookingId.isNotEmpty &&
          riderActiveBookingId != bookingId) {
        throw StateError(
          'This rider already has another live booking assigned.',
        );
      }

      final customerId = _coalesceString([
        beforeData['customerId'],
        beforeData['userId'],
      ]);
      final riderName = _asString(
        riderData['name'],
        fallback: 'Assigned Rider',
      );
      final shouldMarkAccepted = currentStatus != 'accepted';
      final nextStatus = shouldMarkAccepted ? 'accepted' : currentStatus;
      final wasReassigned = currentRiderId.isNotEmpty;
      final previousRiderRef = wasReassigned && currentRiderId != riderId
          ? _db.collection(AdminConstants.colRiders).doc(currentRiderId)
          : null;
      DocumentSnapshot<Map<String, dynamic>>? previousRiderSnap;
      if (previousRiderRef != null) {
        previousRiderSnap = await transaction.get(previousRiderRef);
      }

      transaction.set(bookingRef, {
        'driverId': riderId,
        'riderId': riderId,
        'driverName': riderName,
        'riderName': riderName,
        'status': nextStatus,
        'assignmentReason': reason,
        'assignedBy': AdminConstants.adminUsername,
        'assignedAt': FieldValue.serverTimestamp(),
        if (wasReassigned) 'reassignedAt': FieldValue.serverTimestamp(),
        if (shouldMarkAccepted) 'acceptedAt': FieldValue.serverTimestamp(),
        'lastAdminActionAt': FieldValue.serverTimestamp(),
        'lastAdminActionBy': AdminConstants.adminUsername,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(deliveryRequestRef, {
        'requestId': bookingId,
        'bookingId': bookingId,
        'customerId': customerId,
        'riderId': riderId,
        'riderName': riderName,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'respondedAt': FieldValue.serverTimestamp(),
        'assignmentReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
        'vehicleType': beforeData['vehicleType'],
        'pickupLocation': _asMap(bookingSnap.data())['pickupLocation'],
        'dropoffLocation': _asMap(bookingSnap.data())['dropoffLocation'],
        'distance': beforeData['distance'],
        'estimatedFare': beforeData['estimatedFare'],
      }, SetOptions(merge: true));

      transaction.set(riderRef, {
        'activeBookingId': bookingId,
        'activeBookingStatus': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (previousRiderRef != null) {
        final previousActiveBookingId = _asString(
          _asMap(previousRiderSnap?.data())['activeBookingId'],
        );
        if (previousActiveBookingId == bookingId) {
          transaction.set(previousRiderRef, {
            'activeBookingId': FieldValue.delete(),
            'activeBookingStatus': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      if (customerId.isNotEmpty) {
        final notificationRef = _db
            .collection(AdminConstants.colNotifications)
            .doc();
        transaction.set(notificationRef, {
          'id': notificationRef.id,
          'userId': customerId,
          'userType': 'customer',
          'title': wasReassigned ? 'Rider Reassigned' : 'Rider Assigned',
          'message': wasReassigned
              ? 'Support reassigned your booking to $riderName.'
              : 'Support assigned $riderName to your booking.',
          'body': wasReassigned
              ? 'Support reassigned your booking to $riderName.'
              : 'Support assigned $riderName to your booking.',
          'type': 'booking',
          'referenceId': bookingId,
          'bookingId': bookingId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final assignedRiderNotificationRef = _db
          .collection(AdminConstants.colNotifications)
          .doc();
      transaction.set(assignedRiderNotificationRef, {
        'id': assignedRiderNotificationRef.id,
        'userId': riderId,
        'userType': 'rider',
        'title': wasReassigned
            ? 'Booking Reassigned to You'
            : 'Booking Assigned',
        'message':
            'Support assigned booking #${bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length)} to you.',
        'body':
            'Support assigned booking #${bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length)} to you.',
        'type': 'booking',
        'referenceId': bookingId,
        'bookingId': bookingId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (wasReassigned && currentRiderId.isNotEmpty) {
        final previousRiderNotificationRef = _db
            .collection(AdminConstants.colNotifications)
            .doc();
        transaction.set(previousRiderNotificationRef, {
          'id': previousRiderNotificationRef.id,
          'userId': currentRiderId,
          'userType': 'rider',
          'title': 'Booking Reassigned',
          'message':
              'Support reassigned booking #${bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length)} to another rider.',
          'body':
              'Support reassigned booking #${bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length)} to another rider.',
          'type': 'booking',
          'referenceId': bookingId,
          'bookingId': bookingId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.set(
        auditRef,
        _buildAuditEntry(
          action: AdminConstants.auditAssignBooking,
          entityType: 'booking',
          entityId: bookingId,
          reason: reason,
          before: {
            'status': beforeData['status'],
            'driverId': beforeData['driverId'],
            'riderId': beforeData['riderId'],
            'riderName': beforeData['riderName'],
          },
          after: {
            'status': nextStatus,
            'driverId': riderId,
            'riderId': riderId,
            'riderName': riderName,
            'wasReassigned': wasReassigned,
          },
        ),
      );
    });
  }

  static Future<void> cancelBooking({
    required String bookingId,
    required String reason,
  }) async {
    final bookingRef = _db
        .collection(AdminConstants.colBookings)
        .doc(bookingId);
    final deliveryRequestRef = _db
        .collection(AdminConstants.colDeliveryRequests)
        .doc(bookingId);
    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();

    await _db.runTransaction((transaction) async {
      // ── Reads (must all happen before writes in a Firestore transaction) ──
      final bookingSnap = await transaction.get(bookingRef);
      if (!bookingSnap.exists) {
        throw StateError('Booking not found.');
      }

      final beforeData = normalizeBookingData(
        bookingId,
        _asMap(bookingSnap.data()),
      );
      final customerId = _coalesceString([
        beforeData['customerId'],
        beforeData['userId'],
      ]);
      final riderId = _coalesceString([
        beforeData['driverId'],
        beforeData['riderId'],
      ]);
      final paymentStatus = _asString(
        beforeData['paymentStatus'],
        fallback: 'pending',
      );
      final currentStatus = _asString(
        beforeData['status'],
        fallback: 'pending',
      );
      if (!canCancelBookingStatus(currentStatus)) {
        throw StateError('This booking can no longer be cancelled.');
      }
      final riderRef = riderId.isNotEmpty
          ? _db.collection(AdminConstants.colRiders).doc(riderId)
          : null;
      DocumentSnapshot<Map<String, dynamic>>? riderSnap;
      if (riderRef != null) {
        riderSnap = await transaction.get(riderRef);
      }

      const lateCancellationStatuses = [
        'arrived_at_pickup',
        'loading',
        'loading_complete',
        'in_transit',
        'arrived_at_dropoff',
        'unloading',
        'unloading_complete',
      ];
      final shouldCaptureHeldAmount =
          paymentStatus == 'held' &&
          customerId.isNotEmpty &&
          lateCancellationStatuses.contains(currentStatus);
      final shouldRefund =
          paymentStatus == 'held' &&
          customerId.isNotEmpty &&
          !shouldCaptureHeldAmount;

      // Read user doc for wallet refund (only if payment was on hold)
      DocumentSnapshot? userSnap;
      if (shouldRefund) {
        userSnap = await transaction.get(
          _db.collection(AdminConstants.colUsers).doc(customerId),
        );
      }

      // ── Derive refund amount and reconciliation status ─────────────────────
      final refundAmount = shouldRefund
          ? _asDouble(
              bookingSnap.data() != null
                  ? (_asMap(bookingSnap.data())['estimatedFare'])
                  : null,
            )
          : 0.0;
      final capturedAmount = shouldCaptureHeldAmount
          ? _asDouble(
              bookingSnap.data() != null
                  ? (_asMap(bookingSnap.data())['estimatedFare'])
                  : null,
            )
          : 0.0;
      final reconciliationStatus = shouldRefund || shouldCaptureHeldAmount
          ? 'reconciled'
          : _asString(beforeData['reconciliationStatus']);

      // ── Writes ─────────────────────────────────────────────────────────────
      transaction.set(bookingRef, {
        'status': 'cancelled',
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': AdminConstants.adminUsername,
        'issueStatus': 'flagged',
        'issueOwner': AdminConstants.adminUsername,
        'issueAssignedAt': FieldValue.serverTimestamp(),
        'reconciliationStatus': reconciliationStatus,
        'paymentStatus': shouldRefund
            ? 'refunded'
            : shouldCaptureHeldAmount
            ? 'captured'
            : paymentStatus,
        if (shouldCaptureHeldAmount)
          'paymentCapturedAt': FieldValue.serverTimestamp(),
        if (shouldCaptureHeldAmount) 'paymentCapturedAmount': capturedAmount,
        if (shouldRefund) 'paymentRefundedAt': FieldValue.serverTimestamp(),
        if (shouldRefund) 'paymentRefundedAmount': refundAmount,
        if (shouldRefund) 'refundedAmount': refundAmount,
        if (shouldRefund) 'refundedAt': FieldValue.serverTimestamp(),
        'lastAdminActionAt': FieldValue.serverTimestamp(),
        'lastAdminActionBy': AdminConstants.adminUsername,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(deliveryRequestRef, {
        'bookingId': bookingId,
        'status': 'cancelled',
        'cancellationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (riderRef != null) {
        final activeBookingId = _asString(
          _asMap(riderSnap?.data())['activeBookingId'],
        );
        if (activeBookingId == bookingId) {
          transaction.set(riderRef, {
            'activeBookingId': FieldValue.delete(),
            'activeBookingStatus': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      // Wallet refund when payment was on hold
      if (shouldRefund && userSnap != null && refundAmount > 0) {
        final userData = _asMap(userSnap.data());
        final previousBalance = _asDouble(userData['walletBalance']);
        final newBalance = previousBalance + refundAmount;
        final userRef = _db.collection(AdminConstants.colUsers).doc(customerId);
        final walletRef = _db
            .collection(AdminConstants.colWalletTransactions)
            .doc();
        transaction.set(userRef, {
          'walletBalance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.set(walletRef, {
          'userId': customerId,
          'amount': refundAmount,
          'balance': newBalance,
          'newBalance': newBalance,
          'previousBalance': previousBalance,
          'type': 'refund',
          'transactionType': 'refund',
          'description': 'Refund for admin-cancelled booking #$bookingId',
          'remarks': 'Refund for admin-cancelled booking #$bookingId',
          'referenceId': bookingId,
          'bookingId': bookingId,
          'performedBy': AdminConstants.adminUsername,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (customerId.isNotEmpty) {
        final notificationRef = _db
            .collection(AdminConstants.colNotifications)
            .doc();
        transaction.set(notificationRef, {
          'id': notificationRef.id,
          'userId': customerId,
          'userType': 'customer',
          'title': 'Booking Cancelled by Admin',
          'message': shouldRefund
              ? 'Your booking has been cancelled by support and your fare has been refunded. Reason: $reason'
              : shouldCaptureHeldAmount
              ? 'Your booking was cancelled by support after dispatch. Your original booking amount was retained as the cancellation charge. Reason: $reason'
              : 'Your booking has been cancelled by support. Reason: $reason',
          'body': shouldRefund
              ? 'Your booking has been cancelled by support and your fare has been refunded. Reason: $reason'
              : shouldCaptureHeldAmount
              ? 'Your booking was cancelled by support after dispatch. Your original booking amount was retained as the cancellation charge. Reason: $reason'
              : 'Your booking has been cancelled by support. Reason: $reason',
          'type': 'booking',
          'referenceId': bookingId,
          'bookingId': bookingId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (riderId.isNotEmpty) {
        final notificationRef = _db
            .collection(AdminConstants.colNotifications)
            .doc();
        transaction.set(notificationRef, {
          'id': notificationRef.id,
          'userId': riderId,
          'userType': 'rider',
          'title': 'Booking Cancelled by Admin',
          'message':
              'Booking #${bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length)} was cancelled by support.',
          'body':
              'Booking #${bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length)} was cancelled by support.',
          'type': 'booking',
          'referenceId': bookingId,
          'bookingId': bookingId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.set(
        auditRef,
        _buildAuditEntry(
          action: AdminConstants.auditCancelBooking,
          entityType: 'booking',
          entityId: bookingId,
          reason: reason,
          before: {
            'status': beforeData['status'],
            'cancellationReason': beforeData['cancellationReason'],
            'paymentStatus': paymentStatus,
          },
          after: {
            'status': 'cancelled',
            'cancellationReason': reason,
            'cancelledBy': AdminConstants.adminUsername,
            'issueOwner': AdminConstants.adminUsername,
            'paymentStatus': shouldRefund
                ? 'refunded'
                : shouldCaptureHeldAmount
                ? 'captured'
                : paymentStatus,
            'reconciliationStatus': reconciliationStatus,
            if (shouldRefund) 'refundAmount': refundAmount,
            if (shouldCaptureHeldAmount) 'capturedAmount': capturedAmount,
          },
        ),
      );
    });
  }

  static Future<void> addBookingAdminNote({
    required String bookingId,
    required String note,
  }) async {
    final bookingRef = _db
        .collection(AdminConstants.colBookings)
        .doc(bookingId);
    final noteRef = bookingRef
        .collection(AdminConstants.colBookingAdminNotes)
        .doc();
    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();

    await _db.runTransaction((transaction) async {
      final bookingSnap = await transaction.get(bookingRef);
      final beforeData = _asMap(bookingSnap.data());
      final currentNotesCount = _asInt(beforeData['issueNotesCount']);

      transaction.set(noteRef, {
        'noteId': noteRef.id,
        'entityType': 'booking',
        'entityId': bookingId,
        'noteType': 'support',
        'body': note,
        'createdBy': AdminConstants.adminUsername,
        'createdAt': FieldValue.serverTimestamp(),
        'note': note,
        'addedBy': AdminConstants.adminUsername,
        'addedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(bookingRef, {
        'issueStatus': 'flagged',
        'issueOwner': AdminConstants.adminUsername,
        'issueAssignedAt': FieldValue.serverTimestamp(),
        'issueNotesCount': currentNotesCount + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(
        auditRef,
        _buildAuditEntry(
          action: AdminConstants.auditAddBookingNote,
          entityType: 'booking',
          entityId: bookingId,
          reason: note,
          before: {'issueNotesCount': currentNotesCount},
          after: {
            'issueStatus': 'flagged',
            'issueOwner': AdminConstants.adminUsername,
            'issueNotesCount': currentNotesCount + 1,
            'notePreview': note,
          },
        ),
      );
    });
  }

  static Future<void> claimBookingIssue(String bookingId) async {
    final bookingRef = _db
        .collection(AdminConstants.colBookings)
        .doc(bookingId);
    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();

    await _db.runTransaction((transaction) async {
      final bookingSnap = await transaction.get(bookingRef);
      if (!bookingSnap.exists) {
        throw StateError('Booking not found.');
      }

      final beforeData = normalizeBookingData(
        bookingId,
        _asMap(bookingSnap.data()),
      );

      transaction.set(bookingRef, {
        'issueStatus': 'flagged',
        'issueOwner': AdminConstants.adminUsername,
        'issueAssignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(
        auditRef,
        _buildAuditEntry(
          action: AdminConstants.auditClaimBookingIssue,
          entityType: 'booking',
          entityId: bookingId,
          before: {
            'issueStatus': beforeData['issueStatus'],
            'issueOwner': beforeData['issueOwner'],
          },
          after: {
            'issueStatus': 'flagged',
            'issueOwner': AdminConstants.adminUsername,
          },
        ),
      );
    });
  }

  static Future<void> releaseBookingIssue(String bookingId) async {
    final bookingRef = _db
        .collection(AdminConstants.colBookings)
        .doc(bookingId);
    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();

    await _db.runTransaction((transaction) async {
      final bookingSnap = await transaction.get(bookingRef);
      if (!bookingSnap.exists) {
        throw StateError('Booking not found.');
      }

      final beforeData = normalizeBookingData(
        bookingId,
        _asMap(bookingSnap.data()),
      );

      transaction.set(bookingRef, {
        'issueOwner': '',
        'issueAssignedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(
        auditRef,
        _buildAuditEntry(
          action: AdminConstants.auditReleaseBookingIssue,
          entityType: 'booking',
          entityId: bookingId,
          before: {
            'issueStatus': beforeData['issueStatus'],
            'issueOwner': beforeData['issueOwner'],
          },
          after: {'issueStatus': beforeData['issueStatus'], 'issueOwner': ''},
        ),
      );
    });
  }

  static Stream<QuerySnapshot> streamReconciliationQueue({int limit = 100}) =>
      _db
          .collection(AdminConstants.colBookings)
          .where(
            'reconciliationStatus',
            whereIn: const ['admin_review_required', 'under_review'],
          )
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .snapshots();

  static Future<List<Map<String, dynamic>>> getPayments({
    int limit = 500,
  }) async {
    final snapshot = await _db
        .collection(AdminConstants.colPayments)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => normalizePaymentData(doc.id, _asMap(doc.data())))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getWalletTransactions({
    int limit = 500,
  }) async {
    final snapshot = await _db
        .collection(AdminConstants.colWalletTransactions)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map(
          (doc) => normalizeWalletTransactionData(doc.id, _asMap(doc.data())),
        )
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getReconciliationQueue({
    int limit = 500,
  }) async {
    final snapshot = await _db
        .collection(AdminConstants.colBookings)
        .where(
          'reconciliationStatus',
          whereIn: const ['admin_review_required', 'under_review'],
        )
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => normalizeBookingData(doc.id, _asMap(doc.data())))
        .toList();
  }

  static Stream<QuerySnapshot> streamBookingPayments(
    String bookingId, {
    int limit = 20,
  }) => _db
      .collection(AdminConstants.colPayments)
      .where('bookingId', isEqualTo: bookingId)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots();

  static Stream<QuerySnapshot> streamBookingWalletTransactions(
    String bookingId, {
    int limit = 20,
  }) => _db
      .collection(AdminConstants.colWalletTransactions)
      .where('referenceId', isEqualTo: bookingId)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots();

  static Future<void> updateBookingReconciliationStatus({
    required String bookingId,
    required String status,
    required String reason,
  }) async {
    final bookingRef = _db
        .collection(AdminConstants.colBookings)
        .doc(bookingId);
    final noteRef = bookingRef
        .collection(AdminConstants.colBookingAdminNotes)
        .doc();

    final bookingSnap = await bookingRef.get();
    final beforeData = normalizeBookingData(
      bookingId,
      _asMap(bookingSnap.data()),
    );
    final paymentsSnap = await _db
        .collection(AdminConstants.colPayments)
        .where('bookingId', isEqualTo: bookingId)
        .get();
    final walletSnap = await _db
        .collection(AdminConstants.colWalletTransactions)
        .where('referenceId', isEqualTo: bookingId)
        .get();

    final batch = _db.batch();
    batch.set(bookingRef, {
      'reconciliationStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'reconciled') 'reconciledAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    for (final doc in paymentsSnap.docs) {
      batch.set(doc.reference, {
        'reconciliationStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    for (final doc in walletSnap.docs) {
      batch.set(doc.reference, {
        'reconciliationStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    batch.set(noteRef, {
      'noteId': noteRef.id,
      'entityType': 'booking',
      'entityId': bookingId,
      'noteType': 'reconciliation',
      'body': reason,
      'createdBy': AdminConstants.adminUsername,
      'createdAt': FieldValue.serverTimestamp(),
      'note': reason,
      'addedBy': AdminConstants.adminUsername,
      'addedAt': FieldValue.serverTimestamp(),
    });
    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();
    batch.set(
      auditRef,
      _buildAuditEntry(
        action: AdminConstants.auditUpdateReconciliation,
        entityType: 'booking',
        entityId: bookingId,
        reason: reason,
        before: {'reconciliationStatus': beforeData['reconciliationStatus']},
        after: {
          'reconciliationStatus': status,
          'paymentRecordsUpdated': paymentsSnap.docs.length,
          'walletRecordsUpdated': walletSnap.docs.length,
        },
      ),
    );
    await batch.commit();
  }

  // ─── Wallet transactions ──────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamWalletTransactions(String userId) => _db
      .collection(AdminConstants.colWalletTransactions)
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();

  static Stream<QuerySnapshot> streamAllWalletTransactions({int limit = 100}) =>
      _db
          .collection(AdminConstants.colWalletTransactions)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots();

  static Stream<QuerySnapshot> streamBookingAdminNotes(
    String bookingId, {
    int limit = 50,
  }) => _db
      .collection(AdminConstants.colBookings)
      .doc(bookingId)
      .collection(AdminConstants.colBookingAdminNotes)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots();

  // ─── Payments ─────────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamPayments({int limit = 100}) => _db
      .collection(AdminConstants.colPayments)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots();

  static Future<Map<String, int>> getBackfillSummary() async {
    final usersFuture = _db.collection(AdminConstants.colUsers).get();
    final ridersFuture = _db.collection(AdminConstants.colRiders).get();
    final bookingsFuture = _db.collection(AdminConstants.colBookings).get();

    final results = await Future.wait([
      usersFuture,
      ridersFuture,
      bookingsFuture,
    ]);

    final usersSnap = results[0];
    final ridersSnap = results[1];
    final bookingsSnap = results[2];

    final usersCount = usersSnap.docs
        .where((doc) => _needsUserBackfill(_asMap(doc.data())))
        .length;
    final ridersCount = ridersSnap.docs
        .where((doc) => _needsRiderBackfill(_asMap(doc.data())))
        .length;
    final bookingsCount = bookingsSnap.docs
        .where((doc) => _needsBookingBackfill(_asMap(doc.data())))
        .length;

    return {
      'users': usersCount,
      'riders': ridersCount,
      'bookings': bookingsCount,
    };
  }

  static Future<int> runUsersBackfill() async {
    final snap = await _db.collection(AdminConstants.colUsers).get();
    var batch = _db.batch();
    var opCount = 0;
    var updated = 0;

    for (final doc in snap.docs) {
      final raw = _asMap(doc.data());
      if (!_needsUserBackfill(raw)) continue;

      final normalized = normalizeUserData(doc.id, raw);
      final payload = <String, dynamic>{};
      if (!raw.containsKey('isSuspended')) {
        payload['isSuspended'] = normalized['isSuspended'];
      }
      if (_isMissing(raw['accountStatus'])) {
        payload['accountStatus'] = normalized['accountStatus'];
      }
      if (raw['walletBalance'] == null) {
        payload['walletBalance'] = normalized['walletBalance'];
      }
      if (payload.isEmpty) continue;

      payload['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(doc.reference, payload, SetOptions(merge: true));
      opCount++;
      updated++;

      if (opCount >= _batchWriteLimit) {
        await batch.commit();
        batch = _db.batch();
        opCount = 0;
      }
    }

    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();
    batch.set(
      auditRef,
      _buildAuditEntry(
        action: AdminConstants.auditRunBackfill,
        entityType: 'users',
        entityId: 'users',
        reason: 'Backfilled user account flags and balances',
        after: {'documentsUpdated': updated},
      ),
    );
    opCount++;

    if (opCount > 0) {
      await batch.commit();
    }

    return updated;
  }

  static Future<int> runRidersBackfill() async {
    final snap = await _db.collection(AdminConstants.colRiders).get();
    var batch = _db.batch();
    var opCount = 0;
    var updated = 0;

    for (final doc in snap.docs) {
      final raw = _asMap(doc.data());
      if (!_needsRiderBackfill(raw)) continue;

      final normalized = normalizeRiderData(doc.id, raw);
      final payload = <String, dynamic>{};
      if (!raw.containsKey('isSuspended')) {
        payload['isSuspended'] = normalized['isSuspended'];
      }
      if (_isMissing(raw['accountStatus'])) {
        payload['accountStatus'] = normalized['accountStatus'];
      }
      if (!raw.containsKey('isApproved')) {
        payload['isApproved'] = normalized['isApproved'];
      }
      if (_needsRiderDocumentsBackfill(raw)) {
        payload['documents'] = normalized['documents'];
      }
      if (payload.isEmpty) continue;

      payload['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(doc.reference, payload, SetOptions(merge: true));
      opCount++;
      updated++;

      if (opCount >= _batchWriteLimit) {
        await batch.commit();
        batch = _db.batch();
        opCount = 0;
      }
    }

    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();
    batch.set(
      auditRef,
      _buildAuditEntry(
        action: AdminConstants.auditRunBackfill,
        entityType: 'riders',
        entityId: 'riders',
        reason: 'Backfilled rider account flags and document review metadata',
        after: {'documentsUpdated': updated},
      ),
    );
    opCount++;

    if (opCount > 0) {
      await batch.commit();
    }

    return updated;
  }

  static Future<int> runBookingsBackfill() async {
    final snap = await _db.collection(AdminConstants.colBookings).get();
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final aDate =
            parseTimestamp(_asMap(a.data())['createdAt']) ?? DateTime(1970);
        final bDate =
            parseTimestamp(_asMap(b.data())['createdAt']) ?? DateTime(1970);
        return aDate.compareTo(bDate);
      });
    var batch = _db.batch();
    var opCount = 0;
    var updated = 0;
    final touchedTripCounters = <String, int>{};

    for (final doc in docs) {
      final raw = _asMap(doc.data());
      if (!_needsBookingBackfill(raw)) continue;

      final normalized = normalizeBookingData(doc.id, raw);
      final bookingRef = doc.reference;
      var noteCount = _asInt(raw['issueNotesCount']);
      if (!raw.containsKey('issueNotesCount') ||
          !raw.containsKey('issueStatus')) {
        final countSnap = await bookingRef
            .collection(AdminConstants.colBookingAdminNotes)
            .count()
            .get();
        noteCount = countSnap.count ?? noteCount;
      }

      final isCancelled = {
        'cancelled',
        'cancelled_by_rider',
        'cancelled_by_customer',
      }.contains(normalized['status']);
      final derivedIssueStatus = noteCount > 0 || isCancelled ? 'flagged' : '';
      final derivedReconciliationStatus =
          !_isMissing(raw['reconciliationStatus'])
          ? raw['reconciliationStatus']
          : (normalized['paymentStatus'] == 'held' && isCancelled)
          ? 'admin_review_required'
          : '';
      final accountingFields = _resolveBookingAccountingFields(doc.id, raw);

      final payload = <String, dynamic>{};
      if (_isMissing(raw['customerId'])) {
        payload['customerId'] = normalized['customerId'];
      }
      if (_isMissing(raw['userId'])) {
        payload['userId'] = normalized['userId'];
      }
      if (!_isMissing(normalized['driverId']) && _isMissing(raw['driverId'])) {
        payload['driverId'] = normalized['driverId'];
      }
      if (!_isMissing(normalized['riderId']) && _isMissing(raw['riderId'])) {
        payload['riderId'] = normalized['riderId'];
      }
      if (!raw.containsKey('issueNotesCount')) {
        payload['issueNotesCount'] = noteCount;
      }
      if (!raw.containsKey('issueStatus')) {
        payload['issueStatus'] = derivedIssueStatus;
      }
      if (!raw.containsKey('reconciliationStatus')) {
        payload['reconciliationStatus'] = derivedReconciliationStatus;
      }
      if (_isMissing(raw['tripNumber']) ||
          _isMissing(raw['tripDateKey']) ||
          _asInt(raw['tripSequence']) <= 0) {
        final tripDate =
            parseTimestamp(raw['createdAt']) ??
            parseTimestamp(raw['scheduledDateTime']) ??
            DateTime.now();
        final tripDateKey = _dateKey(tripDate);
        if (!touchedTripCounters.containsKey(tripDateKey)) {
          final counterSnap = await _db
              .collection(AdminConstants.colTripCounters)
              .doc(tripDateKey)
              .get();
          touchedTripCounters[tripDateKey] =
              (counterSnap.data()?['lastSequence'] as num?)?.toInt() ?? 0;
        }
        final nextSequence = touchedTripCounters[tripDateKey]! + 1;
        touchedTripCounters[tripDateKey] = nextSequence;
        payload['tripDateKey'] = tripDateKey;
        payload['tripSequence'] = nextSequence;
        payload['tripNumber'] = _buildTripNumber(tripDateKey, nextSequence);
      }
      if (raw['grossAmount'] == null) {
        payload['grossAmount'] = accountingFields['grossAmount'];
      }
      if (raw['partnerNetRate'] == null) {
        payload['partnerNetRate'] = accountingFields['partnerNetRate'];
      }
      if (raw['partnerNetAmount'] == null) {
        payload['partnerNetAmount'] = accountingFields['partnerNetAmount'];
      }
      if (raw['adminFeeRate'] == null) {
        payload['adminFeeRate'] = accountingFields['adminFeeRate'];
      }
      if (raw['adminFeeAmount'] == null) {
        payload['adminFeeAmount'] = accountingFields['adminFeeAmount'];
      }
      if (raw['vatRate'] == null) {
        payload['vatRate'] = accountingFields['vatRate'];
      }
      if (raw['vatAmount'] == null) {
        payload['vatAmount'] = accountingFields['vatAmount'];
      }
      if (raw['adminNetAmount'] == null) {
        payload['adminNetAmount'] = accountingFields['adminNetAmount'];
      }
      if (payload.isEmpty) continue;

      payload['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(bookingRef, payload, SetOptions(merge: true));
      opCount++;
      updated++;

      if (opCount >= _batchWriteLimit) {
        await batch.commit();
        batch = _db.batch();
        opCount = 0;
      }
    }

    for (final entry in touchedTripCounters.entries) {
      final counterRef = _db
          .collection(AdminConstants.colTripCounters)
          .doc(entry.key);
      batch.set(counterRef, {
        'dateKey': entry.key,
        'lastSequence': entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      opCount++;

      if (opCount >= _batchWriteLimit) {
        await batch.commit();
        batch = _db.batch();
        opCount = 0;
      }
    }

    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();
    batch.set(
      auditRef,
      _buildAuditEntry(
        action: AdminConstants.auditRunBackfill,
        entityType: 'bookings',
        entityId: 'bookings',
        reason:
            'Backfilled booking issue, reconciliation, trip number, and accounting metadata',
        after: {'documentsUpdated': updated},
      ),
    );
    opCount++;

    if (opCount > 0) {
      await batch.commit();
    }

    return updated;
  }

  // ─── Notifications ────────────────────────────────────────────────────────
  static Future<void> sendNotification({
    required String userId,
    required String userType,
    required String title,
    required String message,
    String type = 'admin_broadcast',
    String? referenceId,
  }) async {
    final ref = _db.collection(AdminConstants.colNotifications).doc();
    await ref.set({
      'id': ref.id,
      'userId': userId,
      'userType': userType,
      'title': title,
      'message': message,
      'body': message,
      'type': type,
      'referenceId': referenceId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot> streamRecentNotifications({int limit = 50}) =>
      _db
          .collection(AdminConstants.colNotifications)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots();

  static Stream<QuerySnapshot> streamEmailNotifications({int limit = 50}) => _db
      .collection(AdminConstants.colEmailNotifications)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots();

  static Future<int> sendBroadcastNotifications({
    required String targetType,
    required String title,
    required String message,
  }) async {
    final targetCollection = targetType == 'all_customers'
        ? AdminConstants.colUsers
        : AdminConstants.colRiders;
    final userType = targetType == 'all_customers' ? 'customer' : 'rider';
    final targetSnap = await _db.collection(targetCollection).get();
    final recipients = targetSnap.docs;

    for (
      var offset = 0;
      offset < recipients.length;
      offset += _batchWriteLimit
    ) {
      final batch = _db.batch();
      final slice = recipients.skip(offset).take(_batchWriteLimit);

      for (final recipient in slice) {
        final ref = _db.collection(AdminConstants.colNotifications).doc();
        batch.set(ref, {
          'id': ref.id,
          'userId': recipient.id,
          'userType': userType,
          'title': title,
          'message': message,
          'body': message,
          'type': 'admin_broadcast',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (offset + _batchWriteLimit >= recipients.length) {
        final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();
        batch.set(
          auditRef,
          _buildAuditEntry(
            action: AdminConstants.auditSendNotification,
            entityType: 'notification',
            entityId: 'broadcast',
            reason: '$title — audience: $targetType',
            after: {
              'audience': targetType,
              'recipientCount': recipients.length,
              'title': title,
              'message': message,
            },
          ),
        );
      }

      await batch.commit();
    }

    return recipients.length;
  }

  // ─── Promo Banners ────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamPromoBanners() => _db
      .collection(AdminConstants.colPromoBanners)
      .orderBy('createdAt', descending: true)
      .snapshots();

  static Future<String> upsertBanner(
    String? id,
    Map<String, dynamic> data,
  ) async {
    final bannerCollection = _db.collection(AdminConstants.colPromoBanners);
    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();

    if (id != null) {
      final docRef = bannerCollection.doc(id);
      final beforeSnap = await docRef.get();
      final beforeData = _asMap(beforeSnap.data());
      final nextData = {...data, 'updatedAt': FieldValue.serverTimestamp()};
      final batch = _db.batch();
      batch.set(docRef, nextData, SetOptions(merge: true));
      batch.set(
        auditRef,
        _buildAuditEntry(
          action: AdminConstants.auditPublishBanner,
          entityType: 'promo_banner',
          entityId: id,
          before: beforeData,
          after: data,
        ),
      );
      await batch.commit();
      return id;
    }

    final docRef = bannerCollection.doc();
    final batch = _db.batch();
    batch.set(docRef, {
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      auditRef,
      _buildAuditEntry(
        action: AdminConstants.auditPublishBanner,
        entityType: 'promo_banner',
        entityId: docRef.id,
        after: data,
      ),
    );
    await batch.commit();
    return docRef.id;
  }

  static Future<void> deleteBanner(String bannerId) async {
    final bannerRef = _db
        .collection(AdminConstants.colPromoBanners)
        .doc(bannerId);
    final auditRef = _db.collection(AdminConstants.colAdminAuditLogs).doc();
    final bannerSnap = await bannerRef.get();
    final beforeData = _asMap(bannerSnap.data());
    final batch = _db.batch();
    batch.delete(bannerRef);
    batch.set(
      auditRef,
      _buildAuditEntry(
        action: AdminConstants.auditDeleteBanner,
        entityType: 'promo_banner',
        entityId: bannerId,
        before: beforeData,
      ),
    );
    await batch.commit();
  }

  // ─── Audit Logs ───────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamAuditLogs({int limit = 100}) => _db
      .collection(AdminConstants.colAdminAuditLogs)
      .orderBy('timestamp', descending: true)
      .limit(limit)
      .snapshots();

  // ─── Dashboard aggregates ─────────────────────────────────────────────────
  static Future<Map<String, int>> getBookingStatusCounts() async {
    final snap = await _db.collection(AdminConstants.colBookings).get();
    final counts = <String, int>{};
    for (final doc in snap.docs) {
      final status = (doc.data()['status'] as String?) ?? 'unknown';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  static Future<int> countPendingRiderApprovals() async {
    final snap = await _db
        .collection(AdminConstants.colRiders)
        .where('accountStatus', isEqualTo: 'pending')
        .count()
        .get();
    return snap.count ?? 0;
  }

  static Future<int> countUsers() async {
    final snap = await _db.collection(AdminConstants.colUsers).count().get();
    return snap.count ?? 0;
  }

  // ── Support Tickets ──────────────────────────────────────────────────────

  /// Atomically generates the next TICKET#XXXXX number.
  static Future<String> _getNextTicketNumber() async {
    final counterRef = _db.collection('meta').doc('ticket_counter');
    int nextCount = 1;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(counterRef);
      if (snap.exists) {
        nextCount = ((snap.data()?['count'] as int?) ?? 0) + 1;
        tx.update(counterRef, {'count': nextCount});
      } else {
        nextCount = 1;
        tx.set(counterRef, {'count': 1});
      }
    });
    return 'TICKET#${nextCount.toString().padLeft(5, '0')}';
  }

  /// Streams all support tickets, optionally filtered by one or more statuses.
  static Stream<QuerySnapshot> streamSupportTickets({List<String>? statuses}) {
    Query q = _db
        .collection('support_tickets')
        .orderBy('createdAt', descending: true);
    if (statuses != null && statuses.length == 1) {
      q = q.where('status', isEqualTo: statuses.first);
    } else if (statuses != null && statuses.isNotEmpty) {
      q = q.where('status', whereIn: statuses);
    }
    return q.snapshots();
  }

  /// Streams the messages subcollection for a ticket (oldest first).
  static Stream<QuerySnapshot> streamTicketMessages(String ticketId) {
    return _db
        .collection('support_tickets')
        .doc(ticketId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Admin creates a ticket on behalf of a caller (CSR workflow).
  static Future<String?> createTicketForCaller({
    required String callerName,
    required String subject,
    required String description,
    required String category,
    String? tripNumber,
  }) async {
    try {
      final ticketNumber = await _getNextTicketNumber();
      final now = DateTime.now().toIso8601String();
      final docRef = _db.collection('support_tickets').doc();

      await docRef.set({
        'ticketNumber': ticketNumber,
        'subject': subject,
        'description': description,
        'category': category,
        'status': 'open',
        'submittedBy': 'admin',
        'submittedByType': 'admin',
        'submittedByName': callerName,
        'createdAt': now,
        'updatedAt': now,
        'lastMessageAt': now,
        'isEscalated': false,
        'csrAttempts': 0,
        'managerAttempts': 0,
        'escalationLevel': 'csr',
        if (tripNumber != null && tripNumber.isNotEmpty)
          'tripNumber': tripNumber,
      });

      // First message = caller description
      final msgRef = docRef.collection('messages').doc();
      await msgRef.set({
        'body': description,
        'senderId': 'admin',
        'senderType': 'admin',
        'senderName': 'Admin (on behalf of $callerName)',
        'createdAt': now,
      });

      return docRef.id;
    } catch (_) {
      return null;
    }
  }

  /// Posts a reply message from admin/coordinator/manager in a ticket thread.
  static Future<bool> addAdminMessage({
    required String ticketId,
    required String body,
    String senderName = 'Admin',
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final msgRef = _db
          .collection('support_tickets')
          .doc(ticketId)
          .collection('messages')
          .doc();

      await msgRef.set({
        'body': body,
        'senderId': 'admin',
        'senderType': 'admin',
        'senderName': senderName,
        'createdAt': now,
      });

      await _db.collection('support_tickets').doc(ticketId).update({
        'lastMessageAt': now,
        'updatedAt': now,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Marks a ticket as resolved, records resolution notes, and posts a system message.
  static Future<bool> resolveTicket({
    required String ticketId,
    required String resolutionNotes,
    String closedBy = 'Admin',
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final docRef = _db.collection('support_tickets').doc(ticketId);
      await docRef.update({
        'status': 'resolved',
        'resolvedAt': now,
        'resolvedBy': closedBy,
        'resolutionNotes': resolutionNotes,
        'closedBy': closedBy,
        'updatedAt': now,
      });
      // Post resolution system message in thread
      await docRef.collection('messages').doc().set({
        'body': '✅ RESOLVED by $closedBy\n\nResolution: $resolutionNotes',
        'senderId': 'system',
        'senderType': 'system',
        'senderName': 'System',
        'createdAt': now,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Escalates a ticket with attempt-based routing.
  /// [actorRole]: 'coordinator' increments csrAttempts (≥5 → escalated_manager);
  /// any other role increments managerAttempts (≥3 → escalated_presidential).
  static Future<bool> escalateTicket({
    required String ticketId,
    required String remarks,
    String actorRole = 'coordinator',
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final docRef = _db.collection('support_tickets').doc(ticketId);
      String msgBody = '';

      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final data = snap.data() ?? {};

        if (actorRole == 'coordinator') {
          final csrAttempts = ((data['csrAttempts'] as int?) ?? 0) + 1;
          if (csrAttempts >= 5) {
            msgBody =
                '🔴 ESCALATED TO MANAGER — CSR Attempt $csrAttempts/5 reached.\nRemarks: $remarks\nThis ticket now requires Manager attention.';
            tx.update(docRef, {
              'status': 'escalated_manager',
              'csrAttempts': csrAttempts,
              'isEscalated': true,
              'escalationLevel': 'manager',
              'escalationRemarks': remarks,
              'escalatedAt': now,
              'updatedAt': now,
            });
          } else {
            final remaining = 5 - csrAttempts;
            msgBody =
                '📋 CSR Attempt $csrAttempts/5 failed.\nRemarks: $remarks\n$remaining attempt(s) remaining before Manager escalation.';
            tx.update(docRef, {
              'status': 'pending',
              'csrAttempts': csrAttempts,
              'escalationRemarks': remarks,
              'updatedAt': now,
            });
          }
        } else {
          // manager / admin / president
          final managerAttempts = ((data['managerAttempts'] as int?) ?? 0) + 1;
          if (managerAttempts >= 3) {
            msgBody =
                '⚠️ PRESIDENTIAL APPEAL — Manager Attempt $managerAttempts/3 exhausted.\nRemarks: $remarks\nOnly President/CEO or Corporate Lawyer may now act on this case.';
            tx.update(docRef, {
              'status': 'escalated_presidential',
              'managerAttempts': managerAttempts,
              'isEscalated': true,
              'escalationLevel': 'presidential',
              'escalationRemarks': remarks,
              'escalatedAt': now,
              'updatedAt': now,
            });
          } else {
            final remaining = 3 - managerAttempts;
            msgBody =
                '🔴 Manager Attempt $managerAttempts/3 failed.\nRemarks: $remarks\n$remaining attempt(s) remaining before Presidential Appeal.';
            tx.update(docRef, {
              'status': 'escalated_manager',
              'managerAttempts': managerAttempts,
              'escalationRemarks': remarks,
              'updatedAt': now,
            });
          }
        }
      });

      // Post system message in thread
      await docRef.collection('messages').doc().set({
        'body': msgBody,
        'senderId': 'system',
        'senderType': 'system',
        'senderName': 'System',
        'createdAt': now,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Re-opens a resolved or escalated ticket.
  static Future<bool> reopenTicket(String ticketId) async {
    try {
      await _db.collection('support_tickets').doc(ticketId).update({
        'status': 'open',
        'isEscalated': false,
        'resolvedAt': null,
        'resolvedBy': null,
        'resolutionNotes': null,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
