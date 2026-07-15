import 'package:image_picker/image_picker.dart';

/// Service that performs simulated AI metadata checks for photos to verify
/// authenticity (checks for Photoshop editing EXIF signatures, compression footprints,
/// and AI model artifacts).
class ImageAnalyzerService {
  ImageAnalyzerService._();

  static Map<String, dynamic> analyzeImage(XFile file) {
    return _performAnalysis(file.name);
  }

  static Map<String, dynamic> analyzeImageUrl(String url) {
    String name = '';
    try {
      final uri = Uri.parse(url);
      name = uri.pathSegments.last;
    } catch (_) {
      name = url;
    }
    return _performAnalysis(name);
  }

  static Map<String, dynamic> _performAnalysis(String fileName) {
    final name = fileName.toLowerCase();

    // Default authentic results
    String status = 'Authentic';
    double confidence = 96.4;
    List<String> findings = [
      'EXIF headers match mobile camera capture profile.',
      'Quantization matrices match direct CMOS sensor defaults.',
      'No clone-stamp or localized pixel fabrication detected.',
    ];
    String cameraBrand = 'Apple';
    String cameraModel = 'iPhone 14 Pro';
    String software = 'iOS 17.4.1';
    double latitude = 9.9816; // Kerala coords
    double longitude = 76.2999;

    if (name.contains('photoshop') ||
        name.contains('psd') ||
        name.contains('edit') ||
        name.contains('modified') ||
        name.contains('scaled') ||
        name.contains('whatsapp')) {
      status = 'Edited / Fabricated';
      confidence = 87.5;
      findings = [
        'Quantization tables show compression mismatch (re-saved via editing software).',
        'EXIF Software tags indicating Lightroom/Photoshop edits found.',
        'Quantization table quantization mismatch (QT-QM) indicates double compression.',
        'High-frequency gradient disruption suggests local retouching.',
      ];
      cameraBrand = 'Canon';
      cameraModel = 'EOS R6';
      software = 'Adobe Photoshop 2024';
      latitude = 40.7128; // New York coordinates (fake location discrepancy!)
      longitude = -74.0060;
    } else if (name.contains('dall-e') ||
        name.contains('dalle') ||
        name.contains('midjourney') ||
        name.contains('stable_diffusion') ||
        name.contains('ai') ||
        name.contains('generated')) {
      status = 'AI Generated';
      confidence = 94.2;
      findings = [
        'Absence of camera hardware sensor fingerprint (EXIF tags empty).',
        'Anomalous color-channel noise covariance typical of diffusion models.',
        'High-frequency grid artifacts detected in GAN upsampling layers.',
        'Inconsistent directional illumination vector patterns.',
      ];
      cameraBrand = 'None';
      cameraModel = 'AI Diffusion Model';
      software = 'StableDiffusion-v2.1';
      latitude = 0.0;
      longitude = 0.0;
    }

    return {
      'status': status,
      'confidence': confidence,
      'findings': findings,
      'analyzedAt': DateTime.now().toIso8601String(),
      'fileName': fileName,
      'cameraBrand': cameraBrand,
      'cameraModel': cameraModel,
      'software': software,
      'gpsLatitude': latitude,
      'gpsLongitude': longitude,
    };
  }
}
