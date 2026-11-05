import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vista_mobile/data/repositories/github_actions_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:vista_mobile/core/state/async_state.dart';
import 'package:vista_mobile/data/models/app_notification.dart';
import 'package:vista_mobile/data/models/auth_identity.dart';
import 'package:vista_mobile/data/services/firebase_messaging_service.dart';
import 'package:vista_mobile/data/services/firestore_notification_service.dart';
import 'package:vista_mobile/data/services/notification_cache_service.dart';
import 'package:vista_mobile/ui/auth/auth_view.dart';
import 'package:vista_mobile/ui/auth/auth_view_model.dart';
import 'package:vista_mobile/ui/notifications/notification_center_view.dart';
import 'package:vista_mobile/ui/notifications/notification_run_view.dart';
import 'package:vista_mobile/ui/notifications/notification_view_model.dart';

import 'auth_ui_test.dart' show FakeAuthRepository;
import 'github_actions_test.dart' show FakeActionsRepository;

Map<String, dynamic> payload({String uid = 'user-a', String id = 'notice_1'}) =>
    {
      'notification_id': id,
      'uid': uid,
      'type': 'workflow_run',
      'repo_id': '7',
      'repo_full_name': 'team/app',
      'run_id': '10',
      'attempt': '2',
      'title': 'CI đã hoàn tất',
      'body': 'Kiểm tra kết quả',
      'received_at': '2026-11-05T12:00:00Z',
    };
AppNotification notice({String uid = 'user-a', String id = 'notice_1'}) =>
    AppNotification.parse(payload(uid: uid, id: id))!;
Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class FakeMessaging implements MessagingSource {
  final foregroundController = StreamController<AppNotification>.broadcast();
  final openedController = StreamController<AppNotification>.broadcast();
  final registrationController = StreamController<String>.broadcast();
  AppNotification? first;
  PushPermission allowed = PushPermission.denied;
  int requests = 0;
  int registerCalls = 0;
  int unregisterCalls = 0;
  @override
  Stream<AppNotification> get foreground => foregroundController.stream;
  @override
  Stream<AppNotification> get opened => openedController.stream;
  @override
  Stream<String> get registrations => registrationController.stream;
  @override
  Future<AppNotification?> initial() async => first;
  @override
  Future<PushPermission> permission({bool request = false}) async {
    if (request) requests++;
    return allowed;
  }

  @override
  Future<String> register() async {
    registerCalls++;
    return 'fid-a';
  }

  @override
  Future<void> unregister() async {
    unregisterCalls++;
  }
}

class FakeHistory implements NotificationHistory {
  final controllers = <String, StreamController<List<AppNotification>>>{};
  final received = <String>[];
  final reads = <String>[];
  final registrations = <String>[];
  final removed = <String>[];
  Object? error;
  @override
  Stream<List<AppNotification>> watch(String uid) =>
      (controllers[uid] ??= StreamController<List<AppNotification>>.broadcast())
          .stream;
  @override
  Future<void> receive(String uid, AppNotification notification) async {
    if (error != null) throw error!;
    received.add('$uid:${notification.id}');
  }

  @override
  Future<void> markRead(String uid, String id) async {
    reads.add('$uid:$id');
  }

  @override
  Future<void> saveRegistration(String uid, String fid) async {
    registrations.add('$uid:$fid');
  }

  @override
  Future<void> removeRegistration(String uid) async {
    removed.add(uid);
  }
}

class FakeCache implements NotificationCache {
  final values = <String, AppNotification>{};
  Completer<List<AppNotification>>? gate;
  @override
  Future<List<AppNotification>> load(String uid) async => gate == null
      ? values.values.where((item) => item.uid == uid).toList()
      : await gate!.future;
  @override
  Future<void> save(AppNotification item) async {
    values['${item.uid}:${item.id}'] = item;
  }
}

