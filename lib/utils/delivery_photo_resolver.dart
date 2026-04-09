import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DeliveryPhotoResolver {
  DeliveryPhotoResolver._();

  static Map<String, dynamic>? normalizePhotosMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  static String extractString(dynamic value) {
    if (value is String) return value.trim();
    if (value is Map) {
      final url = value['url'] ?? value['imageUrl'] ?? value['downloadUrl'];
      if (url is String && url.trim().isNotEmpty) return url.trim();
      final text = value['value'] ?? value['text'];
      if (text is String && text.trim().isNotEmpty) return text.trim();
    }
    return '';
  }

  static List<String> photoKeyCandidates(String key) {
    switch (key) {
      case 'warehouse_arrival':
        return [
          'warehouse_arrival',
          'pickup_arrival',
          'warehouse_arrival_photo_url',
          'pickup_arrival_photo_url',
        ];
      case 'destination_arrival':
        return [
          'destination_arrival',
          'dropoff_arrival',
          'destination_arrival_photo_url',
          'dropoff_arrival_photo_url',
        ];
      case 'start_loading':
        return [
          'start_loading',
          'start_loading_photo',
          'start_loading_photo_url',
          'loading_photo_url',
        ];
      case 'finish_loading':
        return [
          'finish_loading',
          'finished_loading',
          'finish_loading_photo',
          'finished_loading_photo',
          'finish_loading_photo_url',
        ];
      case 'start_unloading':
        return [
          'start_unloading',
          'start_unloading_photo',
          'start_unloading_photo_url',
        ];
      case 'finish_unloading':
        return [
          'finish_unloading',
          'finished_unloading',
          'finish_unloading_photo',
          'finished_unloading_photo',
          'finish_unloading_photo_url',
          'unloading_photo_url',
        ];
      case 'receiver_id':
        return ['receiver_id', 'receiver_id_photo', 'receiver_id_photo_url'];
      case 'receiver_signature':
        return ['receiver_signature', 'signature', 'receiver_signature_url'];
      case 'damage_photo':
        return ['damage_photo', 'damaged_boxes', 'empty_truck'];
      default:
        return [key];
    }
  }

  static List<String> metadataKeyCandidates(String key) {
    switch (key) {
      case 'destination_arrival_remarks':
        return ['destination_arrival_remarks', 'dropoff_arrival_remarks'];
      case 'warehouse_arrival_remarks':
        return ['warehouse_arrival_remarks', 'pickup_arrival_remarks'];
      default:
        return [key];
    }
  }

  static List<String> timeKeyCandidates(String key) {
    switch (key) {
      case 'warehouse_arrival':
        return ['pickup_arrival_time'];
      case 'destination_arrival':
        return ['dropoff_arrival_time'];
      case 'start_loading':
        return ['pickup_loading_start_time'];
      case 'finish_loading':
        return ['pickup_loading_finish_time'];
      case 'start_unloading':
        return ['dropoff_unloading_start_time'];
      case 'finish_unloading':
        return ['dropoff_unloading_finish_time'];
      default:
        return const [];
    }
  }

  static DateTime? _extractDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    if (value is Map) {
      return _extractDateTime(value['uploadedAt'] ?? value['timestamp']);
    }
    return null;
  }

  static String? resolvePhotoUrl(Map<String, dynamic>? photos, String key) {
    if (photos == null) return null;

    for (final candidate in photoKeyCandidates(key)) {
      final resolved = extractString(photos[candidate]);
      if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
        return resolved;
      }
    }

    if (key == 'service_invoice') {
      final invoiceEntries = photos.entries
          .where((entry) => entry.key.startsWith('service_invoice_'))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in invoiceEntries) {
        final resolved = extractString(entry.value);
        if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
          return resolved;
        }
      }
      final fallback = extractString(photos['service_invoice']);
      if (fallback.startsWith('http://') || fallback.startsWith('https://')) {
        return fallback;
      }
    }

    return null;
  }

  static DateTime? resolvePhotoUploadedAt(
      Map<String, dynamic>? photos, String key) {
    if (photos == null) return null;
    for (final candidate in photoKeyCandidates(key)) {
      final resolved = _extractDateTime(photos[candidate]);
      if (resolved != null) return resolved;
    }
    return null;
  }

  static String resolveMetadataText(Map<String, dynamic>? photos, String key) {
    if (photos == null) return '';
    for (final candidate in metadataKeyCandidates(key)) {
      final resolved = extractString(photos[candidate]);
      if (resolved.isNotEmpty) return resolved;
    }
    return '';
  }

  static String? resolvePhotoTimeText(
      Map<String, dynamic>? photos, String key) {
    final uploadedAt = resolvePhotoUploadedAt(photos, key);
    if (uploadedAt != null) {
      return DateFormat('h:mm a').format(uploadedAt);
    }

    if (photos == null) return null;
    for (final candidate in timeKeyCandidates(key)) {
      final resolved = extractString(photos[candidate]);
      if (resolved.isNotEmpty) return resolved;
    }
    return null;
  }
}
