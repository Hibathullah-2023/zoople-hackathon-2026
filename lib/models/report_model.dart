import 'package:cloud_firestore/cloud_firestore.dart';

/// Report model — represents a drug incident report.
/// Stored in `/reports/{reportId}`.
/// Reporter identity is stored separately in `/reports/{reportId}/identity/{uid}`.
class ReportModel {
  final String reportId; // Format: NZ-YYMMDD-XXXXX
  final String anonymousId; // Public-facing masked reporter ID
  final String description;
  final String category;
  final String priority; // 'critical' | 'high' | 'medium' | 'low'
  final bool priorityBypassed; // True if auto-routed to authority
  final String status;
  final GeoPoint? location;
  final String? locationAddress;
  final String? city;
  final String? district;
  final String? pincode;
  final String? assignedAuthorityUid;
  final String? assignedBy; // admin UID or 'SYSTEM'
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final List<String> mediaUrls; // Firebase Storage paths, max 5
  final List<String> keywords; // Auto-extracted from description
  final bool isAnonymous; // Reporter's global preference at time of submission
  final int mediaCount;

  const ReportModel({
    required this.reportId,
    required this.anonymousId,
    required this.description,
    required this.category,
    required this.priority,
    this.priorityBypassed = false,
    this.status = 'submitted',
    this.location,
    this.locationAddress,
    this.city,
    this.district,
    this.pincode,
    this.assignedAuthorityUid,
    this.assignedBy,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.mediaUrls = const [],
    this.keywords = const [],
    this.isAnonymous = true,
    this.mediaCount = 0,
  });

  /// Whether this report is still active (not resolved/closed/fake)
  bool get isActive =>
      status != 'resolved' && status != 'closed' && status != 'fake';

  /// Whether this report has been assigned to an authority
  bool get isAssigned => assignedAuthorityUid != null;

  /// Create from Firestore document
  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportModel(
      reportId: doc.id,
      anonymousId: data['anonymousId'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'other',
      priority: data['priority'] ?? 'low',
      priorityBypassed: data['priorityBypassed'] ?? false,
      status: data['status'] ?? 'submitted',
      location: data['location'] as GeoPoint?,
      locationAddress: data['locationAddress'],
      city: data['city'],
      district: data['district'],
      pincode: data['pincode'],
      assignedAuthorityUid: data['assignedAuthorityUid'],
      assignedBy: data['assignedBy'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      keywords: List<String>.from(data['keywords'] ?? []),
      isAnonymous: data['isAnonymous'] ?? true,
      mediaCount: data['mediaCount'] ?? 0,
    );
  }

  /// Convert to Firestore map — NOTE: does NOT include reporter UID
  Map<String, dynamic> toFirestore() {
    return {
      'anonymousId': anonymousId,
      'description': description,
      'category': category,
      'priority': priority,
      'priorityBypassed': priorityBypassed,
      'status': status,
      'location': location,
      'locationAddress': locationAddress,
      'city': city,
      'district': district,
      'pincode': pincode,
      'assignedAuthorityUid': assignedAuthorityUid,
      'assignedBy': assignedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'mediaUrls': mediaUrls,
      'keywords': keywords,
      'isAnonymous': isAnonymous,
      'mediaCount': mediaCount,
    };
  }

  /// Create a copy with updated fields
  ReportModel copyWith({
    String? reportId,
    String? anonymousId,
    String? description,
    String? category,
    String? priority,
    bool? priorityBypassed,
    String? status,
    GeoPoint? location,
    String? locationAddress,
    String? city,
    String? district,
    String? pincode,
    String? assignedAuthorityUid,
    String? assignedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    List<String>? mediaUrls,
    List<String>? keywords,
    bool? isAnonymous,
    int? mediaCount,
  }) {
    return ReportModel(
      reportId: reportId ?? this.reportId,
      anonymousId: anonymousId ?? this.anonymousId,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      priorityBypassed: priorityBypassed ?? this.priorityBypassed,
      status: status ?? this.status,
      location: location ?? this.location,
      locationAddress: locationAddress ?? this.locationAddress,
      city: city ?? this.city,
      district: district ?? this.district,
      pincode: pincode ?? this.pincode,
      assignedAuthorityUid: assignedAuthorityUid ?? this.assignedAuthorityUid,
      assignedBy: assignedBy ?? this.assignedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      keywords: keywords ?? this.keywords,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      mediaCount: mediaCount ?? this.mediaCount,
    );
  }
}

/// Report identity — stored in encrypted sub-collection.
/// Only the reporter themselves can read this document.
/// Stored in `/reports/{reportId}/identity/{uid}`.
class ReportIdentity {
  final String reportId;
  final String reporterUid;
  final String reporterEmail;
  final String reporterAadhaarHash;
  final bool isAnonymous;

  const ReportIdentity({
    required this.reportId,
    required this.reporterUid,
    required this.reporterEmail,
    required this.reporterAadhaarHash,
    required this.isAnonymous,
  });

  factory ReportIdentity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportIdentity(
      reportId: data['reportId'] ?? '',
      reporterUid: doc.id,
      reporterEmail: data['reporterEmail'] ?? '',
      reporterAadhaarHash: data['reporterAadhaarHash'] ?? '',
      isAnonymous: data['isAnonymous'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reportId': reportId,
      'reporterEmail': reporterEmail,
      'reporterAadhaarHash': reporterAadhaarHash,
      'isAnonymous': isAnonymous,
    };
  }
}
