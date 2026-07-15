import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

/// Service for validating, resizing, and compressing report photos.
class ImageCompressionService {
  /// Validate file type and size.
  bool isValidImage(File file) {
    final String extension = path.extension(file.path).toLowerCase();
    final List<String> allowedExtensions = ['.jpg', '.jpeg', '.png'];
    if (!allowedExtensions.contains(extension)) {
      return false;
    }

    final int fileSize = file.lengthSync();
    const int maxSizeBytes = 10 * 1024 * 1024; // 10 MB limit
    if (fileSize > maxSizeBytes) {
      return false;
    }

    return true;
  }

  /// Compress and resize the file to a maximum width of 1080px.
  Future<File> compressAndResize({
    required File file,
    required String targetPath,
  }) async {
    if (!isValidImage(file)) {
      throw ArgumentError('Invalid image format or size exceeds 10MB.');
    }

    // Try to compress using native flutter_image_compress (unless running on Web where it's not supported)
    if (!kIsWeb) {
      try {
        final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          minWidth: 1080,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        if (compressed != null) {
          return File(compressed.path);
        }
      } catch (e) {
        debugPrint('Native compression failed, falling back to pure Dart: $e');
      }
    }

    // Fallback to pure Dart image package (extremely robust, supports all platforms including Web/Emulator)
    final bytes = await file.readAsBytes();
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Failed to decode image.');
    }

    // Resize if width is larger than 1080px
    if (decoded.width > 1080) {
      decoded = img.copyResize(decoded, width: 1080);
    }

    // Encode as JPG (automatically strips metadata EXIF tags)
    final compressedBytes = img.encodeJpg(decoded, quality: 80);
    final targetFile = File(targetPath);
    return await targetFile.writeAsBytes(compressedBytes);
  }
}
