import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fitkhao_user/core/constants/fcm_events.dart';
import 'package:fitkhao_user/core/router/app_router.dart';
import 'package:fitkhao_user/core/router/route_names.dart';
import 'package:fitkhao_user/features/main_navigation/main_navigation_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level function for handling background messages
/// Must be a top-level function or static method
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message received: ${message.messageId}');
  debugPrint('[FCM] Title: ${message.notification?.title}');
  debugPrint('[FCM] Body: ${message.notification?.body}');
  debugPrint('[FCM] Data: ${message.data}');
}

/// Service for handling Firebase Cloud Messaging (FCM) push notifications
class FirebaseNotificationService {
  static FirebaseNotificationService? _instance;
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  bool _isInitialized = false;
  bool _isAppReady = false;
  bool _notificationNavigationRequested = false;
  bool _isFlushScheduled = false;
  Map<String, dynamic>? _pendingNavigationData;

  // Private constructor
  FirebaseNotificationService._();

  /// Get singleton instance
  static FirebaseNotificationService getInstance() {
    _instance ??= FirebaseNotificationService._();
    return _instance!;
  }

  void markAppReady() {
    if (_isAppReady) return;
    _isAppReady = true;
    _flushPendingNavigation();
  }

  bool get hasNotificationNavigationInProgress =>
      _notificationNavigationRequested || _pendingNavigationData != null;

  void flushPendingNavigationIfPossible() {
    _flushPendingNavigation();
  }

