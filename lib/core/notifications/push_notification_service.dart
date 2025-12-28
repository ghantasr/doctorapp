import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/supabase_config.dart';

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message: ${message.messageId}');
}

class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize push notifications
  Future<void> initialize() async {
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional notification permission');
    } else {
      print('User declined notification permission');
      return;
    }

    // Configure local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Get FCM token
    _fcmToken = await _messaging.getToken();
    print('FCM Token: $_fcmToken');

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _saveFCMTokenToDatabase(newToken);
    });

    // Save initial token
    if (_fcmToken != null) {
      await _saveFCMTokenToDatabase(_fcmToken!);
    }

    // Set up foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Save FCM token to Supabase for the current user
  Future<void> _saveFCMTokenToDatabase(String token) async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) return;

      // Check if user_fcm_tokens table exists, if not we'll create it
      await SupabaseConfig.client.from('user_fcm_tokens').upsert({
        'user_id': userId,
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      print('FCM token saved to database');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages (when app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message: ${message.notification?.title}');

    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'Notification',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Notifications',
      channelDescription: 'Default notification channel',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    
    // Navigate based on notification type
    final notificationType = message.data['type'];
    switch (notificationType) {
      case 'follow_up_reminder':
        // Navigate to follow-up patients screen
        print('Navigate to follow-up screen');
        break;
      case 'appointment_reminder':
        // Navigate to appointments screen
        print('Navigate to appointments screen');
        break;
      case 'new_assignment':
        // Navigate to patient detail
        print('Navigate to patient: ${message.data['patient_id']}');
        break;
    }
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Local notification tapped: ${response.payload}');
  }

  /// Subscribe to a topic (e.g., for doctor-specific notifications)
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }

  /// Delete FCM token on logout
  Future<void> deleteToken() async {
    await _messaging.deleteToken();
    _fcmToken = null;
    print('FCM token deleted');
  }
}

// Provider
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});
