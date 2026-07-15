import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' hide Query;
import 'package:firebase_database/firebase_database.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/repositories/report_repository.dart';
import '../../models/report_model.dart';
import '../../services/image_compression_service.dart';
import '../../services/report_image_storage_service.dart';

class ReportRepositoryImpl implements ReportRepository {
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _realtimeDb;
  final ReportImageStorageService _storageService;
  final ImageCompressionService _compressionService;

  ReportRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseDatabase? realtimeDb,
    ReportImageStorageService? storageService,
    ImageCompressionService? compressionService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _realtimeDb = realtimeDb ?? FirebaseDatabase.instance,
       _storageService = storageService ?? ReportImageStorageService(),
       _compressionService = compressionService ?? ImageCompressionService();

  @override
  Future<void> saveReportSync({
    required ReportModel report,
    File? imageFile,
  }) async {
    String? photoUrl;
    List<String> mediaUrls = List.from(report.mediaUrls);

    if (imageFile != null) {
      // 1. Get temporary path for compression
      final tempDir = await getTemporaryDirectory();
      final String targetPath =
          '${tempDir.path}/compressed_${report.reportId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 2. Compress and resize
      final File compressedFile = await _compressionService.compressAndResize(
        file: imageFile,
        targetPath: targetPath,
      );

      // 3. Upload to Storage
      photoUrl = await _storageService.uploadWithRetry(
        reportId: report.reportId,
        imageFile: compressedFile,
      );

      // Clean up temporary compressed file
      try {
        await compressedFile.delete();
      } catch (_) {}

      // Keep Firestore mediaUrls in sync
      if (!mediaUrls.contains(photoUrl)) {
        mediaUrls.add(photoUrl);
      }
    }

    final updatedReport = ReportModel(
      reportId: report.reportId,
      anonymousId: report.anonymousId,
      description: report.description,
      category: report.category,
      priority: report.priority,
      priorityBypassed: report.priorityBypassed,
      status: report.status,
      location: report.location,
      locationAddress: report.locationAddress,
      city: report.city,
      district: report.district,
      pincode: report.pincode,
      assignedAuthorityUid: report.assignedAuthorityUid,
      assignedBy: report.assignedBy,
      createdAt: report.createdAt,
      updatedAt: report.updatedAt,
      resolvedAt: report.resolvedAt,
      mediaUrls: mediaUrls,
      keywords: report.keywords,
      isAnonymous: report.isAnonymous,
      mediaCount: mediaUrls.length,
      photoAnalysis: report.photoAnalysis,
    );

    // 4. Save to Firestore (main database)
    await _firestore
        .collection('reports')
        .doc(report.reportId)
        .set(updatedReport.toFirestore());

    // 5. Synchronize to Realtime Database
    final Map<String, dynamic> rtdbData = {
      'latitude': report.location?.latitude,
      'longitude': report.location?.longitude,
      'createdAt': report.createdAt.millisecondsSinceEpoch,
    };

    if (photoUrl != null) {
      rtdbData['photoUrl'] = photoUrl;
    } else if (mediaUrls.isNotEmpty) {
      rtdbData['photoUrl'] = mediaUrls.first;
    }

    await _realtimeDb.ref('reports/${report.reportId}').set(rtdbData);
  }

  @override
  Future<void> deleteReportSync(String reportId) async {
    // 1. Delete from Firestore
    await _firestore.collection('reports').doc(reportId).delete();

    // 2. Delete from Realtime Database
    await _realtimeDb.ref('reports/$reportId').remove();

    // 3. Delete from Firebase Storage
    await _storageService.deleteReportImage(reportId);
  }

  @override
  Future<List<HeatMapPoint>> getMonthlyHeatMapData({
    required int year,
    required int month,
  }) async {
    // Calculate start and end timestamp of the selected month
    final DateTime startDate = DateTime(year, month, 1);
    final DateTime endDate = month == 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);

    final int startTimestamp = startDate.millisecondsSinceEpoch;
    final int endTimestamp = endDate.millisecondsSinceEpoch - 1;

    // Fetch reports between start and end timestamps from Realtime Database
    final DatabaseReference ref = _realtimeDb.ref('reports');
    final Query query = ref
        .orderByChild('createdAt')
        .startAt(startTimestamp)
        .endAt(endTimestamp);

    final DataSnapshot snap = await query.get();
    if (!snap.exists || snap.value == null) {
      return [];
    }

    final Map<String, int> locationCounts = {};
    final Map<String, List<double>> coordinatesMap = {};

    final Map<dynamic, dynamic> reportsMap =
        snap.value as Map<dynamic, dynamic>;
    reportsMap.forEach((key, value) {
      if (value is Map) {
        final double? lat = value['latitude'] != null
            ? (value['latitude'] as num).toDouble()
            : null;
        final double? lng = value['longitude'] != null
            ? (value['longitude'] as num).toDouble()
            : null;

        if (lat != null && lng != null) {
          // Group by coordinate truncated representation (5 decimal places is approx 1.1 meters accuracy)
          final String coordKey =
              '${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}';
          locationCounts[coordKey] = (locationCounts[coordKey] ?? 0) + 1;
          coordinatesMap[coordKey] = [lat, lng];
        }
      }
    });

    final List<HeatMapPoint> points = [];
    locationCounts.forEach((coordKey, occurrenceCount) {
      final List<double> coords = coordinatesMap[coordKey]!;
      points.add(
        HeatMapPoint(
          latitude: coords[0],
          longitude: coords[1],
          weight: occurrenceCount.toDouble(),
        ),
      );
    });

    return points;
  }
}
