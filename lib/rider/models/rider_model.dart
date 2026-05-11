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
    String? stringOrNull(dynamic value) {
      if (value == null) return null;
      final normalized = value.toString().trim();
      if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
        return null;
      }
      return normalized;
    }

    return HelperModel(
      name: stringOrNull(json['name']) ?? '',
      phoneNumber: stringOrNull(json['phoneNumber']),
      photoUrl: stringOrNull(json['photoUrl']),
      documents: json['documents'] is Map
          ? Map<String, dynamic>.from(json['documents'] as Map)
          : null,
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
  static const Map<String, String> documentLabels = {
    'drivers_license': "Driver's License",
    'vehicle_registration': 'Vehicle Registration (OR/CR)',
    'vehicle_registration_or': 'Vehicle Registration (OR)',
    'vehicle_registration_cr': 'Vehicle Registration (CR)',
    'ltfrb': 'LTFRB',
    'marine_insurance': 'Marine Insurance',
    'nbi_clearance': 'NBI Clearance',
    'drug_test': 'Drug Test',
    'national_police_clearance': 'Police Clearance',
    'fit_to_work': 'Fit to Work',
    'resume': 'Biodata / Resume',
    'valid_id': 'Valid ID',
    'unit_photo_front_plate_visible': 'Picture of Unit',
    'insurance': 'Insurance',
    'helper_1_drug_test': 'Helper 1 - Drug Test',
    'helper_1_national_police_clearance': 'Helper 1 - Police Clearance',
    'helper_1_fit_to_work': 'Helper 1 - Fit to Work',
    'helper_1_resume': 'Helper 1 - Biodata / Resume',
    'helper_1_valid_id': 'Helper 1 - Valid ID',
    'helper_2_drug_test': 'Helper 2 - Drug Test',
    'helper_2_national_police_clearance': 'Helper 2 - Police Clearance',
    'helper_2_fit_to_work': 'Helper 2 - Fit to Work',
    'helper_2_resume': 'Helper 2 - Biodata / Resume',
    'helper_2_valid_id': 'Helper 2 - Valid ID',
  };

  static const Set<String> _unitDocumentKeys = {
    'unit_photo_front_plate_visible',
    'vehicle_registration',
    'vehicle_registration_or',
    'vehicle_registration_cr',
    'insurance',
    'ltfrb',
    'marine_insurance',
  };

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

  Map<String, dynamic> _filterDocuments(bool Function(String key) test) {
    final source = documents;
    if (source == null || source.isEmpty) return const {};

    final filtered = <String, dynamic>{};
    for (final entry in source.entries) {
      if (test(entry.key)) {
        filtered[entry.key] = entry.value;
      }
    }
    return filtered;
  }

  static String labelForDocumentKey(String key) {
    return documentLabels[key] ??
        key.replaceAll('_', ' ').split(' ').map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1);
        }).join(' ');
  }

  Map<String, dynamic> get unitDocuments =>
      _filterDocuments((key) => _unitDocumentKeys.contains(key));

  Map<String, dynamic> get driverDocuments => _filterDocuments((key) {
        if (key.startsWith('helper_1_') || key.startsWith('helper_2_')) {
          return false;
        }
        return !_unitDocumentKeys.contains(key);
      });

  Map<String, dynamic> get helper1Documents =>
      _filterDocuments((key) => key.startsWith('helper_1_'));

  Map<String, dynamic> get helper2Documents =>
      _filterDocuments((key) => key.startsWith('helper_2_'));

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

    double? parseNullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        final normalized = value.trim();
        if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
          return null;
        }
        return double.tryParse(normalized);
      }
      return null;
    }

    bool parseBool(dynamic value, {bool fallback = false}) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        switch (value.trim().toLowerCase()) {
          case 'true':
          case '1':
          case 'yes':
          case 'y':
            return true;
          case 'false':
          case '0':
          case 'no':
          case 'n':
            return false;
        }
      }
      return fallback;
    }

    String? stringOrNull(dynamic value) {
      if (value == null) return null;
      final normalized = value.toString().trim();
      if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
        return null;
      }
      return normalized;
    }

    Map<String, dynamic>? parseMap(dynamic value) {
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return null;
    }

    final allDocuments = parseMap(json['documents']) ?? <String, dynamic>{};

    Map<String, dynamic>? extractHelperDocuments(String prefix) {
      final extracted = <String, dynamic>{};
      for (final entry in allDocuments.entries) {
        if (!entry.key.startsWith(prefix)) continue;
        extracted[entry.key.substring(prefix.length)] = entry.value;
      }
      return extracted.isEmpty ? null : extracted;
    }

    HelperModel? buildHelper({
      Map<String, dynamic>? helperData,
      required String prefix,
      String? fallbackName,
      String? fallbackPhone,
      String? fallbackPhotoUrl,
    }) {
      final parsed = helperData ?? <String, dynamic>{};
      final name = (parsed['name'] ?? fallbackName ?? '').toString().trim();
      final phone = (parsed['phoneNumber'] ?? fallbackPhone)?.toString();
      final photoUrl = (parsed['photoUrl'] ?? fallbackPhotoUrl)?.toString();
      final helperDocuments =
          parseMap(parsed['documents']) ?? extractHelperDocuments(prefix);

      final hasIdentity = name.isNotEmpty ||
          (phone != null && phone.isNotEmpty) ||
          (photoUrl != null && photoUrl.isNotEmpty) ||
          (helperDocuments != null && helperDocuments.isNotEmpty);

      if (!hasIdentity) return null;

      return HelperModel(
        name: name.isEmpty ? 'Unassigned' : name,
        phoneNumber: phone,
        photoUrl: photoUrl,
        documents: helperDocuments,
      );
    }

    // Get helpers from either 'helpers' array or individual helper1/helper2 fields
    HelperModel? h1;
    HelperModel? h2;

    // Check for 'helpers' array first (newer format)
    final helpersList = json['helpers'] as List<dynamic>?;
    if (helpersList != null && helpersList.isNotEmpty) {
      h1 = buildHelper(
        helperData: parseMap(helpersList[0]),
        prefix: 'helper_1_',
        fallbackName: stringOrNull(json['helper1Name']),
        fallbackPhone: stringOrNull(json['helper1Phone']),
        fallbackPhotoUrl: stringOrNull(json['helper1PhotoUrl']),
      );
      if (helpersList.length > 1) {
        h2 = buildHelper(
          helperData: parseMap(helpersList[1]),
          prefix: 'helper_2_',
          fallbackName: stringOrNull(json['helper2Name']),
          fallbackPhone: stringOrNull(json['helper2Phone']),
          fallbackPhotoUrl: stringOrNull(json['helper2PhotoUrl']),
        );
      }
    }

    // Also check individual helper fields (alternative format)
    if (h1 == null && (json['helper1'] != null || json['helper1Name'] != null)) {
      h1 = buildHelper(
        helperData: parseMap(json['helper1']),
        prefix: 'helper_1_',
        fallbackName: stringOrNull(json['helper1Name']),
        fallbackPhone: stringOrNull(json['helper1Phone']),
        fallbackPhotoUrl: stringOrNull(json['helper1PhotoUrl']),
      );
    }
    if (h2 == null && (json['helper2'] != null || json['helper2Name'] != null)) {
      h2 = buildHelper(
        helperData: parseMap(json['helper2']),
        prefix: 'helper_2_',
        fallbackName: stringOrNull(json['helper2Name']),
        fallbackPhone: stringOrNull(json['helper2Phone']),
        fallbackPhotoUrl: stringOrNull(json['helper2PhotoUrl']),
      );
    }

    return RiderModel(
      riderId: stringOrNull(json['riderId']) ?? '',
      name: stringOrNull(json['name']) ?? '',
      phoneNumber: stringOrNull(
            json['phoneNumber'] ?? json['phone'] ?? json['contactNumber'],
          ) ??
          '',
      email: stringOrNull(json['email']),
      photoUrl: stringOrNull(json['photoUrl']),
      vehicleType: stringOrNull(json['vehicleType']) ?? 'AUV',
      vehiclePlateNumber: stringOrNull(json['vehiclePlateNumber']),
      vehicleModel: stringOrNull(json['vehicleModel']),
      vehicleColor: stringOrNull(json['vehicleColor']),
      vehiclePhotoUrl: stringOrNull(json['vehiclePhotoUrl']),
      status: stringOrNull(json['accountStatus'] ?? json['status']) ?? 'pending',
      isOnline: parseBool(json['isOnline']),
      rating: parseDouble(json['rating']),
      totalDeliveries: parseInt(json['totalDeliveries']),
      totalEarnings: parseDouble(json['totalEarnings']),
      currentLatitude: parseNullableDouble(json['currentLatitude']),
      currentLongitude: parseNullableDouble(json['currentLongitude']),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
      helper1: h1,
      helper2: h2,
      documents: allDocuments,
    );
  }

  @override
  String toString() {
    return 'RiderModel(riderId: $riderId, name: $name, phoneNumber: $phoneNumber, vehicleType: $vehicleType, status: $status, isOnline: $isOnline, rating: $rating)';
  }
}
