import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../constants/app_constants.dart';
import '../models/user_model.dart';
import 'aadhaar_service.dart';

/// Authentication service — handles registration, login, role routing.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AadhaarService _aadhaarService = AadhaarService();

  /// Current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Generate anonymous ID (e.g., NX-8821)
  String _generateAnonymousId() {
    final random = Random.secure();
    final number = random.nextInt(9000) + 1000; // 4-digit number
    return '${AppConstants.anonymousIdPrefix}-$number';
  }

  /// Register a new end user.
  /// Returns the created UserModel or throws an exception.
  Future<UserModel> registerUser({
    required String email,
    required String password,
    required String aadhaarNumber,
    String? displayName,
  }) async {
    // 1. Validate Aadhaar format
    if (!_aadhaarService.isValidAadhaar(aadhaarNumber)) {
      throw Exception('Invalid Aadhaar number. Must be 12 digits.');
    }

    // 2. Check for duplicate Aadhaar
    final isDuplicate = await _aadhaarService.isDuplicate(aadhaarNumber);
    if (isDuplicate) {
      throw Exception(
        'An account with this identity already exists. Please login instead.',
      );
    }

    // 3. Create Firebase Auth user
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw Exception('Failed to create account. Please try again.');
    }

    // 4. Send email verification
    await user.sendEmailVerification();

    // 5. Hash the Aadhaar number
    final salt = _aadhaarService.generateSalt();
    final aadhaarHash = await _aadhaarService.hashAadhaar(aadhaarNumber, salt);

    // 6. Create user document in Firestore and register duplicate hash
    final now = DateTime.now();
    final userModel = UserModel(
      uid: user.uid,
      email: email.trim(),
      role: AppConstants.roleUser,
      displayName: displayName,
      aadhaarHash: aadhaarHash,
      fakeReportCount: 0,
      status: AppConstants.userActive,
      termsAccepted: true,
      isAnonymous: true,
      anonymousId: _generateAnonymousId(),
      createdAt: now,
      updatedAt: now,
    );

    final dupHash = await _aadhaarService.getAadhaarDuplicateHash(
      aadhaarNumber,
    );

    final batch = _firestore.batch();

    final userRef = _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid);
    batch.set(userRef, {
      ...userModel.toFirestore(),
      'aadhaarSalt': salt, // Store salt separately for duplicate checks
    });

    final dupRef = _firestore.collection('aadhaar_hashes').doc(dupHash);
    batch.set(dupRef, {'uid': user.uid, 'createdAt': Timestamp.now()});

    await batch.commit();

    return userModel;
  }

  /// Login with email and password.
  /// Returns the UserModel or throws an exception.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw Exception('Login failed. Please try again.');
    }

    // Fetch user document
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      throw Exception('User profile not found. Please contact support.');
    }

    final userModel = UserModel.fromFirestore(doc);

    // Check if user is suspended/blocked
    if (userModel.isSuspended) {
      await _auth.signOut();
      throw Exception(
        'Your account has been suspended due to policy violations. Contact support.',
      );
    }

    if (userModel.status == AppConstants.userBlocked) {
      await _auth.signOut();
      throw Exception(
        'Your account has been blocked. Contact support for assistance.',
      );
    }

    return userModel;
  }

  /// Get current user's profile from Firestore.
  Future<UserModel?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Stream the current user's profile for real-time updates.
  Stream<UserModel?> userProfileStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  /// Update password
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Not authenticated.');
    }

    if (newPassword.length < 8) {
      throw Exception('New password must be at least 8 characters.');
    }
    if (newPassword.contains(' ')) {
      throw Exception('New password must not contain spaces.');
    }

    // Re-authenticate
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    try {
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Incorrect current password.');
      }
      throw Exception(e.message ?? 'Re-authentication failed.');
    }

    // Update password
    await user.updatePassword(newPassword);
  }

  /// Toggle anonymity preference in profile settings and propagate to all submitted reports
  Future<void> toggleAnonymity(bool isAnonymous) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();

    // 1. Update user document
    final userRef = _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid);
    batch.update(userRef, {
      'isAnonymous': isAnonymous,
      'updatedAt': Timestamp.now(),
    });

    // 2. Fetch all reports from myReports sub-collection
    final myReportsSnap = await userRef.collection('myReports').get();

    for (final doc in myReportsSnap.docs) {
      final reportId = doc.id;
      final reportRef = _firestore
          .collection(AppConstants.reportsCollection)
          .doc(reportId);
      batch.update(reportRef, {
        'isAnonymous': isAnonymous,
        'updatedAt': Timestamp.now(),
      });

      // Also update the isAnonymous inside the report's identity subcollection document
      final identityRef = reportRef
          .collection(AppConstants.reportIdentitySubcollection)
          .doc(user.uid);
      batch.update(identityRef, {'isAnonymous': isAnonymous});
    }

    await batch.commit();
  }

  /// Update user profile fields
  Future<void> updateProfile({String? displayName, String? phone}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final updates = <String, dynamic>{'updatedAt': Timestamp.now()};
    if (displayName != null) updates['displayName'] = displayName;
    if (phone != null) updates['phone'] = phone;

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .update(updates);
  }

  /// Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Check if email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Resend verification email
  Future<void> resendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ─── Admin-only: Create Authority Account ───

  /// Admin creates an authority account.
  Future<void> createAuthorityAccount({
    required String email,
    required String name,
    required String password,
    String? badgeId,
    String? jurisdiction,
    String? specialization,
  }) async {
    if (password.length < 8) {
      throw Exception('Password must be at least 8 characters.');
    }
    if (password.contains(' ')) {
      throw Exception('Password must not contain spaces.');
    }

    final emailQuery = await _firestore
        .collection(AppConstants.authoritiesCollection)
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();
    if (emailQuery.docs.isNotEmpty) {
      throw Exception('An authority with this email already exists.');
    }

    if (badgeId != null && badgeId.trim().isNotEmpty) {
      final badgeQuery = await _firestore
          .collection(AppConstants.authoritiesCollection)
          .where('badgeId', isEqualTo: badgeId.trim())
          .limit(1)
          .get();
      if (badgeQuery.docs.isNotEmpty) {
        throw Exception('An authority with this Badge ID already exists.');
      }
    }

    // Initialize temporary secondary app to create user without signing out current admin
    final tempApp = await Firebase.initializeApp(
      name: 'tempApp_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      final now = DateTime.now();

      // Store in users collection
      await _firestore.collection(AppConstants.usersCollection).doc(uid).set({
        'uid': uid,
        'email': email.trim(),
        'role': 'authority',
        'displayName': name.trim(),
        'status': AppConstants.userActive,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Store in authorities collection
      await _firestore
          .collection(AppConstants.authoritiesCollection)
          .doc(uid)
          .set({
            'email': email.trim(),
            'name': name.trim(),
            'badgeId': badgeId,
            'jurisdiction': jurisdiction,
            'specialization': specialization,
            'isActive': true,
            'assignedCaseCount': 0,
            'createdAt': Timestamp.fromDate(now),
          });
    } finally {
      await tempApp.delete();
    }
  }

  // ─── Admin-only: Update Authority ───

  /// Update authority profile fields (name, badge, jurisdiction, specialization, active status).
  Future<void> updateAuthority({
    required String authorityDocId,
    String? name,
    String? badgeId,
    String? jurisdiction,
    String? specialization,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (badgeId != null) updates['badgeId'] = badgeId;
    if (jurisdiction != null) updates['jurisdiction'] = jurisdiction;
    if (specialization != null) updates['specialization'] = specialization;
    if (isActive != null) updates['isActive'] = isActive;

    if (updates.isNotEmpty) {
      await _firestore
          .collection(AppConstants.authoritiesCollection)
          .doc(authorityDocId)
          .update(updates);
    }
  }

  // ─── Admin-only: Delete Authority ───

  /// Delete an authority account from Firestore.
  /// NOTE: This removes the authority document. The Firebase Auth user
  /// would need to be deleted via Admin SDK / Cloud Function in production.
  Future<void> deleteAuthority(String authorityDocId) async {
    await _firestore
        .collection(AppConstants.authoritiesCollection)
        .doc(authorityDocId)
        .delete();
  }

  Future<void> seedDefaultUsers() async {
    final List<Map<String, dynamic>> defaultUsers = [
      {
        'email': 'authority_ekm@nizhal.kerala.gov.in',
        'password': 'AuthEkm2026!',
        'name': 'Inspector Suresh Kumar',
        'role': 'authority',
        'badgeId': 'KP-EKM-001',
        'jurisdiction': 'Ernakulam',
        'specialization': 'narcotics',
      },
      {
        'email': 'authority_tsr@nizhal.kerala.gov.in',
        'password': 'AuthTsr2026!',
        'name': 'DySP Madhavan Nair',
        'role': 'authority',
        'badgeId': 'KP-TSR-002',
        'jurisdiction': 'Thrissur',
        'specialization': 'investigation',
      },
      {
        'email': 'authority_koz@nizhal.kerala.gov.in',
        'password': 'AuthKoz2026!',
        'name': 'SI Fathima Rahma',
        'role': 'authority',
        'badgeId': 'KP-KOZ-003',
        'jurisdiction': 'Kozhikode',
        'specialization': 'patrol',
      },
      {
        'email': 'police@gmail.com',
        'password': 'Police2026!',
        'name': 'Police Authority Admin',
        'role': 'authority',
        'badgeId': 'KP-POL-100',
        'jurisdiction': 'Ernakulam',
        'specialization': 'investigation',
      },
      {
        'email': 'excise@gmail.com',
        'password': 'Excise2026!',
        'name': 'Excise Authority Admin',
        'role': 'authority',
        'badgeId': 'KP-EXC-200',
        'jurisdiction': 'Kozhikode',
        'specialization': 'narcotics',
      },
      {
        'email': 'reporter_anonymous@nizhal.kerala.gov.in',
        'password': 'UserNizhal2026!',
        'name': 'Citizen Advocate',
        'role': 'user',
        'badgeId': '',
        'jurisdiction': '',
        'specialization': '',
        'anonymousId': 'NX-8821',
        'aadhaarHash': '73cfb8417852a39281e28bbd916892543ffb9087cf283a21',
      },
    ];

    for (final u in defaultUsers) {
      try {
        final email = u['email'] as String;
        final password = u['password'] as String;
        final name = u['name'] as String;
        final role = u['role'] as String;
        final badgeId = u['badgeId'] as String;
        final jurisdiction = u['jurisdiction'] as String;
        final specialization = u['specialization'] as String;

        // Check if user already exists in Firestore users collection
        final userSnap = await _firestore
            .collection(AppConstants.usersCollection)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (userSnap.docs.isNotEmpty) {
          debugPrint('User $email already exists, skipping.');
          continue;
        }

        UserCredential? credential;
        try {
          final tempApp = await Firebase.initializeApp(
            name:
                'tempSeed_${u['email'].hashCode}_${DateTime.now().millisecondsSinceEpoch}',
            options: Firebase.app().options,
          );
          final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

          credential = await tempAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          await tempApp.delete();
        } on FirebaseAuthException catch (ae) {
          if (ae.code == 'email-already-in-use') {
            final tempApp = await Firebase.initializeApp(
              name:
                  'tempSeed_${u['email'].hashCode}_${DateTime.now().millisecondsSinceEpoch}',
              options: Firebase.app().options,
            );
            final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
            try {
              credential = await tempAuth.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
            } catch (le) {
              debugPrint('Sign in to existing seeded user failed: $le');
            }
            await tempApp.delete();
          } else {
            debugPrint('Failed to seed Auth user: ${ae.message}');
          }
        } catch (e) {
          debugPrint('Temp app error for seed: $e');
        }

        if (credential != null && credential.user != null) {
          final uid = credential.user!.uid;

          final Map<String, dynamic> userProfile = {
            'uid': uid,
            'email': email,
            'role': role,
            'displayName': name,
            'status': AppConstants.userActive,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (u.containsKey('anonymousId')) {
            userProfile['anonymousId'] = u['anonymousId'];
          }
          if (u.containsKey('aadhaarHash')) {
            userProfile['aadhaarHash'] = u['aadhaarHash'];
          }

          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(uid)
              .set(userProfile, SetOptions(merge: true));

          if (role == 'authority') {
            await _firestore
                .collection(AppConstants.authoritiesCollection)
                .doc(uid)
                .set({
                  'email': email,
                  'name': name,
                  'badgeId': badgeId,
                  'jurisdiction': jurisdiction,
                  'specialization': specialization,
                  'isActive': true,
                  'assignedCaseCount': 0,
                  'createdAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
          }

          debugPrint('Successfully seeded user: $email');
        }
      } catch (e) {
        debugPrint('Error seeding default user ${u['email']}: $e');
      }
    }
  }
}
