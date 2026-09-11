class DemurrageUtils {
  DemurrageUtils._();

  /// Free time before demurrage fees start accruing (first block).
  static const int freeBlockMinutes = 4 * 60;

  /// Percentage of the base fare charged per completed 4-hour block.
  static const double ratePerBlock = 0.25;

  static const int _minutesPerBlock = freeBlockMinutes;

  /// Sources for the effective demurrage start, persisted to Firestore so the
  /// admin panel can show WHY the system began counting at a given time.
  static const String sourceArrival = 'arrival';
  static const String sourceCallTime = 'call_time';
  static const String sourceLoadingStart = 'loading_start';

  static double calculateFee(Duration duration, double baseFare) {
    if (baseFare <= 0) {
      return 0.0;
    }

    final totalMinutes = duration.inMinutes;
    if (totalMinutes < _minutesPerBlock) {
      return 0.0;
    }

    final blocks = totalMinutes ~/ _minutesPerBlock;
    return blocks * ratePerBlock * baseFare;
  }

  /// Resolves the effective demurrage start from the trip's key instants.
  ///
  /// Client rules:
  /// 1/5. If the unit arrives EARLIER than the call time, counting still
  ///      begins at the call time (waiting before the call time is free).
  /// 4.   If the unit arrives LATER than the call time, counting begins at
  ///      the actual arrival.
  /// 6.   If the unit arrives early AND physically starts loading before the
  ///      call time, counting begins at the loading start instead.
  ///
  /// Compressed: `start = min(loadingStart, max(arrival, callTime))`.
  /// With no call time recorded this degrades gracefully to the arrival time,
  /// which preserves the legacy behaviour.
  static ({DateTime start, String source}) resolveDemurrageStart({
    required DateTime arrival,
    DateTime? loadingStart,
    DateTime? callTime,
  }) {
    DateTime start = arrival;
    String source = sourceArrival;

    if (callTime != null && callTime.isAfter(arrival)) {
      start = callTime;
      source = sourceCallTime;
    }

    if (loadingStart != null && loadingStart.isBefore(start)) {
      start = loadingStart;
      source = sourceLoadingStart;
    }

    return (start: start, source: source);
  }
}
