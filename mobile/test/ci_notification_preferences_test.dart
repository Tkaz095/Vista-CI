import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vista_mobile/data/models/app_notification.dart';
import 'package:vista_mobile/data/models/ci_notification_mode.dart';
import 'package:vista_mobile/data/models/project.dart';
import 'package:vista_mobile/data/services/android_notification_service.dart';
import 'package:vista_mobile/data/services/ci_notification_preferences_service.dart';
import 'package:vista_mobile/data/services/firebase_messaging_service.dart';
import 'package:vista_mobile/ui/notifications/ci_notification_preferences_panel.dart';
import 'package:vista_mobile/ui/notifications/ci_notification_preferences_view_model.dart';
import 'package:vista_mobile/ui/notifications/notification_view_model.dart';

import 'notifications_test.dart'
    show FakeMessaging, FakeHistory, FakeCache, notice, payload, flush;

class FakePreferences implements CiNotificationPreferences {
  final stream = StreamController<CiNotificationMode>.broadcast();
  final saved = <({String uid, int repo, CiNotificationMode mode})>[];
  Object? error;
  Completer<void>? pending;
  @override
  Stream<CiNotificationMode> watch(String uid, ProjectRepo repo) =>
      stream.stream;
  @override
  Future<void> save(
    String uid,
    ProjectRepo repo,
    CiNotificationMode mode,
  ) async {
    saved.add((uid: uid, repo: repo.id, mode: mode));
    if (pending != null) await pending!.future;
    if (error != null) throw error!;
  }
}

class FakeSystemNotifications implements SystemNotifications {
  AppNotification? initial;
  void Function(AppNotification)? onTap;
  final shown = <AppNotification>[];
  int clears = 0;
  @override
  Future<AppNotification?> initialize(
    void Function(AppNotification) callback,
  ) async {
    onTap = callback;
    return initial;
  }

  @override
  Future<void> show(AppNotification item) async {
    shown.add(item);
  }

  @override
  Future<void> clear() async {
    clears++;
  }
}

class FailingSystemNotifications extends FakeSystemNotifications {
  @override
  Future<AppNotification?> initialize(
    void Function(AppNotification) callback,
  ) async {
    throw StateError('Android presentation unavailable');
  }
}

AppNotification phase(String value) => AppNotification.parse({
  ...payload(id: 'run_7_10_2_$value'),
  'phase': value,
})!;

