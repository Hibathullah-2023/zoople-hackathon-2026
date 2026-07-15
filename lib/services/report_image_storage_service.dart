import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class ReportImageStorageService {
  final FirebaseStorage _storage;

  ReportImageStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  /// Start an upload task for a report photo.
  /// Path: reports/{reportId}/photo.jpg
  /// Automatically overwrites previous file at the path to prevent duplicates.
  UploadTask uploadReportPhoto({
    required String reportId,
    required File imageFile,
  }) {
    final String path = 'reports/$reportId/photo.jpg';
    final Reference ref = _storage.ref().child(path);

    final SettableMetadata metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'reportId': reportId,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    return ref.putFile(imageFile, metadata);
  }

  /// Helper to upload with retry logic.
  /// If the upload task fails, it can be retried up to [maxRetries] times.
  Future<String> uploadWithRetry({
    required String reportId,
    required File imageFile,
    int maxRetries = 3,
    void Function(double progress)? onProgress,
    StreamController<double>? progressController,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        final UploadTask task = uploadReportPhoto(
          reportId: reportId,
          imageFile: imageFile,
        );

        // Pipe progress to listeners if provided
        final StreamSubscription<TaskSnapshot> subscription = task
            .snapshotEvents
            .listen(
              (snapshot) {
                final double progress =
                    snapshot.bytesTransferred / snapshot.totalBytes;
                onProgress?.call(progress);
                progressController?.add(progress);
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
        // Exponential backoff
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  /// Delete all media associated with a report.
  Future<void> deleteReportImage(String reportId) async {
    final String path = 'reports/$reportId/photo.jpg';
    final Reference ref = _storage.ref().child(path);
    try {
      await ref.delete();
    } on FirebaseException catch (e) {
      // Ignore if the file does not exist (to prevent crash on deletion of reports without images)
      if (e.code != 'object-not-found') {
        rethrow;
      }
    }
  }
}

// Global logger helper
void debugPrint(String message) {
  // ignore: avoid_print
  print('[ReportImageStorageService] $message');
}
