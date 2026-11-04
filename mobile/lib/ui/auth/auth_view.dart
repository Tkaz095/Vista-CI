import 'package:flutter/material.dart';

import '../home/home_view.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_message.dart';
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
    appBar: null,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final theme = Theme.of(context);
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 480,
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.section),
                          Image.asset(
                            'assets/logo/logo.png',
                            height: 80,
                            cacheHeight: 320,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(height: AppSpacing.page),
                          Text(
                            'Vista',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.displaySmall,
                          ),
                          const SizedBox(height: AppSpacing.control),
                          Text(
                            'Quản lý project và repository GitHub của bạn.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.section),
                          Text(
                            'Đăng nhập Vista',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.medium),
                          AppButton(
                            label: 'Tiếp tục với GitHub',
                            loadingLabel: 'Đang xác thực…',
                            isLoading: viewModel.busy,
                            onPressed: viewModel.signInWithGitHub,
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.onSurface,
                              foregroundColor: theme.colorScheme.surface,
                            ),
                            iconWidget: Image.asset(
                              'assets/logo/github-logo.png',
                              width: 20,
                              height: 20,
                              color: theme.colorScheme.surface,
                              excludeFromSemantics: true,
                            ),
                          ),
                          if (viewModel.actionMessage.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.medium),
                            AppMessage(message: viewModel.actionMessage),
                          ],
                          const SizedBox(height: AppSpacing.medium),
                          Text(
                            'Vista tự tạo hồ sơ khi bạn đăng nhập lần đầu.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.section),
                        child: Text(
                          'Để hiển thị cả repo riêng tư, GitHub sẽ yêu cầu quyền repo '
                          '(gồm đọc và ghi). Vista hiện chỉ đọc danh sách repo.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
