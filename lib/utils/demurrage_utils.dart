class DemurrageUtils {
  static const int _minutesPerBlock = 4 * 60;
  static const double _ratePerBlock = 0.25;

  static double calculateFee(Duration duration, double baseFare) {
    if (baseFare <= 0) {
      return 0.0;
    }

    final totalMinutes = duration.inMinutes;
    if (totalMinutes < _minutesPerBlock) {
      return 0.0;
    }

    final blocks = totalMinutes ~/ _minutesPerBlock;
    return blocks * _ratePerBlock * baseFare;
  }
}
