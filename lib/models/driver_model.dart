/// Driver Model for CitiMovers
/// Represents a driver with their details and credentials
class DriverModel {
  final String driverId;
  final String name;
  final String phoneNumber;
  final String? email;
  final String? photoUrl;
  final String vehicleType;
  final String vehiclePlateNumber;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehiclePhotoUrl;
  final int? helpersCount;
  final List<String>? helpersNames;
  final double rating;
  final int totalDeliveries;
  final String licenseNumber;
  final String? licensePhotoUrl;
  final bool isVerified;
  final bool isAvailable;
  final DateTime? lastActive;

  DriverModel({
    required this.driverId,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.photoUrl,
    required this.vehicleType,
    required this.vehiclePlateNumber,
    this.vehicleModel,
    this.vehicleColor,
    this.vehiclePhotoUrl,
    this.helpersCount,
    this.helpersNames,
    this.rating = 0.0,
    this.totalDeliveries = 0,
    required this.licenseNumber,
    this.licensePhotoUrl,
    this.isVerified = false,
    this.isAvailable = true,
    this.lastActive,
  });

  /// Create DriverModel from Firestore document
  factory DriverModel.fromMap(Map<String, dynamic> map) {
    return DriverModel(
      driverId: map['driverId'] as String,
      name: map['name'] as String,
      phoneNumber: map['phoneNumber'] as String,
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      vehicleType: map['vehicleType'] as String,
      vehiclePlateNumber: map['vehiclePlateNumber'] as String,
      vehicleModel: map['vehicleModel'] as String?,
      vehicleColor: map['vehicleColor'] as String?,
      vehiclePhotoUrl: map['vehiclePhotoUrl'] as String?,
      helpersCount: map['helpersCount'] as int?,
      helpersNames: (map['helpersNames'] as List<dynamic>?)?.cast<String>(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalDeliveries: map['totalDeliveries'] as int? ?? 0,
      licenseNumber: map['licenseNumber'] as String,
      licensePhotoUrl: map['licensePhotoUrl'] as String?,
      isVerified: map['isVerified'] as bool? ?? false,
      isAvailable: map['isAvailable'] as bool? ?? true,
      lastActive: map['lastActive'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastActive'] as int)
          : null,
    );
  }

  /// Convert DriverModel to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'photoUrl': photoUrl,
      'vehicleType': vehicleType,
      'vehiclePlateNumber': vehiclePlateNumber,
      'vehicleModel': vehicleModel,
      'vehicleColor': vehicleColor,
      'vehiclePhotoUrl': vehiclePhotoUrl,
      'helpersCount': helpersCount,
      'helpersNames': helpersNames,
      'rating': rating,
      'totalDeliveries': totalDeliveries,
      'licenseNumber': licenseNumber,
      'licensePhotoUrl': licensePhotoUrl,
      'isVerified': isVerified,
      'isAvailable': isAvailable,
      'lastActive': lastActive?.millisecondsSinceEpoch,
    };
  }

  /// Get rating stars text
  String get ratingText {
    return '${rating.toStringAsFixed(1)} ⭐';
  }

  /// Get deliveries text
  String get deliveriesText {
    if (totalDeliveries == 0) return 'New Driver';
    if (totalDeliveries == 1) return '1 Delivery';
    return '$totalDeliveries Deliveries';
  }

  /// Mock driver for testing
  static DriverModel getMockDriver() {
    return DriverModel(
      driverId: 'driver_001',
      name: 'Pedro Santos',
      phoneNumber: '+639171234567',
      email: 'pedro.santos@example.com',
      photoUrl: 'https://via.placeholder.com/150',
      vehicleType: 'Wingvan',
      vehiclePlateNumber: 'ABC 1234',
      vehicleModel: 'Isuzu Elf',
      vehicleColor: 'White',
      vehiclePhotoUrl: 'https://via.placeholder.com/300x200',
      helpersCount: 2,
      helpersNames: ['Juan Dela Cruz', 'Maria Santos'],
      rating: 4.8,
      totalDeliveries: 156,
      licenseNumber: 'N01-12-345678',
      licensePhotoUrl: 'https://via.placeholder.com/400x250',
      isVerified: true,
      isAvailable: true,
      lastActive: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'DriverModel(name: $name, vehicle: $vehicleType, plate: $vehiclePlateNumber)';
  }
}
