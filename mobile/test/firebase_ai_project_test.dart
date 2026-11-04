import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vista_mobile/data/models/ci_analysis.dart';
import 'package:vista_mobile/data/services/gemini_analysis_service.dart';
import 'package:vista_mobile/firebase_ai_options.dart';

import 'ci_analysis_test.dart' show inputFor, validOutput;
import 'github_actions_test.dart' show runJson;

import 'package:vista_mobile/data/models/workflow_run.dart';

final primaryOptions = CoreFirebaseOptions(
  apiKey: 'primary-test-key',
  appId: 'primary-test-app',
  projectId: 'vista-ci',
  messagingSenderId: '111',
);

class NativeCore extends MockFirebaseApp {
  final initializedNames = <String>[];

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [
    CoreInitializeResponse(
      name: '[DEFAULT]',
      options: primaryOptions,
      pluginConstants: {},
    ),
  ];

  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions options,
  ) async {
    initializedNames.add(appName);
    return CoreInitializeResponse(
      name: appName,
      options: options,
      pluginConstants: {},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Real Gemini SDK uses only the named AI project and its limited-use App Check token', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final native = NativeCore();
    TestFirebaseCoreHostApi.setUp(native);
    await Firebase.initializeApp();
    final primary = Firebase.app();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = StandardMessageCodec();
    const channel =
        'dev.flutter.pigeon.firebase_app_check_platform_interface.FirebaseAppCheckHostApi';
    final activatedApps = <String>[];
    final tokenApps = <String>[];
    var failActivation = true;
    messenger.setMockMessageHandler('$channel.activate', (message) async {
      final args = codec.decodeMessage(message) as List;
      activatedApps.add(args.first as String);
      expect(args[1], 'debug');
      if (failActivation) {
        return codec.encodeMessage([
          'unavailable',
          'temporary activation failure',
          null,
        ]);
      }
      return codec.encodeMessage([null]);
    });
    messenger.setMockMessageHandler('$channel.getLimitedUseAppCheckToken', (
      message,
    ) async {
      final args = codec.decodeMessage(message) as List;
      final appName = args.first as String;
      tokenApps.add(appName);
      return codec.encodeMessage(['limited-token-for-$appName']);
    });
    messenger.setMockMessageHandler(
      '$channel.registerTokenListener',
      (_) async => codec.encodeMessage([
        'unavailable',
        'no native listener in this test',
        null,
      ]),
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_ai'),
      (_) async => {
        'X-Android-Package': 'com.vista.vista_mobile',
        'X-Android-Cert': 'test-cert',
      },
    );
    addTearDown(() {
      for (final method in [
        'activate',
        'getLimitedUseAppCheckToken',
        'registerTokenListener',
      ]) {
        messenger.setMockMessageHandler('$channel.$method', null);
      }
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_ai'),
        null,
      );
      TestFirebaseCoreHostApi.setUp(null);
    });
    var httpCalls = 0;
    final requests = <http.Request>[];
    var denyRequest = false;
    await http.runWithClient(
      () async {
        final input = inputFor(WorkflowRun.fromJson(runJson(10)));
        final service = GeminiAnalysisService();
        await expectLater(
          service.analyze(input),
          throwsA(
            isA<CiAnalysisException>().having(
              (e) => e.message,
              'message',
              contains('AI_APP_CHECK'),
            ),
          ),
        );
        expect(httpCalls, 0);
        failActivation = false;
        final results = await Future.wait([
          service.analyze(input),
          GeminiAnalysisService().analyze(input),
        ]);
        for (final request in requests) {
          expect(request.url.host, 'firebasevertexai.googleapis.com');
          expect(request.url.path, contains('/projects/vista-ai-28543/'));
          expect(
            request.url.path,
            contains('gemini-3.5-flash-lite:generateContent'),
          );
          expect(
            request.headers['X-Firebase-AppCheck'],
            'limited-token-for-${FirebaseAiOptions.appName}',
          );
          expect(request.headers['Authorization'], isNull);
        }
        expect(results.first['summary'], validOutput()['summary']);
        expect(GeminiAnalysisService.modelName, 'gemini-3.5-flash-lite');
        expect(native.initializedNames, [FirebaseAiOptions.appName]);
        expect(activatedApps, [
          FirebaseAiOptions.appName,
          FirebaseAiOptions.appName,
        ]);
        expect(tokenApps, [
          FirebaseAiOptions.appName,
          FirebaseAiOptions.appName,
        ]);
        expect(Firebase.app().options, primary.options);
        expect(Firebase.app().options.projectId, 'vista-ci');
        expect(
          Firebase.app(FirebaseAiOptions.appName).options.projectId,
          'vista-ai-28543',
        );
        expect(
          Firebase.app(FirebaseAiOptions.appName).options.projectId,
          isNot(primary.options.projectId),
        );
        denyRequest = true;
        await expectLater(
          service.analyze(input),
          throwsA(isA<CiAnalysisException>()),
        );
        expect(
          httpCalls,
          3,
        ); // No request is retried against the primary project.
      },
      () => MockClient((request) async {
        httpCalls++;
        requests.add(request);
        if (denyRequest) {
          return http.Response(
            jsonEncode({
              'error': {'message': 'PERMISSION_DENIED: rejected request'},
            }),
            403,
          );
        }
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    {'text': jsonEncode(validOutput())},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });
}
