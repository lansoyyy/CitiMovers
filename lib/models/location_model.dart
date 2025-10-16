/// Location Model for CitiMovers
/// Represents a location with coordinates and address details
class LocationModel {
  final String? id;
  final String address;
  final String? label; // e.g., "Home", "Work", "Office"
  final double latitude;
  final double longitude;
  final String? city;
  final String? province;
  final String? postalCode;
  final String? country;
  final DateTime? createdAt;
  final bool isFavorite;

  LocationModel({
    this.id,
    required this.address,
    this.label,
    required this.latitude,
    required this.longitude,
    this.city,
    this.province,
    this.postalCode,
    this.country,
    this.createdAt,
    this.isFavorite = false,
  });

  /// Create LocationModel from Firestore document
  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      id: map['id'] as String?,
      address: map['address'] as String,
      label: map['label'] as String?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      city: map['city'] as String?,
      province: map['province'] as String?,
      postalCode: map['postalCode'] as String?,
      country: map['country'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : null,
      isFavorite: map['isFavorite'] as bool? ?? false,
    );
  }

  /// Convert LocationModel to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'address': address,
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
      'province': province,
      'postalCode': postalCode,
      'country': country,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'isFavorite': isFavorite,
    };
  }

  /// Create a copy with updated fields
  LocationModel copyWith({
    String? id,
    String? address,
    String? label,
    double? latitude,
    double? longitude,
    String? city,
    String? province,
    String? postalCode,
    String? country,
    DateTime? createdAt,
    bool? isFavorite,
  }) {
    return LocationModel(
      id: id ?? this.id,
      address: address ?? this.address,
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  /// Get short address (first line only)
  String get shortAddress {
    final parts = address.split(',');
    return parts.isNotEmpty ? parts[0].trim() : address;
  }

  /// Get formatted address with label
  String get displayAddress {
    if (label != null && label!.isNotEmpty) {
      return '$label - $address';
    }
    return address;
  }

  @override
  String toString() {
    return 'LocationModel(address: $address, lat: $latitude, lng: $longitude)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LocationModel &&
        other.id == id &&
        other.address == address &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        address.hashCode ^
        latitude.hashCode ^
        longitude.hashCode;
  }
}
