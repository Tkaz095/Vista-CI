import 'dart:ui' show PointerDeviceKind;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'firebase_options.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/repositories/auth_repository.dart';
import 'ui/auth/auth_view.dart';
import 'ui/auth/auth_view_model.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/app_loading.dart';
import 'ui/widgets/app_header.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? failure;
  try {
    await _initializeFirebase();
  } catch (error) {
    failure = error;
  }
  runApp(VistaCiApp(initializationFailed: failure != null));
}

Future<void> _initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform)) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }
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
  const VistaCiApp({super.key, this.initializationFailed = false});
  final bool initializationFailed;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vista CI',
    debugShowCheckedModeBanner: false,
    scrollBehavior: const VistaScrollBehavior(),
    theme: AppTheme.light,
    home: initializationFailed
        ? const InitializationError()
        : const SessionGate(),
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
      await _initializeFirebase();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const SessionGate()),
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

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  final AuthViewModel viewModel = AuthViewModel(AuthRepository());
  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthView(viewModel: viewModel);
}
