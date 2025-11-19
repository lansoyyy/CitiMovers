class DeliveryRequest {
  final String id;
  final String customerName;
  final String customerPhone;
  final String pickupLocation;
  final String deliveryLocation;
  final String distance;
  final String estimatedTime;
  final String fare;
  final String packageType;
  final String weight;
  final String urgency;
  final String specialInstructions;
  final String requestTime;

  DeliveryRequest({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.distance,
    required this.estimatedTime,
    required this.fare,
    required this.packageType,
    required this.weight,
    required this.urgency,
    required this.specialInstructions,
    required this.requestTime,
  });
}
