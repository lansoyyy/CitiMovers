import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

/// Storage Service for handling file uploads
/// Integrated with Firebase Storage
class StorageService {
  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload profile photo
  /// Returns the download URL of the uploaded image
  Future<String?> uploadProfilePhoto(File imageFile, String userId) async {
    try {
      // Validate image file
      if (!validateImageFile(imageFile)) {
        print('Invalid image file');
        return null;
      }

      final fileExtension = path.extension(imageFile.path);
      final fileName = 'profile_$userId$fileExtension';
      final storageRef = _storage.ref().child('profile_photos').child(fileName);

      final uploadTask = await storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: _getContentType(fileExtension),
        ),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile photo: $e');
      return null;
    }
  }

  /// Delete profile photo
  Future<bool> deleteProfilePhoto(String userId) async {
    try {
      // Try to delete with common extensions
      final extensions = ['.jpg', '.jpeg', '.png', '.webp'];

      for (final ext in extensions) {
        try {
          final fileName = 'profile_$userId$ext';
          final storageRef =
              _storage.ref().child('profile_photos').child(fileName);

          await storageRef.delete();
        } catch (e) {
          // File might not exist with this extension, continue
          continue;
        }
      }

      return true;
    } catch (e) {
      print('Error deleting profile photo: $e');
      return false;
    }
  }

  /// Upload delivery proof photo
  Future<String?> uploadDeliveryPhoto(
    File imageFile,
    String bookingId,
    String stage,
  ) async {
    try {
      // Validate image file
      if (!validateImageFile(imageFile)) {
        print('Invalid image file');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(imageFile.path);
      final fileName = '${stage}_$timestamp$fileExtension';
      final storageRef = _storage
          .ref()
          .child('delivery_photos')
          .child(bookingId)
          .child(fileName);

      final uploadTask = await storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: _getContentType(fileExtension),
        ),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading delivery photo: $e');
      return null;
    }
  }

  /// Upload complaint photo
  Future<String?> uploadComplaintPhoto(
    File imageFile,
    String complaintId,
  ) async {
    try {
      // Validate image file
      if (!validateImageFile(imageFile)) {
        print('Invalid image file');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(imageFile.path);
      final fileName = '$timestamp$fileExtension';
      final storageRef = _storage
          .ref()
          .child('complaint_photos')
          .child(complaintId)
          .child(fileName);

      final uploadTask = await storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: _getContentType(fileExtension),
        ),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading complaint photo: $e');
      return null;
    }
  }

  /// Upload rider document
  Future<String?> uploadRiderDocument(
    File imageFile,
    String riderId,
    String
        documentType, // e.g., 'license', 'vehicle_registration', 'nbi_clearance'
  ) async {
    try {
      // Validate image file
      if (!validateImageFile(imageFile)) {
        print('Invalid image file');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(imageFile.path);
      final fileName = '${documentType}_$timestamp$fileExtension';
      final storageRef = _storage
          .ref()
          .child('rider_documents')
          .child(riderId)
          .child(fileName);

      final uploadTask = await storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: _getContentType(fileExtension),
        ),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading rider document: $e');
      return null;
    }
  }

  /// Upload vehicle photo
  Future<String?> uploadVehiclePhoto(
    File imageFile,
    String riderId,
    String photoType, // e.g., 'front', 'back', 'side', 'interior'
  ) async {
    try {
      // Validate image file
      if (!validateImageFile(imageFile)) {
        print('Invalid image file');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(imageFile.path);
      final fileName = '${photoType}_$timestamp$fileExtension';
      final storageRef =
          _storage.ref().child('vehicle_photos').child(riderId).child(fileName);

      final uploadTask = await storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: _getContentType(fileExtension),
        ),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading vehicle photo: $e');
      return null;
    }
  }

  /// Upload promo banner image
  Future<String?> uploadPromoBannerImage(
    File imageFile,
    String bannerId,
  ) async {
    try {
      // Validate image file
      if (!validateImageFile(imageFile, maxSizeMB: 10.0)) {
        print('Invalid image file');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(imageFile.path);
      final fileName = 'banner_$timestamp$fileExtension';
      final storageRef = _storage.ref().child('promo_banners').child(fileName);

      final uploadTask = await storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: _getContentType(fileExtension),
        ),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading promo banner image: $e');
      return null;
    }
  }

  /// Delete file from storage
  Future<bool> deleteFile(String storagePath) async {
    try {
      final storageRef = _storage.ref(storagePath);
      await storageRef.delete();
      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  /// Get download URL for a file
  Future<String?> getDownloadUrl(String storagePath) async {
    try {
      final storageRef = _storage.ref(storagePath);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Error getting download URL: $e');
      return null;
    }
  }

  /// Get file size in MB
  double getFileSizeInMB(File file) {
    final bytes = file.lengthSync();
    return bytes / (1024 * 1024);
  }

  /// Validate image file
  bool validateImageFile(File file, {double maxSizeMB = 5.0}) {
    // Check file size
    final sizeMB = getFileSizeInMB(file);
    if (sizeMB > maxSizeMB) {
      print('File size exceeds maximum allowed size of $maxSizeMB MB');
      return false;
    }

    // Check file extension
    final extension = file.path.split('.').last.toLowerCase();
    final validExtensions = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'];
    if (!validExtensions.contains(extension)) {
      print('Invalid file extension: $extension');
      return false;
    }

    return true;
  }

  /// Get content type based on file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  /// Get upload progress stream
  Stream<TaskSnapshot> getUploadProgress(String storagePath, File file) {
    final storageRef = _storage.ref(storagePath);
    final uploadTask = storageRef.putFile(file);
    return uploadTask.snapshotEvents;
  }

  /// List all files in a directory
  Future<ListResult> listFiles(String path) async {
    try {
      final storageRef = _storage.ref(path);
      return await storageRef.listAll();
    } catch (e) {
      print('Error listing files: $e');
      rethrow;
    }
  }

  /// Delete all files in a directory
  Future<bool> deleteDirectory(String path) async {
    try {
      final storageRef = _storage.ref(path);
      final result = await storageRef.listAll();

      for (final item in result.items) {
        await item.delete();
      }

      // Also delete subdirectories
      for (final prefix in result.prefixes) {
        await deleteDirectory(prefix.fullPath);
      }

      return true;
    } catch (e) {
      print('Error deleting directory: $e');
      return false;
    }
  }
}
