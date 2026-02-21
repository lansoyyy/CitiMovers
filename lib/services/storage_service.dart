import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../utils/retry_utility.dart';

/// Storage Service for handling file uploads
/// Integrated with Firebase Storage
class StorageService {
  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<File> _compressImageIfNeeded(
    File file, {
    int quality = 75,
    int minWidth = 1280,
    int minHeight = 1280,
  }) async {
    try {
      if (kIsWeb) return file;
      if (!file.existsSync()) return file;

      final ext = path.extension(file.path).toLowerCase();
      final format = (ext == '.png') ? CompressFormat.png : CompressFormat.jpeg;

      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outExt = (format == CompressFormat.png) ? '.png' : '.jpg';
      final outPath = path.join(dir.path, 'citimovers_upload_$ts$outExt');

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: format,
      );

      if (result == null) return file;

      final originalBytes = file.lengthSync();
      final compressedFile = File(result.path);
      final compressedBytes = compressedFile.lengthSync();
      if (compressedBytes > 0 && compressedBytes < originalBytes) {
        return compressedFile;
      }
      return file;
    } catch (_) {
      return file;
    }
  }

  /// Upload profile photo
  /// Returns the download URL of the uploaded image
  Future<String?> uploadProfilePhoto(File imageFile, String userId) async {
    try {
      // Validate image file
      if (!validateImageFile(imageFile, maxSizeMB: 50.0)) {
        debugPrint('StorageService: Invalid image file');
        return null;
      }

      final compressed = await _compressImageIfNeeded(imageFile);

      if (!validateImageFile(compressed)) {
        debugPrint('StorageService: Invalid compressed image file');
        return null;
      }

      final fileExtension = path.extension(compressed.path);
      final fileName = 'profile_$userId$fileExtension';
      final storageRef = _storage.ref().child('profile_photos').child(fileName);

      final uploadTask = await RetryUtility.retryUploadOperation(() async {
        return await storageRef.putFile(
          compressed,
          SettableMetadata(
            contentType: _getContentType(fileExtension),
          ),
        );
      });

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('StorageService: Error uploading profile photo: $e');
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
      debugPrint('StorageService: Error deleting profile photo: $e');
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
      if (!validateImageFile(imageFile, maxSizeMB: 50.0)) {
        debugPrint('StorageService: Invalid image file');
        return null;
      }

      final compressed = await _compressImageIfNeeded(imageFile);

      if (!validateImageFile(compressed)) {
        debugPrint('StorageService: Invalid compressed image file');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(compressed.path);
      final fileName = '${stage}_$timestamp$fileExtension';
      final storageRef = _storage
          .ref()
          .child('delivery_photos')
          .child(bookingId)
          .child(fileName);

      // Add timeout to prevent indefinite loading
      const uploadTimeout = Duration(minutes: 3);
      const perAttemptTimeout = Duration(seconds: 60);

      String? downloadUrl;

      try {
        // Upload with timeout on the entire operation (including retries)
        downloadUrl = await RetryUtility.retryUploadOperation(() async {
          return await storageRef
              .putFile(
                compressed,
                SettableMetadata(
                  contentType: _getContentType(fileExtension),
                ),
              )
              .then((task) => task.ref.getDownloadURL())
              .timeout(
            perAttemptTimeout,
            onTimeout: () {
              debugPrint(
                  'StorageService: Upload attempt timeout after $perAttemptTimeout');
              throw TimeoutException(
                  'Upload attempt timed out after $perAttemptTimeout');
            },
          );
        }).timeout(
          uploadTimeout,
          onTimeout: () {
            debugPrint('StorageService: Upload timeout after $uploadTimeout');
            throw TimeoutException('Upload timed out after $uploadTimeout');
          },
        );

        return downloadUrl;
      } on TimeoutException catch (e) {
        debugPrint('StorageService: Upload timeout exception: $e');
        throw Exception(
            'Upload timed out. Please check your internet connection and try again.');
      }
    } catch (e) {
      debugPrint('StorageService: Error uploading delivery photo: $e');
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
      if (!validateImageFile(imageFile, maxSizeMB: 50.0)) {
        debugPrint('StorageService: Invalid image file');
        return null;
      }

      final compressed = await _compressImageIfNeeded(imageFile);

      if (!validateImageFile(compressed)) {
        debugPrint('StorageService: Invalid compressed image file');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(compressed.path);
      final fileName = '$timestamp$fileExtension';
      final storageRef = _storage
          .ref()
          .child('complaint_photos')
          .child(complaintId)
          .child(fileName);

      final uploadTask = await RetryUtility.retryUploadOperation(() async {
        return await storageRef.putFile(
          compressed,
          SettableMetadata(
            contentType: _getContentType(fileExtension),
          ),
        );
      });

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('StorageService: Error uploading complaint photo: $e');
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
      if (!validateImageFile(imageFile, maxSizeMB: 50.0)) {
        debugPrint('StorageService: Invalid image file');
        return null;
      }

      final compressed = await _compressImageIfNeeded(imageFile);

      if (!validateImageFile(compressed)) {
        debugPrint('StorageService: Invalid compressed image file');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(compressed.path);
      final fileName = '${documentType}_$timestamp$fileExtension';
      final storageRef = _storage
          .ref()
          .child('rider_documents')
          .child(riderId)
          .child(fileName);

      final uploadTask = await RetryUtility.retryUploadOperation(() async {
        return await storageRef.putFile(
          compressed,
          SettableMetadata(
            contentType: _getContentType(fileExtension),
          ),
        );
      });

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('StorageService: Error uploading rider document: $e');
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
      if (!validateImageFile(imageFile, maxSizeMB: 50.0)) {
        debugPrint('StorageService: Invalid image file');
        return null;
      }

      final compressed = await _compressImageIfNeeded(imageFile);

      if (!validateImageFile(compressed)) {
        debugPrint('StorageService: Invalid compressed image file');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(compressed.path);
      final fileName = '${photoType}_$timestamp$fileExtension';
      final storageRef =
          _storage.ref().child('vehicle_photos').child(riderId).child(fileName);

      final uploadTask = await RetryUtility.retryUploadOperation(() async {
        return await storageRef.putFile(
          compressed,
          SettableMetadata(
            contentType: _getContentType(fileExtension),
          ),
        );
      });

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('StorageService: Error uploading vehicle photo: $e');
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
      if (!validateImageFile(imageFile, maxSizeMB: 50.0)) {
        debugPrint('StorageService: Invalid image file');
        return null;
      }

      final compressed = await _compressImageIfNeeded(
        imageFile,
        quality: 80,
        minWidth: 1920,
        minHeight: 1080,
      );

      if (!validateImageFile(compressed, maxSizeMB: 10.0)) {
        debugPrint('StorageService: Invalid compressed image file');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(compressed.path);
      final fileName = 'banner_$timestamp$fileExtension';
      final storageRef = _storage.ref().child('promo_banners').child(fileName);

      final uploadTask = await RetryUtility.retryUploadOperation(() async {
        return await storageRef.putFile(
          compressed,
          SettableMetadata(
            contentType: _getContentType(fileExtension),
          ),
        );
      });

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('StorageService: Error uploading promo banner image: $e');
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
      debugPrint('StorageService: Error deleting file: $e');
      return false;
    }
  }

  /// Get download URL for a file
  Future<String?> getDownloadUrl(String storagePath) async {
    try {
      final storageRef = _storage.ref(storagePath);
      return await RetryUtility.retryNetworkOperation(
        () => storageRef.getDownloadURL(),
      );
    } catch (e) {
      debugPrint('StorageService: Error getting download URL: $e');
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
      debugPrint(
          'StorageService: File size exceeds maximum allowed size of $maxSizeMB MB');
      return false;
    }

    // Check file extension
    final extension = file.path.split('.').last.toLowerCase();
    final validExtensions = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'];
    if (!validExtensions.contains(extension)) {
      debugPrint('StorageService: Invalid file extension: $extension');
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
  Stream<TaskSnapshot> getUploadProgress(String storagePath, File file) async* {
    final storageRef = _storage.ref(storagePath);
    final compressed = await _compressImageIfNeeded(file);
    final uploadTask = storageRef.putFile(compressed);
    yield* uploadTask.snapshotEvents;
  }

  /// List all files in a directory
  Future<ListResult> listFiles(String path) async {
    try {
      final storageRef = _storage.ref(path);
      return await storageRef.listAll();
    } catch (e) {
      debugPrint('StorageService: Error listing files: $e');
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
      debugPrint('StorageService: Error deleting directory: $e');
      return false;
    }
  }

  /// Get all delivery photos for a booking
  Future<List<String>> getDeliveryPhotos(String bookingId) async {
    try {
      final storageRef =
          _storage.ref().child('delivery_photos').child(bookingId);
      final result = await RetryUtility.retryNetworkOperation(
        () => storageRef.listAll(),
      );

      final photoUrls = <String>[];
      for (final item in result.items) {
        final url = await RetryUtility.retryNetworkOperation(
          () => item.getDownloadURL(),
        );
        photoUrls.add(url);
      }

      return photoUrls;
    } catch (e) {
      debugPrint('StorageService: Error getting delivery photos: $e');
      return [];
    }
  }

  /// Get delivery photos by stage
  Future<Map<String, List<String>>> getDeliveryPhotosByStage(
      String bookingId) async {
    try {
      final storageRef =
          _storage.ref().child('delivery_photos').child(bookingId);
      final result = await RetryUtility.retryNetworkOperation(
        () => storageRef.listAll(),
      );

      final photosByStage = <String, List<String>>{
        'start_loading': [],
        'finish_loading': [],
        'start_unloading': [],
        'finish_unloading': [],
        'receiver_id': [],
      };

      for (final item in result.items) {
        final url = await RetryUtility.retryNetworkOperation(
          () => item.getDownloadURL(),
        );
        final name = item.name.toLowerCase();

        if (name.contains('start_loading')) {
          photosByStage['start_loading']!.add(url);
        } else if (name.contains('finish_loading')) {
          photosByStage['finish_loading']!.add(url);
        } else if (name.contains('start_unloading')) {
          photosByStage['start_unloading']!.add(url);
        } else if (name.contains('finish_unloading')) {
          photosByStage['finish_unloading']!.add(url);
        } else if (name.contains('receiver_id')) {
          photosByStage['receiver_id']!.add(url);
        }
      }

      return photosByStage;
    } catch (e) {
      debugPrint('StorageService: Error getting delivery photos by stage: $e');
      return {};
    }
  }
}
