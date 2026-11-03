/// Capacity rules for rider/driver bookings.
///
/// A unit may hold at most two live bookings at the same time:
/// one scheduled booking and one realtime pickup booking. A new booking of
/// either type is blocked until the matching live delivery is completed.
class RiderBookingCapacity {
  RiderBookingCapacity._();

  static const int maxLiveBookings = 2;
  static const String scheduledType = 'scheduled';
  static const String realtimeType = 'realtime';

  /// Normalizes the booking type stored on booking documents.
  ///
  /// Legacy/on-demand values such as `now` and `on_demand` are treated as
  /// realtime pickup bookings.
  static String normalizeType(dynamic rawType) {
    final value = (rawType ?? '').toString().trim().toLowerCase();
    return value == scheduledType ? scheduledType : realtimeType;
  }

  static bool isScheduled(dynamic rawType) =>
      normalizeType(rawType) == scheduledType;

  static String typeLabel(dynamic rawType) =>
      isScheduled(rawType) ? 'scheduled' : 'realtime pickup';

  static String bookingId(Map<String, dynamic> booking) {
    return (booking['bookingId'] ?? booking['id'] ?? '').toString().trim();
  }

  /// Returns a human-readable conflict message for the given candidate
  /// booking, or `null` when the rider has room for it.
  static String? conflictMessage({
    required dynamic candidateBookingType,
    required Iterable<Map<String, dynamic>> liveBookings,
    String? excludingBookingId,
    String Function(Map<String, dynamic> booking)? referenceBuilder,
  }) {
    final candidateType = normalizeType(candidateBookingType);
    final others = <Map<String, dynamic>>[];
    for (final booking in liveBookings) {
      if (excludingBookingId != null &&
          bookingId(booking) == excludingBookingId) {
        continue;
      }
      others.add(booking);
    }

    if (others.length >= maxLiveBookings) {
      return _capacityMessage;
    }

    final sameType = others
        .where((booking) => normalizeType(booking['bookingType']) == candidateType)
        .toList();
    if (sameType.isNotEmpty) {
      final label = typeLabel(candidateType);
      final reference = referenceBuilder != null
          ? referenceBuilder(sameType.first).trim()
          : bookingId(sameType.first);
      final suffix = reference.isEmpty ? '' : ' ($reference)';
      return 'This unit already has an active $label booking$suffix. '
          'Complete that delivery before accepting another $label booking.';
    }

    return null;
  }

  /// Validates the rider's capacity slots directly. Used inside Firestore
  /// transactions where queries are not available.
  static String? slotConflictMessage({
    required dynamic candidateBookingType,
    required String? scheduledBookingId,
    required String? realtimeBookingId,
    String? candidateBookingId,
  }) {
    final candidateType = normalizeType(candidateBookingType);
    final resolvedCandidateId = (candidateBookingId ?? '').trim();
    final scheduledId = (scheduledBookingId ?? '').trim();
    final realtimeId = (realtimeBookingId ?? '').trim();

    final occupiedSlots = <String>{
      if (scheduledId.isNotEmpty) scheduledId,
      if (realtimeId.isNotEmpty) realtimeId,
    };
    if (occupiedSlots.length >= maxLiveBookings) {
      return _capacityMessage;
    }

    final sameTypeId =
        candidateType == scheduledType ? scheduledId : realtimeId;
    if (sameTypeId.isNotEmpty && sameTypeId != resolvedCandidateId) {
      final label = typeLabel(candidateType);
      return 'This unit already has an active $label booking ($sameTypeId). '
          'Complete that delivery before accepting another $label booking.';
    }

    return null;
  }

  static const String _capacityMessage =
      'This unit already has the maximum of $maxLiveBookings active bookings '
      '(1 scheduled and 1 realtime pickup). Complete a delivery before '
      'accepting another booking.';
}
