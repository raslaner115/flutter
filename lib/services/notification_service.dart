import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'dart:io';

// Must be a top-level function for background handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM automatically shows notifications in the background if they contain a 'notification' object.
  // This handler is for custom logic or data-only messages.
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static StreamSubscription? _notificationSubscription;
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;

    // 1. Android/iOS local settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );

    // 2. Setup FCM Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Handle Foreground FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showNotification(
          id: message.hashCode,
          title: message.notification!.title ?? '',
          body: message.notification!.body ?? '',
        );
      }
    });

    _isInitialized = true;
  }

  /// Saves the FCM token to the user's document in Firestore
  static Future<void> saveDeviceToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'platform': Platform.isAndroid ? 'android' : 'ios',
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("Error saving FCM token: $e");
    }
  }

  static void startListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    saveDeviceToken(); // Update token on login/start
    _notificationSubscription?.cancel();

    bool isInitialLoad = true;
    _notificationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (isInitialLoad) {
        isInitialLoad = false;
        return;
      }

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        
        // We still keep the Firestore listener for immediate UI updates/notifications 
        // while the app is open, but FCM will take over for background.
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final bool enabled = userDoc.data()?['notificationsEnabled'] ?? true;

        if (enabled) {
          _showNotification(
            id: snapshot.docs.first.id.hashCode,
            title: data['title'] ?? 'New Notification',
            body: data['body'] ?? 'You have a new update.',
          );
        }
      }
    });
  }

  static void stopListening() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }

  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'main_channel',
      'Main Notifications',
      channelDescription: 'Notifications for work requests and updates',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }
}
