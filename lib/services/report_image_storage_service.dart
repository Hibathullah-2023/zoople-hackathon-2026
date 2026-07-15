import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Cross-platform report image storage service.
/// Uses [Uint8List] bytes instead of dart:io [File] so it works on both
/// web and mobile platforms.
class ReportImageStorageService {
  final FirebaseStorage _storage;

  ReportImageStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  /// Upload report photo bytes to Firebase Storage.
  /// Path: report_media/{reportId}/{timestamp}_{fileName}
  ///
  /// Returns the Firebase Storage download URL on success.
  UploadTask uploadReportPhotoBytes({
    required String reportId,
    required Uint8List imageBytes,
    required String fileName,
  }) {
    final String path =
        'report_media/$reportId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final Reference ref = _storage.ref().child(path);

    final SettableMetadata metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'reportId': reportId,
        'uploadedAt': DateTime.now().toIso8601String(),
        'originalFileName': fileName,
      },
    );

    return ref.putData(imageBytes, metadata);
  }

  /// Upload with retry logic using bytes.
  /// If the upload task fails, it can be retried up to [maxRetries] times.
  Future<String> uploadWithRetry({
    required String reportId,
    required Uint8List imageBytes,
    required String fileName,
    int maxRetries = 3,
    void Function(double progress)? onProgress,
    StreamController<double>? progressController,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        final UploadTask task = uploadReportPhotoBytes(
          reportId: reportId,
          imageBytes: imageBytes,
          fileName: fileName,
        );

        // Pipe progress to listeners if provided
        final StreamSubscription<TaskSnapshot> subscription = task
            .snapshotEvents
            .listen(
              (snapshot) {
                if (snapshot.totalBytes > 0) {
                  final double progress =
                      snapshot.bytesTransferred / snapshot.totalBytes;
                  onProgress?.call(progress);
                  progressController?.add(progress);
                }
              },
              onError: (e) {
                debugPrint('Upload task snapshot error: $e');
              },
            );

        final TaskSnapshot snapshot = await task;
        await subscription.cancel();
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries || e is TimeoutException) {
          rethrow;
        }
        debugPrint(
          'Upload attempt $attempt failed, retrying in ${attempt * 2}s: $e',
        );
        // Exponential backoff
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  /// Delete all media associated with a report.
  Future<void> deleteReportMedia(String reportId) async {
    final Reference folderRef = _storage.ref().child('report_media/$reportId');
    try {
      final ListResult listResult = await folderRef.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
    } on FirebaseException catch (e) {
      // Ignore if the folder/files do not exist
      if (e.code != 'object-not-found') {
        rethrow;
      }
    }
  }
}
