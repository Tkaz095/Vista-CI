import 'package:flutter/material.dart';

import '../home/home_view.dart';
import 'auth_view_model.dart';

/// Rebuilds the current screen when login or logout updates the ViewModel.
class AuthView extends StatelessWidget {
  const AuthView({super.key, required this.viewModel});
  final AuthViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final profile = viewModel.profile;
      if (profile == null) return LoginView(viewModel: viewModel);
      return HomeView(
        key: ValueKey(profile.uid),
        profile: profile,
        viewModel: viewModel,
      );
    },
  );
}

class LoginView extends StatelessWidget {
  const LoginView({super.key, required this.viewModel});
  final AuthViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vista CI')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.hub_outlined, size: 52),
              const SizedBox(height: 24),
              Text(
                'Đăng nhập Vista',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              const Text(
                'Theo dõi workspace, repository và các lần chạy CI/CD của nhóm.',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: viewModel.busy ? null : viewModel.signInWithGitHub,
                icon: const Icon(Icons.code),
                label: Text(
                  viewModel.busy ? 'Đang xác thực…' : 'Tiếp tục với GitHub',
                ),
              ),
              const SizedBox(height: 20),
              if (viewModel.actionMessage.isNotEmpty)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    viewModel.actionMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              const Text('Vista tự tạo hồ sơ khi bạn đăng nhập lần đầu.'),
              const SizedBox(height: 12),
              const Text(
                'Để hiển thị cả repo riêng tư, GitHub sẽ yêu cầu quyền repo '
                '(gồm đọc và ghi). Vista hiện chỉ đọc danh sách repo.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
