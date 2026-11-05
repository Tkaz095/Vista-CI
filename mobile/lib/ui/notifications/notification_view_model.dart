import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/state/async_state.dart';
import '../../core/telemetry/app_telemetry.dart';
import '../../data/models/app_notification.dart';
import '../../data/services/firebase_messaging_service.dart';
import '../../data/services/firestore_notification_service.dart';
import '../../data/services/notification_cache_service.dart';
import '../../data/services/android_notification_service.dart';

class NotificationViewModel extends ChangeNotifier {
  NotificationViewModel(
    this.messaging,
    this.history,
    this.cache, {
    this.telemetry,
    this.system,
  });
  final MessagingSource messaging;
  final NotificationHistory history;
  final NotificationCache cache;
  final AppTelemetry? telemetry;
  final SystemNotifications? system;
  final _foregroundSeen = <String>{};
  final _subscriptions = <StreamSubscription<dynamic>>[];
  StreamSubscription<List<AppNotification>>? _inbox;
  final _items = <String, AppNotification>{};
  final _unsynced = <String>{};
  String? uid;
  int _version = 0;
  bool _disposed = false;
  bool _started = false;
  bool _permissionBusy = false;
  bool get permissionBusy => _permissionBusy;
  AsyncState<List<AppNotification>> state = const AsyncState.empty();
  PushPermission permission = PushPermission.unknown;
  String setupError = '';
  String? registrationId;
  AppNotification? pendingOpen;
  AppNotification? foregroundNotice;
  int foregroundRevision = 0;
  List<AppNotification> get items => List.unmodifiable(
    _items.values.toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt)),
  );
  int get unreadCount => _items.values.where((item) => !item.read).length;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int version, String owner) =>
      !_disposed && version == _version && uid == owner;
  void _failure(Object error, StackTrace stack) =>
      telemetry?.nonFatal(error, stack, AppOperation.notifications);

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _subscriptions.add(
      messaging.foreground.listen(
        (item) => unawaited(_receive(item)),
        onError: (Object e, StackTrace s) {
          _failure(e, s);
        },
      ),
    );
    _subscriptions.add(
      messaging.opened.listen(
        open,
        onError: (Object e, StackTrace s) {
          _failure(e, s);
        },
      ),
    );
    _subscriptions.add(
      messaging.registrations.listen(
        (value) {
          final owner = uid;
          if (owner != null &&
              permission == PushPermission.allowed &&
              !_permissionBusy) {
            unawaited(_saveRegistration(owner, value, _version));
          }
        },
        onError: (Object e, StackTrace s) {
          _failure(e, s);
        },
      ),
    );
    try {
      final localInitial = await system?.initialize(open);
      if (!_disposed && localInitial != null) open(localInitial);
    } catch (error, stack) {
      _failure(error, stack);
    }
    // A local Android presentation failure must not drop the FCM cold-start tap.
    try {
      final initial = await messaging.initial();
      if (!_disposed && initial != null) open(initial);
    } catch (error, stack) {
      _failure(error, stack);
    }
  }

  void bindSession(String? owner) {
    if (_disposed || uid == owner) return;
    final previousOwner = uid;
    _version++;
    uid = owner;
    if (previousOwner != null) unawaited(_clearSystem());
    registrationId = null;
    setupError = '';
    _permissionBusy = false;
    permission = PushPermission.unknown;
    _inbox?.cancel();
    _inbox = null;
    _items.clear();
    _foregroundSeen.clear();
    _unsynced.clear();
    foregroundNotice = null;
    if (pendingOpen != null && pendingOpen!.uid != owner && owner != null) {
      pendingOpen = null;
    }
    state = owner == null
        ? const AsyncState.empty()
        : const AsyncState.loading();
    _notify();
    if (owner != null) {
      unawaited(refresh());
      unawaited(configurePush());
      if (pendingOpen?.uid == owner) {
        unawaited(_receive(pendingOpen!, foreground: false));
      }
    }
  }

  void _merge(AppNotification item) {
    final existing = _items[item.id];
    _items[item.id] = existing?.read == true ? item.asRead() : item;
    if (_items.length > 200) {
      final oldest = _items.values.reduce(
        (a, b) => a.receivedAt.isBefore(b.receivedAt) ? a : b,
      );
      _items.remove(oldest.id);
      _unsynced.remove(oldest.id);
    }
  }

  void _publish() {
    final list = items.take(200).toList();
    state = list.isEmpty ? const AsyncState.empty() : AsyncState.success(list);
    _notify();
  }

  Future<void> refresh() async {
    final owner = uid;
    if (owner == null || _disposed) return;
    final version = _version;
    state = AsyncState.loading(items);
    _notify();
    try {
      final local = await cache.load(owner);
      if (!_current(version, owner)) return;
      for (final item in local) {
        if (item.uid != owner) continue;
        _merge(item);
      }
      _publish();
      await _inbox?.cancel();
      if (!_current(version, owner)) return;
      for (final id in _unsynced.toList()) {
        final item = _items[id];
        if (item == null) continue;
        await history.receive(owner, item);
        if (!_current(version, owner)) return;
        if (item.read) await history.markRead(owner, item.id);
        if (!_current(version, owner)) return;
        _unsynced.remove(id);
      }
      _inbox = history
          .watch(owner)
          .listen(
            (remote) {
              if (!_current(version, owner)) return;
              for (final item in remote) {
                if (item.uid == owner) _merge(item);
              }
              _publish();
            },
            onError: (Object error, StackTrace stack) {
              if (!_current(version, owner)) return;
              _failure(error, stack);
              state = AsyncState.error(
                'Chưa đồng bộ được thông báo. Kiểm tra mạng và Firestore Rules notifications, rồi thử lại.',
                items,
              );
              _notify();
            },
          );
    } catch (error, stack) {
      if (!_current(version, owner)) return;
      _failure(error, stack);
      state = AsyncState.error(
        'Chưa tải được lịch sử thông báo. Hãy thử lại.',
        items,
      );
      _notify();
    }
  }

  Future<void> _receive(AppNotification item, {bool foreground = true}) async {
    final owner = uid;
    if (_disposed || owner == null || item.uid != owner) return;
    final version = _version;
    final duplicate = _foregroundSeen.contains(item.id);
    final superseded =
        item.phase == 'started' &&
        _items.values.any(
          (saved) =>
              saved.phase == 'completed' && saved.systemTag == item.systemTag,
        );
    _merge(item);
    final present = foreground && !duplicate && !superseded;
    if (present) {
      _foregroundSeen.add(item.id);
      foregroundNotice = item;
      foregroundRevision++;
    }
    _publish();
    try {
      if (present && permission == PushPermission.allowed) {
        try {
          await system?.show(item);
        } catch (error, stack) {
          _failure(error, stack);
        }
        if (!_current(version, owner)) return;
      }
      await cache.save(_items[item.id] ?? item);
      if (!_current(version, owner)) return;
      await history.receive(owner, item);
      if (!_current(version, owner)) return;
      if (_items[item.id]?.read == true) await history.markRead(owner, item.id);
      if (_current(version, owner)) _unsynced.remove(item.id);
    } catch (error, stack) {
      if (!_current(version, owner)) return;
      _failure(error, stack);
      _unsynced.add(item.id);
      state = AsyncState.error(
        'Thông báo đã nhận; chưa đồng bộ được lịch sử lên Firebase. Kéo xuống để thử lại.',
        items,
      );
      _notify();
    }
  }

  void open(AppNotification item) {
    if (_disposed || (uid != null && uid != item.uid)) return;
    pendingOpen = item;
    if (uid == item.uid) unawaited(_receive(item, foreground: false));
    _notify();
  }

  void consumeOpen(String id) {
    if (pendingOpen?.id == id) pendingOpen = null;
  }

  Future<void> markRead(AppNotification item) async {
    final owner = uid;
    if (owner == null || item.uid != owner || _disposed) return;
    final version = _version;
    final read = item.asRead();
    _merge(read);
    _publish();
    try {
      await cache.save(read);
      if (!_current(version, owner)) return;
      await history.receive(owner, item);
      if (!_current(version, owner)) return;
      await history.markRead(owner, item.id);
    } catch (error, stack) {
      if (!_current(version, owner)) return;
      _failure(error, stack);
      state = AsyncState.error(
        'Đã đọc trên thiết bị; chưa đồng bộ trạng thái lên Firebase.',
        items,
      );
      _notify();
    }
  }

  Future<void> configurePush({bool request = false}) async {
    final owner = uid;
    if (_disposed || owner == null || _permissionBusy) return;
    final version = _version;
    _permissionBusy = true;
    setupError = '';
    _notify();
    try {
      final value = await messaging.permission(request: request);
      if (!_current(version, owner)) return;
      permission = value;
      if (value == PushPermission.allowed) {
        final value = await messaging.register();
        if (!_current(version, owner)) return;
        if (value.isEmpty) throw StateError('No FCM registration');
        await _saveRegistration(owner, value, version);
      }
    } catch (error, stack) {
      if (!_current(version, owner)) return;
      _failure(error, stack);
      setupError = 'Chưa đăng ký được thông báo đẩy. Kiểm tra Google Play services, mạng và Firestore Rules devices.';
    } finally {
      if (_current(version, owner)) {
        _permissionBusy = false;
        _notify();
      }
    }
  }

  Future<void> _saveRegistration(
    String owner,
    String value,
    int version,
  ) async {
    try {
      if (!_current(version, owner)) return;
      await history.saveRegistration(owner, value);
      if (_current(version, owner)) {
        registrationId = value;
        setupError = '';
        _notify();
      }
    } catch (error, stack) {
      if (!_current(version, owner)) return;
      _failure(error, stack);
      setupError = 'Chưa lưu được thiết bị nhận thông báo. Kiểm tra Rules devices rồi thử lại.';
      _notify();
    }
  }

  Future<void> _clearSystem() async {
    try {
      await system?.clear();
    } catch (error, stack) {
      _failure(error, stack);
    }
  }

  /// Called before Firebase sign-out, while deleting the owner device is allowed.
  Future<void> beforeSignOut() async {
    final owner = uid;
    bindSession(null);
    pendingOpen = null;
    await _clearSystem();
    if (owner == null) return;
    try {
      await history.removeRegistration(owner);
    } catch (error, stack) {
      _failure(error, stack);
    }
    try {
      await messaging.unregister().timeout(const Duration(seconds: 5));
    } catch (error, stack) {
      _failure(error, stack);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _version++;
    _inbox?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
