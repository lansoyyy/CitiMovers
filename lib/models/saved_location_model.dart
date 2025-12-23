import 'package:cloud_firestore/cloud_firestore.dart';

class SavedLocation {
  final String id;
  final String userId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? type; // 'home', 'office', 'other'
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedLocation({
    required this.id,
    required this.userId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.type,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavedLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavedLocation(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      type: data['type'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SavedLocation copyWith({
    String? id,
    String? userId,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedLocation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