void main() {
  const repo = ProjectRepo(id: 7, fullName: 'team/app');
  test('preference save uses owner/repo and waits for confirmation', () async {
    final source = FakePreferences();
    final model = CiNotificationPreferencesViewModel(
      source,
      uid: 'a',
      repo: repo,
    );
    addTearDown(model.dispose);
    await model.load();
    source.stream.add(CiNotificationMode.failures);
    await flush();
    source.pending = Completer<void>();
    final write = model.save(CiNotificationMode.all);
    expect(model.saving, isTrue);
    expect(model.state.data, CiNotificationMode.failures);
    await model.save(CiNotificationMode.results);
    expect(source.saved.length, 1);
    source.pending!.complete();
    await write;
    expect(source.saved.single.uid, 'a');
    expect(source.saved.single.repo, 7);
    expect(model.state.data, CiNotificationMode.all);
    expect(model.saving, isFalse);
  });
  test('failed saves preserve the last confirmed setting; dispose ignores late writes', () async {
    final source = FakePreferences();
    final model = CiNotificationPreferencesViewModel(
      source,
      uid: 'a',
      repo: repo,
    );
    await model.load();
    source.stream.add(CiNotificationMode.off);
    await flush();
    source.error = StateError('offline');
    await model.save(CiNotificationMode.all);
    expect(model.state.data, CiNotificationMode.off);
    expect(model.message, contains('Chưa xác nhận'));
    source.error = null;
    source.pending = Completer<void>();
    final write = model.save(CiNotificationMode.results);
    model.dispose();
    source.pending!.complete();
    await write;
    expect(model.state.data, CiNotificationMode.off);
  });
  testWidgets(
    'settings do not assume a default while server data is unavailable; retry restores selector',
    (tester) async {
      final source = FakePreferences();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CiNotificationPreferencesPanel(
              uid: 'a',
              repo: repo,
              source: source,
            ),
          ),
        ),
      );
      expect(find.byType(DropdownButton<CiNotificationMode>), findsNothing);
      source.stream.addError(StateError('permission-denied'));
      await tester.pumpAndSettle();
      expect(find.text('Tải lại tùy chọn'), findsOneWidget);
      await tester.tap(find.text('Tải lại tùy chọn'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      });
      await tester.pump();
      expect(source.stream.hasListener, isTrue);
      source.stream.add(CiNotificationMode.failures);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<CiNotificationMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bắt đầu và kết quả').last);
      await tester.pumpAndSettle();
      expect(source.saved.single.mode, CiNotificationMode.all);
      expect(find.text('Đã lưu tùy chọn cho repository này.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('a stalled preference read stops loading and offers retry', (
    tester,
  ) async {
    final source = FakePreferences();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CiNotificationPreferencesPanel(
            uid: 'a',
            repo: repo,
            source: source,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 16));
    expect(find.text('Tải lại tùy chọn'), findsOneWidget);
    expect(find.byType(DropdownButton<CiNotificationMode>), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  test('foreground push still displays when Firestore inbox arrives before FCM; duplicates do not display again', () async {
    final messaging = FakeMessaging()..allowed = PushPermission.allowed;
    final history = FakeHistory();
    final system = FakeSystemNotifications();
    final model = NotificationViewModel(
      messaging,
      history,
      FakeCache(),
      system: system,
    );
    addTearDown(model.dispose);
    await model.start();
    model.bindSession('user-a');
    await flush();
    history.controllers['user-a']!.add([phase('started')]);
    await flush();
    messaging.foregroundController.add(phase('started'));
    await flush();
    messaging.foregroundController.add(phase('started'));
    await flush();
    messaging.foregroundController.add(phase('completed'));
    await flush();
    expect(system.shown.length, 2);
    expect(system.shown.first.systemTag, system.shown.last.systemTag);
    expect(model.items.length, 2);
    expect(model.foregroundRevision, 2);
    expect(
      model.items.map((item) => item.phase),
      containsAll(['started', 'completed']),
    );
  });
  test('late started push cannot overwrite a known completed card', () async {
    final messaging = FakeMessaging()..allowed = PushPermission.allowed;
    final system = FakeSystemNotifications();
    final model = NotificationViewModel(
      messaging,
      FakeHistory(),
      FakeCache(),
      system: system,
    );
    addTearDown(model.dispose);
    await model.start();
    model.bindSession('user-a');
    await flush();
    messaging.foregroundController.add(phase('completed'));
    await flush();
    messaging.foregroundController.add(phase('started'));
    await flush();
    expect(system.shown.map((item) => item.phase), ['completed']);
  });
  test('system notification tap uses the same guarded route and changing accounts clears the tray', () async {
    final system = FakeSystemNotifications()..initial = notice();
    final model = NotificationViewModel(
      FakeMessaging(),
      FakeHistory(),
      FakeCache(),
      system: system,
    );
    addTearDown(model.dispose);
    await model.start();
    expect(model.pendingOpen!.id, 'notice_1');
    model.bindSession('user-a');
    await flush();
    model.consumeOpen('notice_1');
    system.onTap!(phase('completed'));
    expect(model.pendingOpen!.target!.attempt, 2);
    model.bindSession('user-b');
    await flush();
    expect(system.clears, 1);
    expect(model.pendingOpen, isNull);
    system.onTap!(notice());
    expect(model.pendingOpen, isNull);
  });
  test(
    'FCM cold-start tap survives an Android presentation initialization error',
    () async {
      final messaging = FakeMessaging()..first = notice();
      final model = NotificationViewModel(
        messaging,
        FakeHistory(),
        FakeCache(),
        system: FailingSystemNotifications(),
      );
      addTearDown(model.dispose);
      await model.start();
      expect(model.pendingOpen!.target!.runId, 10);
      expect(model.pendingOpen!.target!.attempt, 2);
    },
  );
  test(
    'denying system permission keeps history without posting a system card',
    () async {
      final system = FakeSystemNotifications();
      final messaging = FakeMessaging();
      final model = NotificationViewModel(
        messaging,
        FakeHistory(),
        FakeCache(),
        system: system,
      );
      addTearDown(model.dispose);
      await model.start();
      model.bindSession('user-a');
      await flush();
      messaging.foregroundController.add(notice());
      await flush();
      expect(system.shown, isEmpty);
      expect(model.items.length, 1);
    },
  );
  testWidgets(
    'Android bridge uses the same replacement tag and preserves payload on tap',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidNotificationService.channel,
        (call) async {
          calls.add(call);
          return call.method == 'initialize'
              ? jsonEncode(phase('started').toJson())
              : null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          AndroidNotificationService.channel,
          null,
        ),
      );
      final service = AndroidNotificationService();
      final initial = await service.initialize((_) {});
      expect(initial!.phase, 'started');
      await service.show(phase('started'));
      await service.show(phase('completed'));
      final shown = calls.where((call) => call.method == 'show').toList();
      expect(
        (shown.first.arguments as Map)['tag'],
        (shown.last.arguments as Map)['tag'],
      );
      expect(
        AppNotification.parse(
          jsonDecode((shown.last.arguments as Map)['payload'] as String),
        )!.phase,
        'completed',
      );
      await service.clear();
      expect(calls.last.method, 'clear');
    },
  );
}
