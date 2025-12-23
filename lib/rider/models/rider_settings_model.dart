import 'package:cloud_firestore/cloud_firestore.dart';

/// Model class for Rider Settings in CitiMovers
class RiderSettingsModel {
  final String riderId;
  final bool pushNotifications;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool soundEffects;
  final bool vibration;
  final bool locationServices;
  final bool autoAcceptDeliveries;
  final String language;
  final String theme;
  final DateTime createdAt;
  final DateTime updatedAt;

  RiderSettingsModel({
    required this.riderId,
    this.pushNotifications = true,
    this.emailNotifications = false,
    this.smsNotifications = true,
    this.soundEffects = true,
    this.vibration = true,
    this.locationServices = true,
    this.autoAcceptDeliveries = false,
    this.language = 'English',
    this.theme = 'Light',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory RiderSettingsModel.fromMap(Map<String, dynamic> map) {
    return RiderSettingsModel(
      riderId: map['riderId'] as String,
      pushNotifications: (map['pushNotifications'] as bool?) ?? true,
      emailNotifications: (map['emailNotifications'] as bool?) ?? false,
      smsNotifications: (map['smsNotifications'] as bool?) ?? true,
      soundEffects: (map['soundEffects'] as bool?) ?? true,
      vibration: (map['vibration'] as bool?) ?? true,
      locationServices: (map['locationServices'] as bool?) ?? true,
      autoAcceptDeliveries: (map['autoAcceptDeliveries'] as bool?) ?? false,
      language: (map['language'] as String?) ?? 'English',
      theme: (map['theme'] as String?) ?? 'Light',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int))
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp
              ? (map['updatedAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'riderId': riderId,
      'pushNotifications': pushNotifications,
      'emailNotifications': emailNotifications,
      'smsNotifications': smsNotifications,
      'soundEffects': soundEffects,
      'vibration': vibration,
      'locationServices': locationServices,
      'autoAcceptDeliveries': autoAcceptDeliveries,
      'language': language,
      'theme': theme,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  RiderSettingsModel copyWith({
    String? riderId,
    bool? pushNotifications,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? soundEffects,
    bool? vibration,
    bool? locationServices,
    bool? autoAcceptDeliveries,
    String? language,
    String? theme,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RiderSettingsModel(
      riderId: riderId ?? this.riderId,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      soundEffects: soundEffects ?? this.soundEffects,
      vibration: vibration ?? this.vibration,
      locationServices: locationServices ?? this.locationServices,
      autoAcceptDeliveries: autoAcceptDeliveries ?? this.autoAcceptDeliveries,
      language: language ?? this.language,
      theme: theme ?? this.theme,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'RiderSettingsModel(riderId: $riderId, pushNotifications: $pushNotifications, language: $language, theme: $theme)';
  }
}
