import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import '../constants/app_constants.dart';

/// Storage service for secure media upload and EXIF metadata stripping.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Strips metadata (EXIF) from an image file by decoding and re-encoding it,
  /// then uploads it to Firebase Storage.
  /// Returns the download URL.
  Future<String> uploadReportPhoto({
    required String reportId,
    required File photoFile,
    required String fileName,
  }) async {
    // 1. Strip EXIF metadata by re-encoding
    final bytes = await photoFile.readAsBytes();
    final decodedImage = img.decodeImage(bytes);

    if (decodedImage == null) {
      throw Exception('Failed to decode image. Invalid format.');
    }

    // Re-encode as JPG with 80% quality (automatically strips metadata)
    final strippedBytes = img.encodeJpg(decodedImage, quality: 80);

    // 2. Define storage path
    final fileExtension = path.extension(fileName).toLowerCase();
    final cleanExtension = fileExtension.isEmpty ? '.jpg' : fileExtension;
    final storageRef = _storage
        .ref()
        .child(AppConstants.reportMediaStoragePath)
        .child(reportId)
        .child('${DateTime.now().millisecondsSinceEpoch}$cleanExtension');

    // 3. Upload bytes
    final uploadTask = storageRef.putData(
      strippedBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Delete all media associated with a report.
  Future<void> deleteReportMedia(String reportId) async {
    final folderRef = _storage
        .ref()
        .child(AppConstants.reportMediaStoragePath)
        .child(reportId);

    try {
      final listResult = await folderRef.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
    } catch (e) {
      // Ignore or handle folder not found
    }
  }
}
