import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_notification.dart';

abstract interface class SystemNotifications {
  Future<AppNotification?> initialize(void Function(AppNotification) onTap);
  Future<void> show(AppNotification notification);
  Future<void> clear();
}

/// Android system tray presentation for foreground FCM. Remote background pushes
/// use the same channel + tag + ID=0, so a result replaces the started card.
class AndroidNotificationService implements SystemNotifications {
  static const channel = MethodChannel('vista_ci/notifications');
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  AppNotification? _parse(Object? value) {
    if (value is! String) return null;
    try {
      return AppNotification.parse(jsonDecode(value) as Map<String, dynamic>);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<AppNotification?> initialize(
    void Function(AppNotification) onTap,
  ) async {
    if (!_supported) return null;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'notificationTap') {
        final item = _parse(call.arguments);
        if (item != null) onTap(item);
      }
    });
    return _parse(await channel.invokeMethod<String>('initialize'));
  }

  @override
  Future<void> show(AppNotification notification) async {
    if (!_supported) return;
    await channel.invokeMethod<void>('show', {
      'title': notification.title,
      'body': notification.body,
      'tag': notification.systemTag,
      'payload': jsonEncode(notification.toJson()),
      'timestamp': notification.receivedAt.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> clear() async {
    if (_supported) await channel.invokeMethod<void>('clear');
  }
}
