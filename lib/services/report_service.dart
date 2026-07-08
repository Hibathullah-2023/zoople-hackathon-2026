import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../constants/priority_keywords.dart';
import '../models/report_model.dart';
import '../models/status_log_model.dart';

/// Report service — handles CRUD, auto-priority, status updates,
/// bypass routing, and real-time listeners.
class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Report ID Generation ───

  /// Generate a unique report ID in format NZ-YYMMDD-XXXXX
  String _generateReportId() {
    final now = DateTime.now();
    final dateStr =
        '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final random = Random.secure();
    final seq =
        random.nextInt(90000) + 10000; // 5-digit number
    return '${AppConstants.reportIdPrefix}-$dateStr-$seq';
  }

  // ─── Create Report ───

  /// Submit a new incident report.
  /// Runs auto-priority engine, determines bypass routing.
  Future<ReportModel> submitReport({
    required String reporterUid,
    required String reporterEmail,
    required String reporterAadhaarHash,
    required String anonymousId,
    required bool isAnonymous,
    required String description,
    required String category,
    GeoPoint? location,
    String? locationAddress,
    String? city,
    String? district,
    String? pincode,
    List<String> mediaUrls = const [],
  }) async {
    // 1. Generate report ID
    final reportId = _generateReportId();

    // 2. Run auto-priority engine
    final priority =
        PriorityKeywords.calculatePriority(description, category);
    final shouldBypass =
        PriorityKeywords.shouldBypassAdmin(priority, category);
    final keywords = PriorityKeywords.extractKeywords(description);

    // 3. Determine initial status and assignment
    String initialStatus = AppConstants.statusSubmitted;
    String? assignedAuthorityUid;
    String? assignedBy;

    if (shouldBypass) {
      // Auto-assign to an available authority
      final authority = await _findAvailableAuthority(district);
      if (authority != null) {
        assignedAuthorityUid = authority['uid'] as String;
        assignedBy = 'SYSTEM';
        initialStatus = AppConstants.statusAssigned;
      }
    }

    // 4. Create the report document (NO reporter PII)
    final now = DateTime.now();
    final report = ReportModel(
      reportId: reportId,
      anonymousId: anonymousId,
      description: description,
      category: category,
      priority: priority,
      priorityBypassed: shouldBypass,
      status: initialStatus,
      location: location,
      locationAddress: locationAddress,
      city: city,
      district: district,
      pincode: pincode,
      assignedAuthorityUid: assignedAuthorityUid,
      assignedBy: assignedBy,
      createdAt: now,
      updatedAt: now,
      mediaUrls: mediaUrls,
      keywords: keywords,
      isAnonymous: isAnonymous,
      mediaCount: mediaUrls.length,
    );

    final batch = _firestore.batch();

    // Write report document
    final reportRef = _firestore
        .collection(AppConstants.reportsCollection)
        .doc(reportId);
    batch.set(reportRef, report.toFirestore());

    // Write reporter identity in encrypted sub-collection
    final identityRef = reportRef
        .collection(AppConstants.reportIdentitySubcollection)
        .doc(reporterUid);
    batch.set(identityRef, {
      'reportId': reportId,
      'reporterEmail': reporterEmail,
      'reporterAadhaarHash': reporterAadhaarHash,
      'isAnonymous': isAnonymous,
    });

    // Write initial status log
    final statusLogRef = reportRef
        .collection(AppConstants.reportStatusLogSubcollection)
        .doc();
    batch.set(statusLogRef, StatusLogModel(
      logId: statusLogRef.id,
      reportId: reportId,
      previousStatus: '',
      newStatus: initialStatus,
      changedBy: shouldBypass ? 'SYSTEM' : reporterUid,
      changedByRole: shouldBypass ? 'system' : 'user',
      note: shouldBypass
          ? 'Auto-assigned due to $priority priority'
          : 'Report submitted',
      changedAt: now,
    ).toFirestore());

    // Update authority's assigned case count if auto-assigned
    if (assignedAuthorityUid != null) {
      final authorityRef = _firestore
          .collection(AppConstants.authoritiesCollection)
          .doc(assignedAuthorityUid);
      batch.update(authorityRef, {
        'assignedCaseCount': FieldValue.increment(1),
      });
    }

    // Update aggregates
    final aggregateRef = _firestore
        .collection(AppConstants.aggregatesCollection)
        .doc('global');
    batch.set(
      aggregateRef,
      {
        'totalReports': FieldValue.increment(1),
        'pendingReports': FieldValue.increment(1),
        'categoryBreakdown': {category: FieldValue.increment(1)},
        'priorityBreakdown': {priority: FieldValue.increment(1)},
        'statusBreakdown': {initialStatus: FieldValue.increment(1)},
        if (district != null)
          'districtBreakdown': {district: FieldValue.increment(1)},
        'lastUpdated': Timestamp.now(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    return report;
  }

  /// Find an available authority, optionally matching jurisdiction
  Future<Map<String, dynamic>?> _findAvailableAuthority(
      String? district) async {
    Query query = _firestore
        .collection(AppConstants.authoritiesCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('assignedCaseCount')
        .limit(1);

    if (district != null) {
      // Try to find one in the same jurisdiction first
      final jurisdictionQuery = _firestore
          .collection(AppConstants.authoritiesCollection)
          .where('isActive', isEqualTo: true)
          .where('jurisdiction', isEqualTo: district)
          .orderBy('assignedCaseCount')
          .limit(1);

      final jurisdictionResult = await jurisdictionQuery.get();
      if (jurisdictionResult.docs.isNotEmpty) {
        final doc = jurisdictionResult.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        return {'uid': doc.id, ...data};
      }
    }

    // Fall back to any available authority
    final result = await query.get();
    if (result.docs.isNotEmpty) {
      final doc = result.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      return {'uid': doc.id, ...data};
    }

    return null;
  }

  // ─── Read Reports ───

  /// Stream all reports (for admin) with real-time updates
  Stream<List<ReportModel>> allReportsStream({
    String? statusFilter,
    String? categoryFilter,
    String? priorityFilter,
    String? districtFilter,
  }) {
    Query query = _firestore
        .collection(AppConstants.reportsCollection)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }
    if (categoryFilter != null) {
      query = query.where('category', isEqualTo: categoryFilter);
    }
    if (priorityFilter != null) {
      query = query.where('priority', isEqualTo: priorityFilter);
    }
    if (districtFilter != null) {
      query = query.where('district', isEqualTo: districtFilter);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ReportModel.fromFirestore(doc)).toList());
  }

  /// Stream reports assigned to a specific authority
  Stream<List<ReportModel>> authorityReportsStream(String authorityUid) {
    return _firestore
        .collection(AppConstants.reportsCollection)
        .where('assignedAuthorityUid', isEqualTo: authorityUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ReportModel.fromFirestore(doc)).toList());
  }

  /// Stream reports submitted by a specific user (via identity sub-collection)
  Stream<List<ReportModel>> userReportsStream(String userUid) {
    // We need to query reports where the identity sub-doc matches this user
    // Since Firestore doesn't support collection group queries on sub-collections
    // easily, we'll store a list of report IDs on the user document
    return _firestore
        .collection(AppConstants.reportsCollection)
        .where('anonymousId', isEqualTo: '') // This won't work directly
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ReportModel.fromFirestore(doc)).toList());
  }

  /// Get reports by user - using a separate user_reports collection
  Future<List<ReportModel>> getUserReports(String userUid) async {
    // Query from user's report references
    final userReportsSnap = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userUid)
        .collection('myReports')
        .orderBy('createdAt', descending: true)
        .get();

    final reportIds =
        userReportsSnap.docs.map((doc) => doc.id).toList();

    if (reportIds.isEmpty) return [];

    // Fetch actual reports (batch in groups of 10 for Firestore 'in' limit)
    final reports = <ReportModel>[];
    for (var i = 0; i < reportIds.length; i += 10) {
      final batch = reportIds.sublist(
          i, i + 10 > reportIds.length ? reportIds.length : i + 10);
      final snapshot = await _firestore
          .collection(AppConstants.reportsCollection)
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      reports.addAll(
          snapshot.docs.map((doc) => ReportModel.fromFirestore(doc)));
    }

    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports;
  }

  /// Stream a single report for real-time status tracking
  Stream<ReportModel?> reportStream(String reportId) {
    return _firestore
        .collection(AppConstants.reportsCollection)
        .doc(reportId)
        .snapshots()
        .map((doc) => doc.exists ? ReportModel.fromFirestore(doc) : null);
  }

  /// Get report by tracking ID
  Future<ReportModel?> getReportByTrackingId(String trackingId) async {
    final doc = await _firestore
        .collection(AppConstants.reportsCollection)
        .doc(trackingId)
        .get();

    return doc.exists ? ReportModel.fromFirestore(doc) : null;
  }

  /// Stream status log for a report
  Stream<List<StatusLogModel>> statusLogStream(String reportId) {
    return _firestore
        .collection(AppConstants.reportsCollection)
        .doc(reportId)
        .collection(AppConstants.reportStatusLogSubcollection)
        .orderBy('changedAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StatusLogModel.fromFirestore(doc))
            .toList());
  }

  // ─── Update Report Status ───

  /// Update report status (admin or authority)
  Future<void> updateReportStatus({
    required String reportId,
    required String newStatus,
    required String changedBy,
    required String changedByRole,
    String? note,
  }) async {
    final reportRef = _firestore
        .collection(AppConstants.reportsCollection)
        .doc(reportId);

    final reportDoc = await reportRef.get();
    if (!reportDoc.exists) throw Exception('Report not found.');

    final currentStatus = reportDoc.data()?['status'] ?? '';

    final batch = _firestore.batch();

    // Update report status
    final updates = <String, dynamic>{
      'status': newStatus,
      'updatedAt': Timestamp.now(),
    };
    if (newStatus == AppConstants.statusResolved ||
        newStatus == AppConstants.statusClosed) {
      updates['resolvedAt'] = Timestamp.now();
    }
    batch.update(reportRef, updates);

    // Add status log entry
    final logRef = reportRef
        .collection(AppConstants.reportStatusLogSubcollection)
        .doc();
    batch.set(
      logRef,
      StatusLogModel(
        logId: logRef.id,
        reportId: reportId,
        previousStatus: currentStatus,
        newStatus: newStatus,
        changedBy: changedBy,
        changedByRole: changedByRole,
        note: note,
        changedAt: DateTime.now(),
      ).toFirestore(),
    );

    await batch.commit();
  }

  /// Assign a report to an authority (admin action)
  Future<void> assignToAuthority({
    required String reportId,
    required String authorityUid,
    required String adminUid,
  }) async {
    final batch = _firestore.batch();

    final reportRef = _firestore
        .collection(AppConstants.reportsCollection)
        .doc(reportId);

    batch.update(reportRef, {
      'assignedAuthorityUid': authorityUid,
      'assignedBy': adminUid,
      'status': AppConstants.statusAssigned,
      'updatedAt': Timestamp.now(),
    });

    // Update authority case count
    final authorityRef = _firestore
        .collection(AppConstants.authoritiesCollection)
        .doc(authorityUid);
    batch.update(authorityRef, {
      'assignedCaseCount': FieldValue.increment(1),
    });

    // Add status log
    final logRef = reportRef
        .collection(AppConstants.reportStatusLogSubcollection)
        .doc();
    batch.set(
      logRef,
      StatusLogModel(
        logId: logRef.id,
        reportId: reportId,
        previousStatus: '',
        newStatus: AppConstants.statusAssigned,
        changedBy: adminUid,
        changedByRole: 'admin',
        note: 'Assigned to authority',
        changedAt: DateTime.now(),
      ).toFirestore(),
    );

    await batch.commit();
  }

  // ─── Mark Report as Fake ───

  /// Mark a report as fake (admin or authority).
  /// Increments the reporter's fake count. Auto-suspends at 3.
  Future<void> markAsFake({
    required String reportId,
    required String markedBy,
    required String markedByRole,
    String? note,
  }) async {
    final reportRef = _firestore
        .collection(AppConstants.reportsCollection)
        .doc(reportId);

    // Get the reporter's UID from the identity sub-collection
    final identitySnap = await reportRef
        .collection(AppConstants.reportIdentitySubcollection)
        .limit(1)
        .get();

    if (identitySnap.docs.isEmpty) {
      throw Exception('Reporter identity not found.');
    }

    final reporterUid = identitySnap.docs.first.id;

    final batch = _firestore.batch();

    // Update report status to fake
    batch.update(reportRef, {
      'status': AppConstants.statusFake,
      'updatedAt': Timestamp.now(),
    });

    // Increment reporter's fake count
    final userRef = _firestore
        .collection(AppConstants.usersCollection)
        .doc(reporterUid);

    batch.update(userRef, {
      'fakeReportCount': FieldValue.increment(1),
      'updatedAt': Timestamp.now(),
    });

    // Add status log
    final logRef = reportRef
        .collection(AppConstants.reportStatusLogSubcollection)
        .doc();
    batch.set(
      logRef,
      StatusLogModel(
        logId: logRef.id,
        reportId: reportId,
        previousStatus: '',
        newStatus: AppConstants.statusFake,
        changedBy: markedBy,
        changedByRole: markedByRole,
        note: note ?? 'Marked as fake report',
        changedAt: DateTime.now(),
      ).toFirestore(),
    );

    await batch.commit();

    // Check if user should be auto-suspended (3 strikes)
    final userDoc = await userRef.get();
    final fakeCount = (userDoc.data()?['fakeReportCount'] ?? 0) as int;

    if (fakeCount >= AppConstants.fakeReportThreshold) {
      await userRef.update({
        'status': AppConstants.userSuspended,
        'updatedAt': Timestamp.now(),
      });
    }
  }

  // ─── Aggregates ───

  /// Stream global aggregates for home screen floating stats
  Stream<Map<String, dynamic>?> globalAggregatesStream() {
    return _firestore
        .collection(AppConstants.aggregatesCollection)
        .doc('global')
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }
}
