import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

    // 6. Create user document in Firestore
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

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set({
      ...userModel.toFirestore(),
      'aadhaarSalt': salt, // Store salt separately for duplicate checks
    });

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

    // Re-authenticate
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);

    // Update password
    await user.updatePassword(newPassword);
  }

  /// Toggle anonymity preference in profile settings
  Future<void> toggleAnonymity(bool isAnonymous) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .update({
      'isAnonymous': isAnonymous,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Update user profile fields
  Future<void> updateProfile({
    String? displayName,
    String? phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final updates = <String, dynamic>{
      'updatedAt': Timestamp.now(),
    };
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
  /// The authority receives an email to set their password.
  Future<void> createAuthorityAccount({
    required String email,
    required String name,
    String? badgeId,
    String? jurisdiction,
    String? specialization,
  }) async {
    // Note: In production, this would use Firebase Admin SDK via Cloud Functions
    // For MVP, admin creates a temporary password and the authority resets it

    final tempPassword = _generateTempPassword();

    // Create Firebase Auth user
    // This should ideally be done via Cloud Functions to avoid
    // signing out the current admin. For MVP, we'll use a workaround.
    
    // Store authority details in Firestore
    // The authority will be created when they first sign in
    await _firestore
        .collection(AppConstants.authoritiesCollection)
        .doc(email)
        .set({
      'email': email,
      'name': name,
      'badgeId': badgeId,
      'jurisdiction': jurisdiction,
      'specialization': specialization,
      'isActive': true,
      'assignedCaseCount': 0,
      'createdAt': Timestamp.now(),
      'tempPassword': tempPassword, // Will be removed after first login
      'isPendingSetup': true,
    });

    // Send password reset email so authority can set their own password
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (_) {
      // If user doesn't exist yet, we'll handle it differently
    }
  }

  String _generateTempPassword() {
    final random = Random.secure();
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%';
    return List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
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
}
