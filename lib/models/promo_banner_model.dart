import 'package:cloud_firestore/cloud_firestore.dart';

class PromoBanner {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String? actionUrl;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  PromoBanner({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.actionUrl,
    required this.isActive,
    this.startDate,
    this.endDate,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PromoBanner.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PromoBanner(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      actionUrl: data['actionUrl'],
      isActive: data['isActive'] ?? true,
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : null,
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      displayOrder: data['displayOrder'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'actionUrl': actionUrl,
      'isActive': isActive,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'displayOrder': displayOrder,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  bool get isValid {
    final now = DateTime.now();
    if (!isActive) return false;
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }
}
