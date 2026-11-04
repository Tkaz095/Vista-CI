import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/services/firebase_messaging_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_message.dart';
import '../widgets/app_stack_header.dart';
import 'notification_view_model.dart';

class NotificationCenterView extends StatelessWidget {
  const NotificationCenterView({super.key, required this.model});
  final NotificationViewModel model;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Scaffold(
      appBar: const AppStackHeader(title: 'Thông báo'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await model.refresh();
            await model.configurePush();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text(switch (model.permission) {
                PushPermission.allowed => 'Thông báo đẩy đã được cho phép.',
                PushPermission.denied => 'Thông báo đẩy đang tắt. Bạn vẫn xem được lịch sử tại đây. Nếu Android không hỏi lại, bật quyền trong Cài đặt → Ứng dụng → Vista CI → Thông báo.',
                _ => 'Bật thông báo để nhận cập nhật CI khi rời ứng dụng.',
              }),
              const SizedBox(height: AppSpacing.medium),
              AppButton(
                label: model.permission == PushPermission.allowed
                    ? 'Đăng ký lại thiết bị'
                    : 'Bật thông báo',
                onPressed: () => model.configurePush(request: true),
                isLoading: model.permissionBusy,
                variant: AppButtonVariant.secondary,
              ),
              if (kDebugMode && model.registrationId != null) ...[
                const SizedBox(height: AppSpacing.small),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: model.registrationId!),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Đã sao chép FCM Installation ID. Chỉ dùng để gửi thử.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Sao chép FCM Installation ID · Debug'),
                ),
              ],
              if (model.setupError.isNotEmpty)
                AppMessage(message: model.setupError),
              const SizedBox(height: AppSpacing.page),
              if (model.state.isLoading)
                const AppLoading(label: 'Đang tải thông báo…'),
              if (model.state.hasError) ...[
                AppMessage(message: model.state.message),
                TextButton(
                  onPressed: model.refresh,
                  child: const Text('Thử lại'),
                ),
              ],
              if (model.items.isEmpty &&
                  !model.state.isLoading &&
                  !model.state.hasError)
                const Text(
                  'Chưa có thông báo. Các cập nhật CI sẽ xuất hiện tại đây.',
                ),
              for (final item in model.items) ...[
                Card(
                  child: ListTile(
                    leading: Icon(
                      item.read
                          ? Icons.notifications_none
                          : Icons.mark_email_unread_outlined,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.read
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.body.isNotEmpty) Text(item.body),
                        if (item.target != null)
                          Text(
                            '${item.target!.repoFullName} · run ${item.target!.runId} · attempt ${item.target!.attempt}',
                          ),
                        Text(
                          item.receivedAt.toLocal().toString().substring(0, 16),
                        ),
                        if (item.target == null)
                          const Text(
                            'Thông báo này không có đích workflow/run hợp lệ.',
                          ),
                      ],
                    ),
                    trailing: item.target == null
                        ? null
                        : const Icon(Icons.chevron_right),
                    onTap: () {
                      if (item.target == null) {
                        model.markRead(item);
                      } else {
                        model.open(item);
                      }
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
