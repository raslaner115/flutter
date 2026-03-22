import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

// Must be a top-level function for background handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM automatically shows notifications in the background if they contain a 'notification' object.
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static StreamSubscription? _notificationSubscription;
  static bool _isInitialized = false;
  static bool _isListening = false;
  static String? _activeUserId;

  // Stream controller to handle notification taps
  static final StreamController<String?> selectNotificationStream = StreamController<String?>.broadcast();

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
        // Handle notification tap by adding payload to stream
        selectNotificationStream.add(response.payload);
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
          payload: jsonEncode(message.data),
        );
      }
    });

    // 4. Handle notification when app is opened from a terminated state
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      selectNotificationStream.add(jsonEncode(initialMessage.data));
    }

    // 5. Handle notification when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      selectNotificationStream.add(jsonEncode(message.data));
    });

    _isInitialized = true;
  }

  /// Saves the FCM token to the user's document in Firestore
  static Future<void> saveDeviceToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      // Request permission for iOS/Android 13+
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await _messaging.getToken();
        if (token != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
            'platform': Platform.isAndroid ? 'android' : 'ios',
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint("Error saving FCM token: $e");
    }
  }

  /// Sends a push notification to a specific device token.
  static Future<void> sendPushNotification({
    required String targetToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Note: In production, you should trigger this via a Cloud Function for security.
      // This is currently a debug placeholder or client-side trigger (depending on your setup).
      debugPrint("FCM notification request for token: $targetToken");
      debugPrint("Title: $title, Body: $body");
      // If you are using FCM HTTP v1, you would perform an authenticated post here.
    } catch (e) {
      debugPrint("Error sending push notification: $e");
    }
  }

  static void startListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      stopListening();
      return;
    }

    if (_isListening && _activeUserId == user.uid) return;
    
    _isListening = true;
    _activeUserId = user.uid;

    saveDeviceToken(); 
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
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final bool enabled = userDoc.data()?['notificationsEnabled'] ?? true;

        if (enabled) {
          _showNotification(
            id: snapshot.docs.first.id.hashCode,
            title: data['title'] ?? 'New Notification',
            body: data['body'] ?? 'You have a new update.',
            payload: jsonEncode(data),
          );
        }
      }
    }, onError: (e) => debugPrint("Notification Stream Error: $e"));
  }

  static void stopListening() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _isListening = false;
    _activeUserId = null;
  }

  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'main_channel',
      'Main Notifications',
      channelDescription: 'Notifications for work requests and updates',
      importance: Importance.max,
      priority: Priority.high,
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
      payload: payload,
    );
  }
}
