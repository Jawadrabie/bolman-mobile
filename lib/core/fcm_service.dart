import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories.dart';
import 'config.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
}

/// Handles FCM token registration, push notifications, and real-time alerts.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final AndroidNotificationChannel _channel = const AndroidNotificationChannel(
    'bolman_high_importance_channel',
    'Bolman Notifications',
    description: 'Notifications for Bolman passenger and driver updates',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  /// Broadcasts an event whenever a new notification arrives (FCM or Supabase realtime).
  /// Subscribe to this stream to refresh UI without polling.
  final _notificationStreamController = StreamController<void>.broadcast();
  Stream<void> get onNewNotification => _notificationStreamController.stream;

  bool _initialized = false;
  RealtimeChannel? _realtimeSubscription;
  String? _realtimeUserId;
  StreamSubscription<String>? _tokenRefreshSub;

  /// The push and the Supabase realtime insert describe the same event, and both
  /// land while the app is in the foreground. Remember what was just shown so the
  /// user does not get the same alert twice.
  final Map<String, DateTime> _recentAlerts = {};
  static const _dedupeWindow = Duration(seconds: 15);

  /// Set by the app so a notification tap can open the notifications screen.
  void Function()? onNotificationTap;

  bool _isDuplicate(String title, String body) {
    final now = DateTime.now();
    _recentAlerts.removeWhere((_, at) => now.difference(at) > _dedupeWindow);
    final key = '$title|$body';
    if (_recentAlerts.containsKey(key)) return true;
    _recentAlerts[key] = now;
    return false;
  }


  Future<void> ensureInitialized() async {
    if (_initialized) return;

    // 1. Initialize Firebase with safarbus-2b9b0 options
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      _initialized = true;
    } catch (e) {
      debugPrint('Firebase init error: $e');
    }

    // 2. Initialize Local Notifications Plugin
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (_) => onNotificationTap?.call(),
      );

      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        // Request POST_NOTIFICATIONS permission for Android 13+
        await androidPlugin?.requestNotificationsPermission();

        // Create the high-importance channel so heads-up banners appear
        await androidPlugin?.createNotificationChannel(_channel);
      }
    } catch (e) {
      debugPrint('Local notifications init error: $e');
    }

    // 3. Listen for Foreground FCM messages and notification taps
    if (_initialized) {
      try {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _showForegroundNotification(message);
        });

        // Tapped a tray notification while the app was backgrounded.
        FirebaseMessaging.onMessageOpenedApp.listen((_) => onNotificationTap?.call());

        // Tapped a tray notification that cold-started the app.
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null) onNotificationTap?.call();
      } catch (e) {
        debugPrint('FCM onMessage listen error: $e');
      }
    }

    // 4. Listen for Real-Time Supabase notifications
    _listenToSupabaseNotifications();
  }


  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'إشعار جديد';
    final body = notification?.body ?? message.data['body'] ?? message.data['message'] ?? '';

    if (_isDuplicate(title, body)) {
      _notificationStreamController.add(null);
      return;
    }

    _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          ticker: title,
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
    // Notify UI listeners to refresh the notifications list
    _notificationStreamController.add(null);
  }


  void _listenToSupabaseNotifications() {
    final user = sb.auth.currentUser;
    if (user == null) return;

    // Already listening for this same user — re-subscribing would leave a dead
    // duplicate channel behind and the events would arrive twice.
    if (_realtimeUserId == user.id && _realtimeSubscription != null) return;

    final previous = _realtimeSubscription;
    _realtimeSubscription = null;
    _realtimeUserId = user.id;
    if (previous != null) unawaited(sb.removeChannel(previous));

    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'user_id',
      value: user.id,
    );

    _realtimeSubscription = sb
        .channel('public:notifications:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: filter,
          callback: (payload) {
            final newRecord = payload.newRecord;
            final title = newRecord['title'] as String? ?? 'إشعار جديد';
            final message = newRecord['message'] as String? ?? '';
            _showLocalAlert(title, message);
          },
        )
        // A row marked read (or removed) on another device must not leave a stale
        // unread badge here, so nudge the UI on those too — without an alert.
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: filter,
          callback: (_) => _notificationStreamController.add(null),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'notifications',
          callback: (_) => _notificationStreamController.add(null),
        )
        .subscribe((status, error) {
          debugPrint('Notifications realtime: $status${error == null ? '' : ' — $error'}');
          // Reconciles anything inserted while the socket was down.
          if (status == RealtimeSubscribeStatus.subscribed) {
            _notificationStreamController.add(null);
          }
        });
  }

  void _showLocalAlert(String title, String body) {
    if (_isDuplicate(title, body)) {
      _notificationStreamController.add(null);
      return;
    }

    _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          ticker: title,
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
    // Notify UI listeners to refresh the notifications list
    _notificationStreamController.add(null);
  }



  Future<void> registerForCurrentUser() async {
    await ensureInitialized();
    _listenToSupabaseNotifications();

    if (!_initialized) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('FCM permission: ${settings.authorizationStatus}');

      // Register the token regardless of the permission verdict. A token is still
      // valid for data messages, and keeping the row means push starts working the
      // moment the user enables notifications in system settings — without waiting
      // for them to sign out and back in.
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await NotificationsRepo().registerFcm(token, _platform(), null);
        debugPrint('FCM token registered: ${token.substring(0, 12)}…');
      } else {
        debugPrint('FCM getToken returned null — check google-services.json / Firebase setup');
      }

      _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await NotificationsRepo().registerFcm(newToken, _platform(), null);
        } catch (e) {
          debugPrint('FCM token refresh registration failed: $e');
        }
      });
    } catch (e) {
      debugPrint('FCM registration error: $e');
    }
  }

  String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }
}
