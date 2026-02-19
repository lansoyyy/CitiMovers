import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper/Crew Member Model for CitiMovers
class HelperModel {
  final String name;
  final String? phoneNumber;
  final String? photoUrl;
  final Map<String, dynamic>? documents;

  HelperModel({
    required this.name,
    this.phoneNumber,
    this.photoUrl,
    this.documents,
  });

  factory HelperModel.fromMap(Map<String, dynamic> json) {
    return HelperModel(
      name: (json['name'] ?? '').toString(),
      phoneNumber: json['phoneNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      documents: json['documents'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (documents != null) 'documents': documents,
    };
  }
}

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
  final String? vehiclePhotoUrl;
  final String status; // pending, approved, active, inactive, suspended
  final bool isOnline;
  final double rating;
  final int totalDeliveries;
  final double totalEarnings;
  final double? currentLatitude;
  final double? currentLongitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Helper/Crew members
  final HelperModel? helper1;
  final HelperModel? helper2;

  // Documents with URLs
  final Map<String, dynamic>? documents;

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
    this.vehiclePhotoUrl,
    required this.status,
    required this.isOnline,
    required this.rating,
    required this.totalDeliveries,
    required this.totalEarnings,
    this.currentLatitude,
    this.currentLongitude,
    required this.createdAt,
    required this.updatedAt,
    this.helper1,
    this.helper2,
    this.documents,
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
    String? vehiclePhotoUrl,
    String? status,
    bool? isOnline,
    double? rating,
    int? totalDeliveries,
    double? totalEarnings,
    double? currentLatitude,
    double? currentLongitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    HelperModel? helper1,
    HelperModel? helper2,
    Map<String, dynamic>? documents,
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
      vehiclePhotoUrl: vehiclePhotoUrl ?? this.vehiclePhotoUrl,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      helper1: helper1 ?? this.helper1,
      helper2: helper2 ?? this.helper2,
      documents: documents ?? this.documents,
    );
  }

  // Convert to Map for Firestore (standardized naming)
  Map<String, dynamic> toMap() {
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
      'vehiclePhotoUrl': vehiclePhotoUrl,
      'status': status,
      'isOnline': isOnline,
      'rating': rating,
      'totalDeliveries': totalDeliveries,
      'totalEarnings': totalEarnings,
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (helper1 != null) 'helper1': helper1!.toMap(),
      if (helper2 != null) 'helper2': helper2!.toMap(),
      if (documents != null) 'documents': documents,
    };
  }

  // Create from Map (standardized naming - alias for backward compatibility)
  factory RiderModel.fromJson(Map<String, dynamic> json) {
    return RiderModel.fromMap(json);
  }

  // Create from Map (standardized naming)
  factory RiderModel.fromMap(Map<String, dynamic> json) {
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

    // Parse helpers from Firestore
    HelperModel? parseHelper(Map<String, dynamic>? helperData) {
      if (helperData == null) return null;
      return HelperModel.fromMap(helperData);
    }

    // Get helpers from either 'helpers' array or individual helper1/helper2 fields
    HelperModel? h1;
    HelperModel? h2;

    // Check for 'helpers' array first (newer format)
    final helpersList = json['helpers'] as List<dynamic>?;
    if (helpersList != null && helpersList.isNotEmpty) {
      h1 = parseHelper(helpersList[0] as Map<String, dynamic>?);
      if (helpersList.length > 1) {
        h2 = parseHelper(helpersList[1] as Map<String, dynamic>?);
      }
    }

    // Also check individual helper fields (alternative format)
    if (h1 == null && json['helper1Name'] != null) {
      h1 = HelperModel(
        name: (json['helper1Name'] ?? '').toString(),
        phoneNumber: json['helper1Phone'] as String?,
        photoUrl: json['helper1PhotoUrl'] as String?,
        documents: json['helper1Documents'] as Map<String, dynamic>?,
      );
    }
    if (h2 == null && json['helper2Name'] != null) {
      h2 = HelperModel(
        name: (json['helper2Name'] ?? '').toString(),
        phoneNumber: json['helper2Phone'] as String?,
        photoUrl: json['helper2PhotoUrl'] as String?,
        documents: json['helper2Documents'] as Map<String, dynamic>?,
      );
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
      vehiclePhotoUrl: json['vehiclePhotoUrl'] as String?,
      status: (json['status'] ?? 'pending').toString(),
      isOnline: (json['isOnline'] as bool?) ?? false,
      rating: parseDouble(json['rating']),
      totalDeliveries: parseInt(json['totalDeliveries']),
      totalEarnings: parseDouble(json['totalEarnings']),
      currentLatitude: (json['currentLatitude'] as num?)?.toDouble(),
      currentLongitude: (json['currentLongitude'] as num?)?.toDouble(),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
      helper1: h1,
      helper2: h2,
      documents: json['documents'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'RiderModel(riderId: $riderId, name: $name, phoneNumber: $phoneNumber, vehicleType: $vehicleType, status: $status, isOnline: $isOnline, rating: $rating)';
  }
}
