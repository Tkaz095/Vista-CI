import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../firebase_options.dart';
import '../models/app_notification.dart';
import 'notification_cache_service.dart';

enum PushPermission { unknown, allowed, denied }

abstract interface class MessagingSource {
  Stream<AppNotification> get foreground;
  Stream<AppNotification> get opened;
  Stream<String> get registrations;
  Future<AppNotification?> initial();
  Future<PushPermission> permission({bool request = false});
  Future<String> register();
  Future<void> unregister();
}

AppNotification? notificationFromMessage(RemoteMessage message) =>
    AppNotification.parse(
      message.data,
      messageId: message.messageId?.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_'),
      title: message.notification?.title,
      body: message.notification?.body,
      sentAt: message.sentTime,
    );

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final item = notificationFromMessage(message);
  if (item != null) await NotificationCacheService().save(item);
}

class FirebaseMessagingService implements MessagingSource {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  @override
  Stream<AppNotification> get foreground => FirebaseMessaging.onMessage
      .map(notificationFromMessage)
      .where((item) => item != null)
      .cast<AppNotification>();
  @override
  Stream<AppNotification> get opened => FirebaseMessaging.onMessageOpenedApp
      .map(notificationFromMessage)
      .where((item) => item != null)
      .cast<AppNotification>();
  @override
  Stream<String> get registrations => _messaging.onRegistered;
  @override
  Future<AppNotification?> initial() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : notificationFromMessage(message);
  }

  @override
  Future<PushPermission> permission({bool request = false}) async {
    final settings = request
        ? await _messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )
        : await _messaging.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => PushPermission.allowed,
      AuthorizationStatus.denied => PushPermission.denied,
      _ => PushPermission.unknown,
    };
  }

  @override
  Future<String> register() async {
    final result = Completer<String>();
    final subscription = _messaging.onRegistered.listen(
      (fid) {
        if (!result.isCompleted) result.complete(fid);
      },
      onError: (Object error, StackTrace stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      },
    );
    try {
      final completed = await Future.wait<Object?>([
        _messaging.register().timeout(const Duration(seconds: 15)),
        result.future.timeout(const Duration(seconds: 15)),
      ]);
      return completed[1] as String;
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> unregister() => _messaging.unregister();
}
