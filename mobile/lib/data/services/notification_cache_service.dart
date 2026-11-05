import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';

abstract interface class NotificationCache {
  Future<List<AppNotification>> load(String uid);
  Future<void> save(AppNotification notification);
}

/// Separate keys avoid read/modify/write races between the FCM background isolate
/// and the UI isolate. Async preferences avoid a stale isolate-local cache.
class NotificationCacheService implements NotificationCache {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  String _prefix(String uid) =>
      'ci_notification:${base64Url.encode(utf8.encode(uid))}:';
  @override
  Future<void> save(AppNotification notification) async {
    final key = '${_prefix(notification.uid)}${notification.id}';
    if (notification.read) await _preferences.setBool('$key:read', true);
    await _preferences.setString(key, jsonEncode(notification.toJson()));
  }

  @override
  Future<List<AppNotification>> load(String uid) async {
    final keys = (await _preferences.getKeys()).where(
      (key) => key.startsWith(_prefix(uid)) && !key.endsWith(':read'),
    );
    final items = <AppNotification>[];
    for (final key in keys) {
      try {
        final value = await _preferences.getString(key);
        if (value == null) continue;
        final item = AppNotification.parse(
          jsonDecode(value) as Map<String, dynamic>,
        );
        if (item != null && item.uid == uid) {
          items.add(
            await _preferences.getBool('$key:read') == true
                ? item.asRead()
                : item,
          );
        }
      } on FormatException {
        /* Ignore invalid local entries. */
      } on TypeError {
        /* Ignore invalid local entries. */
      }
    }
    items.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    for (final item in items.skip(200)) {
      await _preferences.remove('${_prefix(uid)}${item.id}');
      await _preferences.remove('${_prefix(uid)}${item.id}:read');
    }
    return items.take(200).toList();
  }
}