  /// Initialize Firebase Messaging and local notifications
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[FCM] Already initialized');
      return;
    }

    try {
      debugPrint('[FCM] Initializing Firebase Messaging...');

      // Request notification permissions
      await _requestPermissions();

      // Initialize local notifications for foreground messages
      await _initializeLocalNotifications();

      // Set up FCM message handlers
      _setupMessageHandlers();

      // Get initial FCM token
      await _getFcmToken();

      // Listen for token refresh
      _setupTokenRefreshListener();

      _isInitialized = true;
      debugPrint('[FCM] Initialization complete');
    } catch (e) {
      debugPrint('[FCM] Initialization error: $e');
      rethrow;
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      debugPrint('[FCM] Requesting notification permissions...');

      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[FCM] User granted notification permissions');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('[FCM] User granted provisional notification permissions');
      } else {
        debugPrint('[FCM] User declined or has not accepted notification permissions');
      }
    } catch (e) {
      debugPrint('[FCM] Error requesting permissions: $e');
    }
  }

  /// Initialize local notifications for showing notifications in foreground
  Future<void> _initializeLocalNotifications() async {
    try {
      debugPrint('[FCM] Initializing local notifications...');

      // Android settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Initialize settings
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create Android notification channel
      if (Platform.isAndroid) {
        await _createAndroidNotificationChannel();
      }

      debugPrint('[FCM] Local notifications initialized');
    } catch (e) {
      debugPrint('[FCM] Error initializing local notifications: $e');
    }
  }

  /// Create Android notification channel
  Future<void> _createAndroidNotificationChannel() async {
    try {
      const channel = AndroidNotificationChannel(
        'fitkhao_notifications', // ID
        'Fitkhao Notifications', // Name
        description: 'Notifications for Fitkhao app',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint('[FCM] Android notification channel created');
    } catch (e) {
      debugPrint('[FCM] Error creating notification channel: $e');
    }
  }

  /// Set up message handlers for foreground, background, and terminated states
  void _setupMessageHandlers() {
    try {
      debugPrint('[FCM] Setting up message handlers...');

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle notification tap when app is terminated
      _handleInitialMessage();

      debugPrint('[FCM] Message handlers set up successfully');
    } catch (e) {
      debugPrint('[FCM] Error setting up message handlers: $e');
    }
  }

  /// Handle foreground messages by showing local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      debugPrint('[FCM] Foreground message received: ${message.messageId}');
      debugPrint('[FCM] Title: ${message.notification?.title}');
      debugPrint('[FCM] Body: ${message.notification?.body}');
      debugPrint('[FCM] Data: ${message.data}');

      // Show local notification
      if (message.notification != null) {
        await _showLocalNotification(message);
      }
    } catch (e) {
      debugPrint('[FCM] Error handling foreground message: $e');
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      const androidDetails = AndroidNotificationDetails(
        'fitkhao_notifications',
        'Fitkhao Notifications',
        channelDescription: 'Notifications for Fitkhao app',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
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
        notification.hashCode,
        notification.title,
        notification.body,
        details,
        payload: jsonEncode(message.data),
      );

      debugPrint('[FCM] Local notification shown');
    } catch (e) {
      debugPrint('[FCM] Error showing local notification: $e');
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    try {
      debugPrint('[FCM] Notification tapped: ${message.messageId}');
      debugPrint('[FCM] Data: ${message.data}');
      _notificationNavigationRequested = true;
      _navigateFromNotificationData(message.data);
    } catch (e) {
      debugPrint('[FCM] Error handling notification tap: $e');
    }
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    try {
      debugPrint('[FCM] Local notification tapped');
      debugPrint('[FCM] Payload: ${response.payload}');
      final payload = response.payload;
      if (payload == null || payload.isEmpty) return;

      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _navigateFromNotificationData(decoded);
      } else if (decoded is Map) {
        _navigateFromNotificationData(
          decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
      }
    } catch (e) {
      debugPrint('[FCM] Error handling local notification tap: $e');
    }
  }

  /// Handle initial message when app is opened from terminated state
  Future<void> _handleInitialMessage() async {
    try {
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] App opened from terminated state via notification');
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      debugPrint('[FCM] Error handling initial message: $e');
    }
  }

  /// Get FCM token
  Future<String?> _getFcmToken() async {
    try {
      debugPrint('[FCM] Getting FCM token...');

      // For iOS, you might need to get APNs token first
      if (Platform.isIOS) {
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        debugPrint('[FCM] APNs token: $apnsToken');

        if (apnsToken == null) {
          debugPrint('[FCM] APNs token not available yet, waiting...');
          // Wait a bit and try again
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('[FCM] Token obtained: $_fcmToken');
      return _fcmToken;
    } catch (e) {
      debugPrint('[FCM] Error getting FCM token: $e');
      return null;
    }
  }

  /// Set up token refresh listener
  void _setupTokenRefreshListener() {
    try {
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed: $newToken');
        _fcmToken = newToken;

        // TODO: Send updated token to your backend
        // You can use a callback or event bus here
      }).onError((error) {
        debugPrint('[FCM] Error on token refresh: $error');
      });
    } catch (e) {
      debugPrint('[FCM] Error setting up token refresh listener: $e');
    }
  }

  /// Get current FCM token
  Future<String> getToken() async {
    try {
      if (_fcmToken != null) {
        return _fcmToken!;
      }

      final token = await _getFcmToken();
      return token ?? '';
    } catch (e) {
      debugPrint('[FCM] Error getting token: $e');
      return '';
    }
  }

  /// Delete FCM token (useful for logout)
  Future<void> deleteToken() async {
    try {
      debugPrint('[FCM] Deleting FCM token...');
      await _firebaseMessaging.deleteToken();
      _fcmToken = null;
      debugPrint('[FCM] Token deleted');
    } catch (e) {
      debugPrint('[FCM] Error deleting token: $e');
    }
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      debugPrint('[FCM] Subscribing to topic: $topic');
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('[FCM] Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('[FCM] Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      debugPrint('[FCM] Unsubscribing from topic: $topic');
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('[FCM] Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('[FCM] Error unsubscribing from topic: $e');
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      final settings = await _firebaseMessaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      debugPrint('[FCM] Error checking notification status: $e');
      return false;
    }
  }

  void _navigateFromNotificationData(Map<String, dynamic> data) {
    final eventType = _extractEventType(data);
    if (eventType == null || eventType.isEmpty) {
      _notificationNavigationRequested = false;
      debugPrint('[FCM] Notification event type missing in payload: $data');
      return;
    }

    if (!_isAppReady) {
      _pendingNavigationData = Map<String, dynamic>.from(data);
      debugPrint('[FCM] App not ready, queued notification navigation');
      return;
    }

    if (AppRouter.rootNavigatorKey.currentContext == null) {
      _pendingNavigationData = Map<String, dynamic>.from(data);
      debugPrint('[FCM] Navigator not ready, queued notification navigation');
      _schedulePendingNavigationFlush();
      return;
    }

    debugPrint('[FCM] Navigating for event type: $eventType');

    if (FcmEvent.orderEvents.contains(eventType) ||
        FcmEvent.deliveryEvents.contains(eventType)) {
      AppRouter.router.go(
        RouteNames.home,
        extra: MainNavigationTabIndex.history,
      );
      _pendingNavigationData = null;
      _notificationNavigationRequested = false;
      return;
    }

    if (FcmEvent.subscriptionEvents.contains(eventType) ||
        FcmEvent.walletEvents.contains(eventType)) {
      AppRouter.router.go(RouteNames.subscriptionPlans);
      _pendingNavigationData = null;
      _notificationNavigationRequested = false;
      return;
    }

    _notificationNavigationRequested = false;
    debugPrint('[FCM] No navigation mapping found for event type: $eventType');
  }

  String? _extractEventType(Map<String, dynamic> data) {
    final directKeys = [
      data['type'],
      data['event'],
      data['eventType'],
      data['notificationType'],
      data['notification_type'],
    ];

    for (final candidate in directKeys) {
      final normalizedValue = _normalizeEventType(candidate);
      if (normalizedValue != null) {
        return normalizedValue;
      }
    }

    final nestedData = data['data'];
    if (nestedData is Map) {
      return _extractEventType(
        nestedData.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
    }

    if (nestedData is String && nestedData.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(nestedData);
        if (decoded is Map) {
          return _extractEventType(
            decoded.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          );
        }
      } catch (_) {
        // Ignore malformed nested JSON payloads and fall back gracefully.
      }
    }

    return null;
  }

  String? _normalizeEventType(Object? rawType) {
    if (rawType == null) return null;

    final normalized = rawType.toString().trim().toUpperCase();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  void _flushPendingNavigation() {
    final pendingData = _pendingNavigationData;
    if (pendingData == null || !_isAppReady) return;

    if (AppRouter.rootNavigatorKey.currentContext == null) {
      _schedulePendingNavigationFlush();
      return;
    }

    _pendingNavigationData = null;
    _navigateFromNotificationData(pendingData);
  }

  void _schedulePendingNavigationFlush() {
    if (_isFlushScheduled) return;

    _isFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isFlushScheduled = false;
      _flushPendingNavigation();
    });
  }
}
