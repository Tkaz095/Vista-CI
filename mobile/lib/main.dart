import 'dart:ui' show PointerDeviceKind;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/repositories/auth_repository.dart';
import 'ui/auth/auth_view.dart';
import 'ui/auth/auth_view_model.dart';

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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vista CI')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
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
          FilledButton(
            onPressed: pending ? null : retry,
            child: Text(pending ? 'Đang thử…' : 'Thử lại'),
          ),
        ],
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
