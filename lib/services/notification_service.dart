import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

/// Service to handle Firebase Cloud Messaging (FCM) push notifications.
class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize FCM, request permissions, and set up message handlers.
  Future<void> initialize(String userUid, String role) async {
    // 1. Request notification permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('User granted notification permissions');
      }

      // 2. Save/Update FCM token
      await _saveTokenToDatabase(userUid);

      // 3. Subscribe to role-specific topics
      await _subscribeToRoleTopics(role);

      // 4. Handle token refresh
      _fcm.onTokenRefresh.listen((token) async {
        await _saveTokenToDatabase(userUid);
      });

      // 5. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Received foreground message: ${message.notification?.title}');
        }
        // Custom local notification display can be added here if needed
      });

      // 6. Handle notification click when app is in background but opened
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Notification clicked: ${message.data}');
        }
        // Route navigation based on data can be performed here
      });
    }
  }

  /// Save FCM token to Firestore `/users/{uid}/fcmTokens`
  Future<void> _saveTokenToDatabase(String userUid) async {
    String? token = await _fcm.getToken();
    if (token == null) return;

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userUid)
        .collection(AppConstants.fcmTokensSubcollection)
        .doc(token)
        .set({
      'token': token,
      'lastUpdated': FieldValue.serverTimestamp(),
      'platform': defaultTargetPlatform.toString(),
    });
  }

  /// Subscribe user to topics based on role.
  /// Admin -> 'admins' topic
  /// Authority -> 'authorities' topic
  /// Everyone -> 'all_users' topic
  Future<void> _subscribeToRoleTopics(String role) async {
    // Unsubscribe from other topics first to clean up
    try {
      await _fcm.unsubscribeFromTopic('admins');
      await _fcm.unsubscribeFromTopic('authorities');
    } catch (_) {}

    await _fcm.subscribeToTopic('all_users');

    if (role == AppConstants.roleAdmin) {
      await _fcm.subscribeToTopic('admins');
    } else if (role == AppConstants.roleAuthority) {
      await _fcm.subscribeToTopic('authorities');
    }
  }

  /// Unsubscribe and clean token on logout
  Future<void> cleanUp(String userUid) async {
    String? token = await _fcm.getToken();
    if (token != null) {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userUid)
          .collection(AppConstants.fcmTokensSubcollection)
          .doc(token)
          .delete();
    }
    await _fcm.unsubscribeFromTopic('admins');
    await _fcm.unsubscribeFromTopic('authorities');
    await _fcm.unsubscribeFromTopic('all_users');
  }
}