void main() {
  late FakeMessaging messaging;
  late FakeHistory history;
  late FakeCache cache;
  late NotificationViewModel model;
  setUp(() {
    messaging = FakeMessaging();
    history = FakeHistory();
    cache = FakeCache();
    model = NotificationViewModel(messaging, history, cache);
  });
  tearDown(() {
    model.dispose();
  });

  test('parses real FCM data into an exact run attempt', () {
    final item = notificationFromMessage(RemoteMessage(data: payload()));
    expect(item!.target!.runId, 10);
    expect(item.target!.attempt, 2);
    expect(item.target!.repoFullName, 'team/app');
    expect(item.toJson()['repo_id'], '7');
  });
  test(
    'rejects missing recipients and unsafe targets without interpreting URLs',
    () {
      expect(AppNotification.parse({...payload(), 'uid': ''}), isNull);
      expect(
        AppNotification.parse({...payload(), 'notification_id': '../bad'}),
        isNull,
      );
      for (final change in [
        {'run_id': '0'},
        {'attempt': '9007199254740992'},
        {'repo_full_name': '../app'},
        {'repo_full_name': 'https://evil.test'},
      ]) {
        expect(
          AppNotification.parse({...payload(), ...change})!.target,
          isNull,
        );
      }
    },
  );
  test('receives foreground once, stores history and preserves read status on duplicates', () async {
    await model.start();
    model.bindSession('user-a');
    await flush();
    messaging.foregroundController.add(notice());
    await flush();
    expect(model.unreadCount, 1);
    expect(model.foregroundRevision, 1);
    await model.markRead(notice());
    messaging.foregroundController.add(notice());
    await flush();
    history.controllers['user-a']!.add([notice()]);
    await flush();
    expect(model.items.length, 1);
    expect(model.unreadCount, 0);
    expect(model.foregroundRevision, 1);
    expect(history.reads, contains('user-a:notice_1'));
  });
  test('cold-start target waits for the correct verified account', () async {
    messaging.first = notice();
    await model.start();
    expect(model.pendingOpen!.id, 'notice_1');
    expect(model.items, isEmpty);
    model.bindSession('user-a');
    await flush();
    expect(model.pendingOpen!.target!.attempt, 2);
    model.consumeOpen('notice_1');
    expect(model.pendingOpen, isNull);
  });
  test(
    'another account cannot receive or navigate an old notification',
    () async {
      messaging.first = notice();
      await model.start();
      model.bindSession('user-b');
      await flush();
      expect(model.pendingOpen, isNull);
      messaging.foregroundController.add(notice());
      messaging.openedController.add(notice());
      await flush();
      expect(model.items, isEmpty);
      expect(model.pendingOpen, isNull);
      expect(cache.values, isEmpty);
    },
  );
  test('late local loads are discarded after account changes', () async {
    cache.gate = Completer<List<AppNotification>>();
    model.bindSession('user-a');
    model.bindSession('user-b');
    cache.gate!.complete([notice()]);
    await flush();
    expect(model.items.where((item) => item.uid == 'user-a'), isEmpty);
  });
  test(
    'permission denial keeps the inbox usable and never requests on startup',
    () async {
      model.bindSession('user-a');
      await flush();
      expect(model.permission, PushPermission.denied);
      expect(messaging.requests, 0);
      expect(messaging.registerCalls, 0);
      history.controllers['user-a']!.add([notice()]);
      await flush();
      expect(model.items.length, 1);
      messaging.allowed = PushPermission.allowed;
      await model.configurePush(request: true);
      expect(messaging.requests, 1);
      expect(model.registrationId, 'fid-a');
      expect(history.registrations, ['user-a:fid-a']);
    },
  );
  test('registration refresh updates the signed-in device', () async {
    messaging.allowed = PushPermission.allowed;
    await model.start();
    model.bindSession('user-a');
    await flush();
    messaging.registrationController.add('fid-new');
    await flush();
    expect(model.registrationId, 'fid-new');
    expect(history.registrations.last, 'user-a:fid-new');
  });
  test(
    'sign out clears user data and unregisters before Firebase auth ends',
    () async {
      await model.start();
      model.bindSession('user-a');
      await flush();
      messaging.foregroundController.add(notice());
      await flush();
      model.open(notice());
      await model.beforeSignOut();
      expect(model.uid, isNull);
      expect(model.items, isEmpty);
      expect(model.pendingOpen, isNull);
      expect(history.removed, ['user-a']);
      expect(messaging.unregisterCalls, 1);
    },
  );
  test(
    'Firestore failure retains the received notification and reports an error',
    () async {
      await model.start();
      model.bindSession('user-a');
      await flush();
      history.error = StateError('offline');
      messaging.foregroundController.add(notice());
      await flush();
      expect(model.items.length, 1);
      expect(cache.values.length, 1);
      expect(model.state.hasError, isTrue);
    },
  );
  test(
    'local read markers survive background duplicate writes and isolate UIDs',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final local = NotificationCacheService();
      await local.save(notice().asRead());
      await local.save(notice());
      expect((await local.load('user-a')).single.read, isTrue);
      expect(await local.load('user-b'), isEmpty);
    },
  );
  test('run resolver preserves the requested attempt and handles inaccessible runs', () async {
    final github = FakeActionsRepository();
    final resolver = NotificationRunViewModel(github, notice().target!, 'fake');
    addTearDown(resolver.dispose);
    await resolver.load();
    expect(resolver.state.data!.attempt, 2);
    github.error = StateError('404');
    await resolver.load();
    expect(resolver.state.status, LoadStatus.error);
    expect(resolver.state.data, isNull);
  });
  test(
    'GitHub resolver requests the original attempt and rejects repo mismatch',
    () async {
      final repo = NotificationRunViewModel(
        FakeActionsRepository(),
        notice().target!,
        'fake',
      ).repo;
      for (final repoId in [7, 99]) {
        await http.runWithClient(
          () async {
            final request = GitHubActionsRepository().getRunAttempt(
              'fake',
              repo,
              10,
              2,
            );
            if (repoId == 7) {
              expect((await request).attempt, 2);
            } else {
              await expectLater(request, throwsA(anything));
            }
          },
          () => MockClient((request) async {
            expect(request.url.host, 'api.github.com');
            expect(
              request.url.path,
              '/repos/team/app/actions/runs/10/attempts/2',
            );
            return http.Response(
              jsonEncode({
                'id': 10,
                'name': 'CI',
                'run_number': 30,
                'run_attempt': 2,
                'status': 'completed',
                'repository': {'id': repoId},
              }),
              200,
            );
          }),
        );
      }
    },
  );
  testWidgets(
    'foreground banner and protected screens are removed at sign out',
    (tester) async {
      final repository = FakeAuthRepository();
      final auth = AuthViewModel(repository, notifications: model);
      addTearDown(auth.dispose);
      await model.start();
      await tester.pumpWidget(MaterialApp(home: AuthView(viewModel: auth)));
      await tester.pumpAndSettle();
      repository.emit(
        const AuthIdentity(uid: 'user-a', email: '', displayName: 'A'),
      );
      await tester.pumpAndSettle();
      messaging.foregroundController.add(notice());
      await tester.pumpAndSettle();
      expect(find.text('CI đã hoàn tất'), findsOneWidget);
      expect(find.text('Xem'), findsOneWidget);
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục với GitHub'), findsOneWidget);
      expect(find.text('CI đã hoàn tất'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'notification opens the actual workflow detail for the selected attempt',
    (tester) async {
      final repository = FakeAuthRepository()..githubAccessToken = 'fake';
      final auth = AuthViewModel(repository, notifications: model);
      addTearDown(auth.dispose);
      await model.start();
      await http.runWithClient(
        () async {
          await tester.pumpWidget(MaterialApp(home: AuthView(viewModel: auth)));
          await tester.pumpAndSettle();
          repository.emit(
            const AuthIdentity(uid: 'user-a', email: '', displayName: 'A'),
          );
          await tester.pumpAndSettle();
          model.open(notice());
          await tester.pumpAndSettle();
          expect(find.text('CI #30'), findsOneWidget);
          expect(find.text('Mở workflow run'), findsNothing);
          expect(history.reads, contains('user-a:notice_1'));
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/jobs')) {
            return http.Response('{"jobs":[]}', 200);
          }
          expect(
            request.url.path,
            '/repos/team/app/actions/runs/10/attempts/2',
          );
          return http.Response(
            jsonEncode({
              'id': 10,
              'name': 'CI',
              'run_number': 30,
              'run_attempt': 2,
              'status': 'completed',
              'conclusion': 'success',
              'repository': {'id': 7},
            }),
            200,
          );
        }),
      );
    },
  );
  testWidgets(
    'Notification Center renders empty, unread and read states and requests permission',
    (tester) async {
      model.bindSession('user-a');
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(home: NotificationCenterView(model: model)),
      );
      expect(find.textContaining('Chưa có thông báo'), findsOneWidget);
      await tester.tap(find.text('Bật thông báo'));
      await tester.pumpAndSettle();
      expect(messaging.requests, 1);
      history.controllers['user-a']!.add([notice()]);
      await tester.pumpAndSettle();
      expect(find.text('CI đã hoàn tất'), findsOneWidget);
      expect(find.byIcon(Icons.mark_email_unread_outlined), findsOneWidget);
      await model.markRead(notice());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mark_email_unread_outlined), findsNothing);
      await tester.tap(find.text('CI đã hoàn tất'));
      await tester.pump();
      expect(model.pendingOpen!.target!.runId, 10);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'tap waits at login then opens the reconnect screen; logout removes protected routes',
    (tester) async {
      final repository = FakeAuthRepository();
      final auth = AuthViewModel(repository, notifications: model);
      addTearDown(auth.dispose);
      messaging.first = notice();
      await model.start();
      await tester.pumpWidget(MaterialApp(home: AuthView(viewModel: auth)));
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục với GitHub'), findsOneWidget);
      repository.emit(
        const AuthIdentity(uid: 'user-a', email: '', displayName: 'A'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kết nối lại GitHub'), findsOneWidget);
      expect(find.text('team/app · run 10 · attempt 2'), findsOneWidget);
      await http.runWithClient(
        () async {
          await tester.tap(find.text('Kết nối lại GitHub'));
          await tester.pumpAndSettle();
          expect(find.text('CI #30'), findsOneWidget);
          expect(model.pendingOpen, isNull);
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/jobs')) {
            return http.Response('{"jobs":[]}', 200);
          }
          expect(
            request.url.path,
            '/repos/team/app/actions/runs/10/attempts/2',
          );
          return http.Response(
            jsonEncode({
              'id': 10,
              'name': 'CI',
              'run_number': 30,
              'run_attempt': 2,
              'status': 'completed',
              'conclusion': 'success',
              'repository': {'id': 7},
            }),
            200,
          );
        }),
      );
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Tiếp tục với GitHub'), findsOneWidget);
      expect(find.byType(NotificationRunView), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
