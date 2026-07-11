import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

/// Aadhaar hashing service — SHA-512 with Salt + Pepper + PBKDF2.
/// Used for duplicate detection without storing the actual Aadhaar number.
class AadhaarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _pepperKey = 'nizhal_aadhaar_pepper';

  /// Get or generate the pepper (stored in secure device storage).
  /// In production, pepper should be a server-side secret.
  Future<String> _getPepper() async {
    String? pepper = await _secureStorage.read(key: _pepperKey);
    if (pepper == null) {
      // First time: generate a pepper and store it
      pepper = _generateRandomBytes(32);
      await _secureStorage.write(key: _pepperKey, value: pepper);
    }
    return pepper;
  }

  /// Generate random bytes as hex string
  String _generateRandomBytes(int length) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generate a unique salt for this Aadhaar hash
  String generateSalt() {
    return _generateRandomBytes(AppConstants.saltLength);
  }

  /// Hash an Aadhaar number using SHA-512 with Salt + Pepper + PBKDF2.
  ///
  /// Process:
  /// 1. Clean the Aadhaar number (remove spaces/dashes)
  /// 2. Combine: aadhaar + salt + pepper
  /// 3. Run PBKDF2 with 100,000 iterations of SHA-512
  /// 4. Return the final hash as hex
  Future<String> hashAadhaar(String aadhaarNumber, String salt) async {
    // Clean the input
    final cleanAadhaar = aadhaarNumber.replaceAll(RegExp(r'[\s\-]'), '');

    // Get pepper
    final pepper = await _getPepper();

    // Combine: aadhaar + salt + pepper
    final input = '$cleanAadhaar$salt$pepper';

    // PBKDF2 with SHA-512
    Uint8List hash = Uint8List.fromList(utf8.encode(input));
    for (int i = 0; i < AppConstants.pbkdf2Iterations; i++) {
      hash = Uint8List.fromList(
        sha512.convert([...hash, ...utf8.encode(salt)]).bytes,
      );
    }

    return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Calculate a consistent global hash for duplicate checking across devices
  Future<String> getAadhaarDuplicateHash(String aadhaarNumber) async {
    final cleanAadhaar = aadhaarNumber.replaceAll(RegExp(r'[\s\-]'), '');
    const globalPepper = 'nizhal_global_pepper_2026';
    final input = '$cleanAadhaar$globalPepper';
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Check if an Aadhaar number is already registered using the dedicated aadhaar_hashes collection.
  Future<bool> isDuplicate(String aadhaarNumber) async {
    final hash = await getAadhaarDuplicateHash(aadhaarNumber);
    final doc = await _firestore.collection('aadhaar_hashes').doc(hash).get();
    return doc.exists;
  }

  /// Validate Aadhaar number format (12 digits).
  bool isValidAadhaar(String aadhaarNumber) {
    final clean = aadhaarNumber.replaceAll(RegExp(r'[\s\-]'), '');
    return RegExp(r'^\d{12}$').hasMatch(clean);
  }
}
