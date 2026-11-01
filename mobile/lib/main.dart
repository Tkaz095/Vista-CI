import 'dart:ui' show PointerDeviceKind;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'features/auth/session_view_model.dart';
import 'features/auth/session_views.dart';
import 'features/workspaces/workspace_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? failure;
  try {
    await Firebase.initializeApp();
  } catch (error) {
    failure = error;
  }
  runApp(VistaCiApp(initializationFailed: failure != null));
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
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8FAFC),
        scrolledUnderElevation: 0,
      ),
    ),
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
    setState(() => pending = true);
    try {
      await Firebase.initializeApp();
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
  Widget build(BuildContext context) => StatusPage(
    title: 'Chưa khởi tạo được Firebase',
    message: 'Kiểm tra cấu hình Android google-services.json và kết nối mạng.',
    actions: [
      FilledButton(
        onPressed: pending ? null : retry,
        child: Text(pending ? 'Đang thử…' : 'Thử lại'),
      ),
    ],
  );
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key, this.repository});
  final AuthRepository? repository;
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final SessionViewModel session = SessionViewModel(
    widget.repository ?? AuthRepository(),
  );
  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      switch (session.status) {
        case SessionStatus.loading:
          return const StatusPage(
            title: 'Đang xác minh phiên và hồ sơ',
            message: 'Vui lòng chờ kết quả từ Firebase.',
            actions: [CircularProgressIndicator()],
          );
        case SessionStatus.signedOut:
          return LoginScreen(repository: session.repository);
        case SessionStatus.ready:
          final profile = session.profile!;
          return WorkspaceScreen(
            key: ValueKey(profile.uid),
            profile: profile,
            auth: session.repository,
          );
        case SessionStatus.blocked:
        case SessionStatus.error:
          return StatusPage(
            title: 'Chưa thể mở Vista',
            message: session.message,
            actions: [
              FilledButton(
                onPressed: session.retry,
                child: const Text('Kiểm tra lại'),
              ),
              LogoutButton(repository: session.repository),
            ],
          );
      }
    },
  );
}
