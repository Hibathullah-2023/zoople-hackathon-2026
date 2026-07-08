import 'package:cloud_firestore/cloud_firestore.dart';

/// Media metadata for a report attachment.
/// Stored in `/reports/{reportId}/media/{mediaId}`.
class MediaModel {
  final String mediaId;
  final String reportId;
  final String storagePath;
  final String? downloadUrl;
  final String contentType; // 'image/jpeg', 'image/png'
  final int sizeBytes;
  final DateTime uploadedAt;
  final bool metadataStripped;

  const MediaModel({
    required this.mediaId,
    required this.reportId,
    required this.storagePath,
    this.downloadUrl,
    this.contentType = 'image/jpeg',
    this.sizeBytes = 0,
    required this.uploadedAt,
    this.metadataStripped = true,
  });

  factory MediaModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MediaModel(
      mediaId: doc.id,
      reportId: data['reportId'] ?? '',
      storagePath: data['storagePath'] ?? '',
      downloadUrl: data['downloadUrl'],
      contentType: data['contentType'] ?? 'image/jpeg',
      sizeBytes: data['sizeBytes'] ?? 0,
      uploadedAt:
          (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadataStripped: data['metadataStripped'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reportId': reportId,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'metadataStripped': metadataStripped,
    };
  }
}

/// Pre-computed aggregate statistics.
/// Stored in `/aggregates/{docId}` (e.g., `daily_2026-07-08`).
class AggregateModel {
  final String docId;
  final int totalReports;
  final int resolvedReports;
  final int activeUsers;
  final int pendingReports;
  final Map<String, int> categoryBreakdown;
  final Map<String, int> priorityBreakdown;
  final Map<String, int> statusBreakdown;
  final Map<String, int> districtBreakdown; // For heat map
  final DateTime date;

  const AggregateModel({
    required this.docId,
    this.totalReports = 0,
    this.resolvedReports = 0,
    this.activeUsers = 0,
    this.pendingReports = 0,
    this.categoryBreakdown = const {},
    this.priorityBreakdown = const {},
    this.statusBreakdown = const {},
    this.districtBreakdown = const {},
    required this.date,
  });

  factory AggregateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AggregateModel(
      docId: doc.id,
      totalReports: data['totalReports'] ?? 0,
      resolvedReports: data['resolvedReports'] ?? 0,
      activeUsers: data['activeUsers'] ?? 0,
      pendingReports: data['pendingReports'] ?? 0,
      categoryBreakdown:
          Map<String, int>.from(data['categoryBreakdown'] ?? {}),
      priorityBreakdown:
          Map<String, int>.from(data['priorityBreakdown'] ?? {}),
      statusBreakdown: Map<String, int>.from(data['statusBreakdown'] ?? {}),
      districtBreakdown:
          Map<String, int>.from(data['districtBreakdown'] ?? {}),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'totalReports': totalReports,
      'resolvedReports': resolvedReports,
      'activeUsers': activeUsers,
      'pendingReports': pendingReports,
      'categoryBreakdown': categoryBreakdown,
      'priorityBreakdown': priorityBreakdown,
      'statusBreakdown': statusBreakdown,
      'districtBreakdown': districtBreakdown,
      'date': Timestamp.fromDate(date),
    };
  }
}
