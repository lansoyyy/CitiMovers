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

  // Standardized naming: fromMap
  factory PromoBanner.fromMap(Map<String, dynamic> map) {
    return PromoBanner(
      id: map['id'] as String,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      actionUrl: map['actionUrl'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      startDate: map['startDate'] != null
          ? (map['startDate'] is Timestamp
              ? (map['startDate'] as Timestamp).toDate()
              : DateTime.parse(map['startDate'] as String))
          : null,
      endDate: map['endDate'] != null
          ? (map['endDate'] is Timestamp
              ? (map['endDate'] as Timestamp).toDate()
              : DateTime.parse(map['endDate'] as String))
          : null,
      displayOrder: map['displayOrder'] as int? ?? 0,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(map['updatedAt'] as String),
    );
  }

  // Standardized naming: toMap
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'actionUrl': actionUrl,
      'isActive': isActive,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'displayOrder': displayOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Backward compatibility: fromFirestore
  factory PromoBanner.fromFirestore(DocumentSnapshot doc) {
    return PromoBanner.fromMap(doc.data() as Map<String, dynamic>);
  }

  // Backward compatibility: toFirestore
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
