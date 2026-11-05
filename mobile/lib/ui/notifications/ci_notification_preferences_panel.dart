import 'package:flutter/material.dart';

import '../../core/telemetry/app_telemetry.dart';
import '../../data/models/ci_notification_mode.dart';
import '../../data/models/project.dart';
import '../../data/services/ci_notification_preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_message.dart';
import 'ci_notification_preferences_view_model.dart';

class CiNotificationPreferencesPanel extends StatefulWidget {
  const CiNotificationPreferencesPanel({
    super.key,
    required this.uid,
    required this.repo,
    this.source,
    this.telemetry,
  });
  final String uid;
  final ProjectRepo repo;
  final CiNotificationPreferences? source;
  final AppTelemetry? telemetry;
  @override
  State<CiNotificationPreferencesPanel> createState() =>
      _CiNotificationPreferencesPanelState();
}

class _CiNotificationPreferencesPanelState
    extends State<CiNotificationPreferencesPanel> {
  late final model = CiNotificationPreferencesViewModel(
    widget.source ?? CiNotificationPreferencesService(),
    uid: widget.uid,
    repo: widget.repo,
    telemetry: widget.telemetry,
  );
  @override
  void initState() {
    super.initState();
    model.load();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Thông báo CI', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.small),
        if (model.state.isLoading)
          const AppLoading(label: 'Đang tải tùy chọn thông báo…', compact: true)
        else if (model.state.hasError) ...[
          AppMessage(message: model.state.message),
          TextButton(
            onPressed: model.load,
            child: const Text('Tải lại tùy chọn'),
          ),
        ] else ...[
          InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CiNotificationMode>(
                isExpanded: true,
                value: model.state.data,
                items: [
                  for (final mode in CiNotificationMode.values)
                    DropdownMenuItem(value: mode, child: Text(mode.label)),
                ],
                onChanged: model.saving
                    ? null
                    : (mode) {
                        if (mode != null) model.save(mode);
                      },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          const Text(
            'Áp dụng cho repo này trong mọi project. Repository cần bật tích hợp gửi cập nhật CI với Vista. Bật quyền thông báo tại biểu tượng chuông.',
          ),
          if (model.saving) const AppLoading(label: 'Đang lưu…', compact: true),
        ],
        if (model.message.isNotEmpty)
          AppMessage(message: model.message, type: AppMessageType.info),
        if (model.message.startsWith('Chưa'))
          TextButton(
            onPressed: model.load,
            child: const Text('Tải lại tùy chọn'),
          ),
      ],
    ),
  );
}
