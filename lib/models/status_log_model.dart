import 'package:cloud_firestore/cloud_firestore.dart';

/// Status log entry — tracks every status change on a report.
/// Stored in `/reports/{reportId}/statusLog/{logId}`.
class StatusLogModel {
  final String logId;
  final String reportId;
  final String previousStatus;
  final String newStatus;
  final String changedBy; // UID of admin/authority/SYSTEM
  final String changedByRole; // 'admin' | 'authority' | 'system'
  final String? note;
  final DateTime changedAt;

  const StatusLogModel({
    required this.logId,
    required this.reportId,
    required this.previousStatus,
    required this.newStatus,
    required this.changedBy,
    required this.changedByRole,
    this.note,
    required this.changedAt,
  });

  factory StatusLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StatusLogModel(
      logId: doc.id,
      reportId: data['reportId'] ?? '',
      previousStatus: data['previousStatus'] ?? '',
      newStatus: data['newStatus'] ?? '',
      changedBy: data['changedBy'] ?? '',
      changedByRole: data['changedByRole'] ?? 'system',
      note: data['note'],
      changedAt: (data['changedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reportId': reportId,
      'previousStatus': previousStatus,
      'newStatus': newStatus,
      'changedBy': changedBy,
      'changedByRole': changedByRole,
      'note': note,
      'changedAt': Timestamp.fromDate(changedAt),
    };
  }
}
