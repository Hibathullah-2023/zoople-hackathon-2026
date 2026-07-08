import 'package:cloud_firestore/cloud_firestore.dart';

/// User model — represents all user types (end user, authority, admin).
/// Stored in `/users/{uid}`.
class UserModel {
  final String uid;
  final String email;
  final String role; // 'user' | 'authority' | 'admin'
  final String? displayName;
  final String aadhaarHash; // SHA-512 hashed
  final int fakeReportCount;
  final String status; // 'active' | 'suspended' | 'blocked'
  final bool termsAccepted;
  final bool isAnonymous; // Global anonymity preference (Profile Settings)
  final String anonymousId; // Public-facing masked ID e.g. NX-8821
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? profileImageUrl;
  final String? phone;

  const UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.displayName,
    required this.aadhaarHash,
    this.fakeReportCount = 0,
    this.status = 'active',
    this.termsAccepted = false,
    this.isAnonymous = true,
    required this.anonymousId,
    required this.createdAt,
    required this.updatedAt,
    this.profileImageUrl,
    this.phone,
  });

  /// Whether this user is currently active
  bool get isActive => status == 'active';

  /// Whether this user is suspended due to fake reports
  bool get isSuspended => status == 'suspended';

  /// Whether the user should be auto-suspended
  bool get shouldAutoSuspend => fakeReportCount >= 3;

  /// Create from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      displayName: data['displayName'],
      aadhaarHash: data['aadhaarHash'] ?? '',
      fakeReportCount: data['fakeReportCount'] ?? 0,
      status: data['status'] ?? 'active',
      termsAccepted: data['termsAccepted'] ?? false,
      isAnonymous: data['isAnonymous'] ?? true,
      anonymousId: data['anonymousId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profileImageUrl: data['profileImageUrl'],
      phone: data['phone'],
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'role': role,
      'displayName': displayName,
      'aadhaarHash': aadhaarHash,
      'fakeReportCount': fakeReportCount,
      'status': status,
      'termsAccepted': termsAccepted,
      'isAnonymous': isAnonymous,
      'anonymousId': anonymousId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'profileImageUrl': profileImageUrl,
      'phone': phone,
    };
  }

  /// Create a copy with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? role,
    String? displayName,
    String? aadhaarHash,
    int? fakeReportCount,
    String? status,
    bool? termsAccepted,
    bool? isAnonymous,
    String? anonymousId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? profileImageUrl,
    String? phone,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      aadhaarHash: aadhaarHash ?? this.aadhaarHash,
      fakeReportCount: fakeReportCount ?? this.fakeReportCount,
      status: status ?? this.status,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      anonymousId: anonymousId ?? this.anonymousId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      phone: phone ?? this.phone,
    );
  }
}
