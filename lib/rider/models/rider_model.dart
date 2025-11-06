/// Model class for Rider/Driver in CitiMovers
class RiderModel {
  final String riderId;
  final String name;
  final String phoneNumber;
  final String? email;
  final String? photoUrl;
  final String vehicleType; // motorcycle, sedan, van, truck
  final String? vehiclePlateNumber;
  final String? vehicleModel;
  final String? vehicleColor;
  final String status; // pending, approved, active, inactive, suspended
  final bool isOnline;
  final double rating;
  final int totalDeliveries;
  final double totalEarnings;
  final double? currentLatitude;
  final double? currentLongitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  RiderModel({
    required this.riderId,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.photoUrl,
    required this.vehicleType,
    this.vehiclePlateNumber,
    this.vehicleModel,
    this.vehicleColor,
    required this.status,
    required this.isOnline,
    required this.rating,
    required this.totalDeliveries,
    required this.totalEarnings,
    this.currentLatitude,
    this.currentLongitude,
    required this.createdAt,
    required this.updatedAt,
  });

  // CopyWith method for immutable updates
  RiderModel copyWith({
    String? riderId,
    String? name,
    String? phoneNumber,
    String? email,
    String? photoUrl,
    String? vehicleType,
    String? vehiclePlateNumber,
    String? vehicleModel,
    String? vehicleColor,
    String? status,
    bool? isOnline,
    double? rating,
    int? totalDeliveries,
    double? totalEarnings,
    double? currentLatitude,
    double? currentLongitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RiderModel(
      riderId: riderId ?? this.riderId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlateNumber: vehiclePlateNumber ?? this.vehiclePlateNumber,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'riderId': riderId,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'photoUrl': photoUrl,
      'vehicleType': vehicleType,
      'vehiclePlateNumber': vehiclePlateNumber,
      'vehicleModel': vehicleModel,
      'vehicleColor': vehicleColor,
      'status': status,
      'isOnline': isOnline,
      'rating': rating,
      'totalDeliveries': totalDeliveries,
      'totalEarnings': totalEarnings,
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory RiderModel.fromJson(Map<String, dynamic> json) {
    return RiderModel(
      riderId: json['riderId'] as String,
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      email: json['email'] as String?,
      photoUrl: json['photoUrl'] as String?,
      vehicleType: json['vehicleType'] as String,
      vehiclePlateNumber: json['vehiclePlateNumber'] as String?,
      vehicleModel: json['vehicleModel'] as String?,
      vehicleColor: json['vehicleColor'] as String?,
      status: json['status'] as String,
      isOnline: json['isOnline'] as bool,
      rating: (json['rating'] as num).toDouble(),
      totalDeliveries: json['totalDeliveries'] as int,
      totalEarnings: (json['totalEarnings'] as num).toDouble(),
      currentLatitude: json['currentLatitude'] as double?,
      currentLongitude: json['currentLongitude'] as double?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  String toString() {
    return 'RiderModel(riderId: $riderId, name: $name, phoneNumber: $phoneNumber, vehicleType: $vehicleType, status: $status, isOnline: $isOnline, rating: $rating)';
  }
}
