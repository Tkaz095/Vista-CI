import 'package:flutter/material.dart';

import '../../data/models/user_profile.dart';
import '../../core/telemetry/app_telemetry.dart';
import '../settings/app_config_view_model.dart';
import '../settings/app_settings_panel.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';

/// Displays the signed-in profile. Authentication still belongs to AuthViewModel.
class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.profile,
    required this.onSignOut,
    this.isSigningOut = false,
    this.onReconnectGitHub,
    this.configuration,
    this.telemetry,
    this.onDebugCrash,
  });

  final UserProfile profile;
  final AppConfigViewModel? configuration;
  final AppTelemetry? telemetry;
  final VoidCallback? onDebugCrash;
  final VoidCallback onSignOut;
  final bool isSigningOut;
  final VoidCallback? onReconnectGitHub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile.displayName.trim().isEmpty
        ? 'Vista User'
        : profile.displayName.trim();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        Text('Tài khoản', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.page),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                if (profile.email.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    profile.email,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.page),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.medium),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.small,
                  children: [
                    Image.asset(
                      'assets/logo/github-logo.png',
                      width: 20,
                      height: 20,
                      excludeFromSemantics: true,
                    ),
                    Text(
                      'Đăng nhập bằng GitHub',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.page),
        if (onReconnectGitHub != null) ...[
          const Text(
            'Phiên Vista đã được khôi phục. Kết nối lại GitHub để tải repository và CI.',
          ),
          const SizedBox(height: AppSpacing.medium),
          AppButton(
            label: 'Kết nối lại GitHub',
            onPressed: onReconnectGitHub,
            isLoading: isSigningOut,
            icon: Icons.link,
          ),
          const SizedBox(height: AppSpacing.medium),
        ],
        AppButton(
          label: 'Đăng xuất',
          loadingLabel: 'Đang đăng xuất…',
          icon: Icons.logout,
          variant: AppButtonVariant.secondary,
          isLoading: isSigningOut,
          onPressed: onSignOut,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
        if (configuration != null || telemetry != null) ...[
          const SizedBox(height: AppSpacing.page),
          AppSettingsPanel(
            configuration: configuration,
            telemetry: telemetry,
            onDebugCrash: onDebugCrash,
          ),
        ],
      ],
    );
  }
}
