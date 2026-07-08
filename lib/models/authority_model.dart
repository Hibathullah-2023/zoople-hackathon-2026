import 'package:cloud_firestore/cloud_firestore.dart';

/// Authority model — extended profile for users with role 'authority'.
/// Stored in `/authorities/{uid}`.
class AuthorityModel {
  final String uid;
  final String name;
  final String email;
  final String? badgeId;
  final String? jurisdiction; // District or area
  final String? specialization; // 'narcotics' | 'patrol' | 'investigation'
  final bool isActive;
  final int assignedCaseCount;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  const AuthorityModel({
    required this.uid,
    required this.name,
    required this.email,
    this.badgeId,
    this.jurisdiction,
    this.specialization,
    this.isActive = true,
    this.assignedCaseCount = 0,
    required this.createdAt,
    this.lastActiveAt,
  });

  factory AuthorityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuthorityModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      badgeId: data['badgeId'],
      jurisdiction: data['jurisdiction'],
      specialization: data['specialization'],
      isActive: data['isActive'] ?? true,
      assignedCaseCount: data['assignedCaseCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'badgeId': badgeId,
      'jurisdiction': jurisdiction,
      'specialization': specialization,
      'isActive': isActive,
      'assignedCaseCount': assignedCaseCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt':
          lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
    };
  }

  AuthorityModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? badgeId,
    String? jurisdiction,
    String? specialization,
    bool? isActive,
    int? assignedCaseCount,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    return AuthorityModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      badgeId: badgeId ?? this.badgeId,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      specialization: specialization ?? this.specialization,
      isActive: isActive ?? this.isActive,
      assignedCaseCount: assignedCaseCount ?? this.assignedCaseCount,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}
