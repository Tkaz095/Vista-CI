import 'dart:ui' show PointerDeviceKind;

import 'package:firebase_messaging/firebase_messaging.dart';

import 'data/services/firebase_messaging_service.dart';
import 'ui/notifications/notification_view_model.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'firebase_options.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_runtime.dart';
import 'core/telemetry/app_telemetry.dart';
import 'ui/settings/app_config_view_model.dart';
import 'data/repositories/auth_repository.dart';
import 'ui/auth/auth_view.dart';
import 'ui/auth/auth_view_model.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/app_theme_controller.dart';
import 'ui/widgets/app_loading.dart';
import 'ui/widgets/app_header.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeController.instance.loadTheme();
  Object? failure;
  AppRuntime? runtime;
  try {
    runtime = await _initializeFirebase();
  } catch (error) {
    failure = error;
  }
  runApp(VistaCiApp(initializationFailed: failure != null, runtime: runtime));
}

Future<AppRuntime> _initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  final runtime = AppRuntime();
  await runtime.initialize();
  if (!kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform)) {
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
    } catch (_) {}
  }
  return runtime;
}

class VistaScrollBehavior extends MaterialScrollBehavior {
  const VistaScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}

class VistaCiApp extends StatelessWidget {
  const VistaCiApp({
    super.key,
    this.initializationFailed = false,
    this.runtime,
  });
  final AppRuntime? runtime;
  final bool initializationFailed;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppThemeController.instance,
    builder: (context, _) => MaterialApp(
      title: 'Vista CI',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const VistaScrollBehavior(),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: AppThemeController.instance.themeMode,
      home: initializationFailed
          ? const InitializationError()
          : SessionGate(
              telemetry: runtime?.telemetry,
              configuration: runtime?.configuration,
              notifications: runtime?.notifications,
              onDebugCrash: kDebugMode ? runtime?.crashes.testCrash : null,
            ),
    ),
  );
}

class InitializationError extends StatefulWidget {
  const InitializationError({super.key});
  @override
  State<InitializationError> createState() => _InitializationErrorState();
}

class _InitializationErrorState extends State<InitializationError> {
  bool pending = false;
  Future<void> retry() async {
    if (pending) return;
    setState(() => pending = true);
    try {
      final runtime = await _initializeFirebase();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => SessionGate(
              telemetry: runtime.telemetry,
              configuration: runtime.configuration,
              notifications: runtime.notifications,
              onDebugCrash: kDebugMode ? runtime.crashes.testCrash : null,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppHeader(showNotifications: false),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: retry,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Text(
              'Chưa khởi tạo được Firebase',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            const Text(
              'Kiểm tra cấu hình Android google-services.json và kết nối mạng.',
            ),
            const SizedBox(height: 20),
            if (pending)
              const AppLoading(label: 'Đang khởi tạo Firebase…', compact: true)
            else
              const Text('Kéo xuống để thử khởi tạo lại.'),
          ],
        ),
      ),
    ),
  );
}

class SessionGate extends StatelessWidget {
  const SessionGate({
    super.key,
    this.repository,
    this.telemetry,
    this.configuration,
    this.onDebugCrash,
    this.notifications,
  });
  final NotificationViewModel? notifications;
  final AppTelemetry? telemetry;
  final AppConfigViewModel? configuration;
  final VoidCallback? onDebugCrash;
  final AuthRepository? repository;
  @override
  Widget build(BuildContext context) => Provider<AuthRepository>(
    create: (_) => repository ?? AuthRepository(),
    child: ChangeNotifierProvider<AuthViewModel>(
      create: (context) => AuthViewModel(
        context.read<AuthRepository>(),
        telemetry: telemetry,
        configuration: configuration,
        notifications: notifications,
        onDebugCrash: onDebugCrash,
      ),
      child: Consumer<AuthViewModel>(
        builder: (_, viewModel, _) => AuthView(viewModel: viewModel),
      ),
    ),
  );
}
