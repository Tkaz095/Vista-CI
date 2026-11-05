import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/telemetry/app_telemetry.dart';
import '../widgets/app_button.dart';
import '../widgets/app_message.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_controller.dart';
import 'app_config_view_model.dart';
import 'diagnostics_view_model.dart';

class AppSettingsPanel extends StatefulWidget {
  const AppSettingsPanel({
    super.key,
    this.configuration,
    this.telemetry,
    this.onDebugCrash,
  });
  final AppConfigViewModel? configuration;
  final AppTelemetry? telemetry;
  final VoidCallback? onDebugCrash;
  @override
  State<AppSettingsPanel> createState() => _AppSettingsPanelState();
}

class _AppSettingsPanelState extends State<AppSettingsPanel> {
  late final DiagnosticsViewModel diagnostics;
  @override
  void initState() {
    super.initState();
    diagnostics = DiagnosticsViewModel(
      telemetry: widget.telemetry,
      onCrash: widget.onDebugCrash,
    );
  }

  @override
  void dispose() {
    diagnostics.dispose();
    super.dispose();
  }

  Future<void> _confirmCrash() async {
    final accepted = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Thử crash ứng dụng?'),
        content: const Text(
          'App sẽ đóng ngay. Mở lại app để gửi báo cáo Crashlytics.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thử crash'),
          ),
        ],
      ),
    );
    if (mounted && accepted == true) diagnostics.testCrash();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      diagnostics,
      if (widget.configuration != null) widget.configuration!,
      if (widget.telemetry is Listenable) widget.telemetry as Listenable,
    ]),
    builder: (context, _) {
      final configuration = widget.configuration;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Giao diện ứng dụng',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.medium),
          ListenableBuilder(
            listenable: AppThemeController.instance,
            builder: (context, _) {
              final current = AppThemeController.instance.themeMode;
              return SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Hệ thống'),
                    icon: Icon(Icons.brightness_auto_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Sáng'),
                    icon: Icon(Icons.light_mode_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Tối'),
                    icon: Icon(Icons.dark_mode_rounded),
                  ),
                ],
                selected: {current},
                onSelectionChanged: (newSelection) {
                  HapticFeedback.selectionClick();
                  AppThemeController.instance.setThemeMode(newSelection.first);
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.page),
          if (configuration != null) ...[
            Text(
              'Cấu hình ứng dụng',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(
              'Phân tích CI mới: ${configuration.config.analysisEnabled ? "Bật" : "Tắt"}',
            ),
            if (configuration.state.hasError)
              AppMessage(message: configuration.state.message),
            const SizedBox(height: AppSpacing.medium),
            AppButton(
              label: 'Cập nhật cấu hình',
              onPressed: configuration.refresh,
              isLoading: configuration.state.isLoading,
              variant: AppButtonVariant.secondary,
            ),
          ],
          if (kDebugMode && widget.telemetry != null) ...[
            const SizedBox(height: AppSpacing.page),
            Text(
              'Kiểm tra tích hợp · Debug',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.medium),
            if (widget.telemetry!.analyticsError.isNotEmpty)
              AppMessage(message: widget.telemetry!.analyticsError),
            if (widget.telemetry!.crashError.isNotEmpty)
              AppMessage(message: widget.telemetry!.crashError),
            AppButton(
              label: 'Gửi lỗi non-fatal thử nghiệm',
              onPressed: diagnostics.testNonFatal,
              variant: AppButtonVariant.secondary,
            ),
            if (widget.onDebugCrash != null) ...[
              const SizedBox(height: AppSpacing.medium),
              AppButton(
                label: 'Thử crash ứng dụng',
                onPressed: _confirmCrash,
                variant: AppButtonVariant.danger,
              ),
            ],
            if (diagnostics.message.isNotEmpty)
              AppMessage(
                message: diagnostics.message,
                type: AppMessageType.info,
              ),
          ],
        ],
      );
    },
  );
}
