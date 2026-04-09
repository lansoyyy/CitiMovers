class BookingFinanceBreakdown {
  final double grossAmount;
  final double partnerNetRate;
  final double partnerNetAmount;
  final double adminFeeRate;
  final double adminFeeAmount;
  final double vatRate;
  final double vatAmount;
  final double adminNetAmount;

  const BookingFinanceBreakdown({
    required this.grossAmount,
    required this.partnerNetRate,
    required this.partnerNetAmount,
    required this.adminFeeRate,
    required this.adminFeeAmount,
    required this.vatRate,
    required this.vatAmount,
    required this.adminNetAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'grossAmount': grossAmount,
      'partnerNetRate': partnerNetRate,
      'partnerNetAmount': partnerNetAmount,
      'adminFeeRate': adminFeeRate,
      'adminFeeAmount': adminFeeAmount,
      'vatRate': vatRate,
      'vatAmount': vatAmount,
      'adminNetAmount': adminNetAmount,
    };
  }
}

class BookingFinanceService {
  BookingFinanceService._();

  static const double partnerNetRate = 0.80;
  static const double adminFeeRate = 0.20;
  static const double vatRate = 0.02;

  static double resolveGrossAmount({
    required double estimatedFare,
    double loadingDemurrageFee = 0.0,
    double unloadingDemurrageFee = 0.0,
    double tipAmount = 0.0,
    double? persistedFinalFare,
  }) {
    final computedAmount =
        estimatedFare + loadingDemurrageFee + unloadingDemurrageFee + tipAmount;
    final persistedAmount = persistedFinalFare ?? 0.0;
    return persistedAmount > computedAmount ? persistedAmount : computedAmount;
  }

  static BookingFinanceBreakdown calculate({
    required double estimatedFare,
    double loadingDemurrageFee = 0.0,
    double unloadingDemurrageFee = 0.0,
    double tipAmount = 0.0,
    double? persistedFinalFare,
  }) {
    final grossAmount = resolveGrossAmount(
      estimatedFare: estimatedFare,
      loadingDemurrageFee: loadingDemurrageFee,
      unloadingDemurrageFee: unloadingDemurrageFee,
      tipAmount: tipAmount,
      persistedFinalFare: persistedFinalFare,
    );
    final adminFeeAmount = grossAmount * adminFeeRate;
    final partnerNetAmount = grossAmount * partnerNetRate;
    final vatAmount = grossAmount * vatRate;

    return BookingFinanceBreakdown(
      grossAmount: grossAmount,
      partnerNetRate: partnerNetRate,
      partnerNetAmount: partnerNetAmount,
      adminFeeRate: adminFeeRate,
      adminFeeAmount: adminFeeAmount,
      vatRate: vatRate,
      vatAmount: vatAmount,
      adminNetAmount: adminFeeAmount - vatAmount,
    );
  }
}
