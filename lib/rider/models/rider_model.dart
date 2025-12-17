import 'package:cloud_firestore/cloud_firestore.dart';

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
    DateTime parseDateTime(dynamic value) {
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    double parseDouble(dynamic value, {double fallback = 0.0}) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      return fallback;
    }

    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    return RiderModel(
      riderId: (json['riderId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phoneNumber: (json['phoneNumber'] ?? '').toString(),
      email: json['email'] as String?,
      photoUrl: json['photoUrl'] as String?,
      vehicleType: (json['vehicleType'] ?? 'AUV').toString(),
      vehiclePlateNumber: json['vehiclePlateNumber'] as String?,
      vehicleModel: json['vehicleModel'] as String?,
      vehicleColor: json['vehicleColor'] as String?,
      status: (json['status'] ?? 'pending').toString(),
      isOnline: (json['isOnline'] as bool?) ?? false,
      rating: parseDouble(json['rating']),
      totalDeliveries: parseInt(json['totalDeliveries']),
      totalEarnings: parseDouble(json['totalEarnings']),
      currentLatitude: (json['currentLatitude'] as num?)?.toDouble(),
      currentLongitude: (json['currentLongitude'] as num?)?.toDouble(),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
    );
  }

  @override
  String toString() {
    return 'RiderModel(riderId: $riderId, name: $name, phoneNumber: $phoneNumber, vehicleType: $vehicleType, status: $status, isOnline: $isOnline, rating: $rating)';
  }
}
