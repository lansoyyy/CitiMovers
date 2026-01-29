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

  // Convert to Map (standardized naming)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'pickupLocation': pickupLocation,
      'deliveryLocation': deliveryLocation,
      'distance': distance,
      'estimatedTime': estimatedTime,
      'fare': fare,
      'packageType': packageType,
      'weight': weight,
      'urgency': urgency,
      'specialInstructions': specialInstructions,
      'requestTime': requestTime,
    };
  }

  // Create from Map (standardized naming)
  factory DeliveryRequest.fromMap(Map<String, dynamic> map) {
    return DeliveryRequest(
      id: map['id'] as String,
      customerName: map['customerName'] as String,
      customerPhone: map['customerPhone'] as String,
      pickupLocation: map['pickupLocation'] as String,
      deliveryLocation: map['deliveryLocation'] as String,
      distance: map['distance'] as String,
      estimatedTime: map['estimatedTime'] as String,
      fare: map['fare'] as String,
      packageType: map['packageType'] as String,
      weight: map['weight'] as String,
      urgency: map['urgency'] as String,
      specialInstructions: map['specialInstructions'] as String,
      requestTime: map['requestTime'] as String,
    );
  }

  // Copy with method for immutable updates
  DeliveryRequest copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    String? pickupLocation,
    String? deliveryLocation,
    String? distance,
    String? estimatedTime,
    String? fare,
    String? packageType,
    String? weight,
    String? urgency,
    String? specialInstructions,
    String? requestTime,
  }) {
    return DeliveryRequest(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      distance: distance ?? this.distance,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      fare: fare ?? this.fare,
      packageType: packageType ?? this.packageType,
      weight: weight ?? this.weight,
      urgency: urgency ?? this.urgency,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      requestTime: requestTime ?? this.requestTime,
    );
  }

  @override
  String toString() {
    return 'DeliveryRequest(id: $id, customerName: $customerName, pickup: $pickupLocation, delivery: $deliveryLocation, fare: $fare)';
  }
}
