import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenSubscription;

  // =========================================================
  // INITIALIZE
  // =========================================================

  Future<void> initialize() async {
    try {
      // طلب صلاحية الإشعارات
      final settings =
          await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      debugPrint(
        'NOTIFICATION PERMISSION: '
        '${settings.authorizationStatus}',
      );

      // Android notification channel
      if (!kIsWeb) {
        await _messaging
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // الحصول على FCM token
      final token = await getToken();

      debugPrint(
        'FCM TOKEN: $token',
      );

      // مراقبة تغيير Token
      _tokenSubscription?.cancel();

      _tokenSubscription =
          _messaging.onTokenRefresh.listen(
        (newToken) {
          debugPrint(
            'FCM TOKEN REFRESHED: $newToken',
          );
        },
      );

      // الرسائل عندما التطبيق مفتوح
      FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );

      // عند الضغط على إشعار والتطبيق في الخلفية
      FirebaseMessaging.onMessageOpenedApp.listen(
        _handleNotificationTap,
      );

      // عند فتح التطبيق بسبب إشعار وهو مغلق
      final initialMessage =
          await _messaging.getInitialMessage();

      if (initialMessage != null) {
        _handleNotificationTap(
          initialMessage,
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        'NOTIFICATION INITIALIZATION ERROR: $e',
      );

      debugPrint(
        '$stackTrace',
      );
    }
  }

  // =========================================================
  // GET TOKEN
  // =========================================================

  Future<String?> getToken() async {
    try {
      if (kIsWeb) {
        // Web يحتاج VAPID key.
        // إذا كان التطبيق Android فقط، هذا الجزء لن يستخدم.
        return await _messaging.getToken();
      }

      return await _messaging.getToken();
    } catch (e) {
      debugPrint(
        'FCM GET TOKEN ERROR: $e',
      );

      return null;
    }
  }

  // =========================================================
  // TOKEN STREAM
  // =========================================================

  Stream<String> get onTokenRefresh {
    return _messaging.onTokenRefresh;
  }

  // =========================================================
  // FOREGROUND
  // =========================================================

  void _handleForegroundMessage(
    RemoteMessage message,
  ) {
    debugPrint(
      'FOREGROUND NOTIFICATION',
    );

    debugPrint(
      'TITLE: ${message.notification?.title}',
    );

    debugPrint(
      'BODY: ${message.notification?.body}',
    );

    debugPrint(
      'DATA: ${message.data}',
    );
  }

  // =========================================================
  // NOTIFICATION TAP
  // =========================================================

  void _handleNotificationTap(
    RemoteMessage message,
  ) {
    debugPrint(
      'NOTIFICATION CLICKED',
    );

    debugPrint(
      'DATA: ${message.data}',
    );

    final type =
        message.data['type'];

    final ticketId =
        message.data['ticket_id'];

    debugPrint(
      'TYPE: $type',
    );

    debugPrint(
      'TICKET ID: $ticketId',
    );

    // هنا يمكن لاحقاً فتح QueueScreen
    // مباشرة حسب ticket_id.
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
  }
}


// ===========================================================
// BACKGROUND HANDLER
// ===========================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  debugPrint(
    'BACKGROUND MESSAGE: ${message.messageId}',
  );

  debugPrint(
    'DATA: ${message.data}',
  );
}