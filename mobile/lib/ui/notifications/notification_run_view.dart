import 'package:flutter/material.dart';

import '../../core/state/async_state.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/project.dart';
import '../../data/models/workflow_run.dart';
import '../../data/repositories/github_actions_repository.dart';
import '../auth/auth_view_model.dart';
import '../projects/workflow_run_detail_view.dart';
import '../widgets/app_button.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_message.dart';
import '../widgets/app_stack_header.dart';
import '../theme/app_theme.dart';

class NotificationRunViewModel extends ChangeNotifier {
  NotificationRunViewModel(this.repository, this.target, this.token);
  final GitHubActionsRepository repository;
  final NotificationTarget target;
  final String? token;
  AsyncState<WorkflowRun> state = const AsyncState.loading();
  bool _disposed = false;
  ProjectRepo get repo =>
      ProjectRepo(id: target.repoId, fullName: target.repoFullName);
  Future<void> load() async {
    if (_disposed) return;
    state = const AsyncState.loading();
    notifyListeners();
    try {
      final run = await repository.getRunAttempt(
        token,
        repo,
        target.runId,
        target.attempt,
      );
      if (!_disposed) state = AsyncState.success(run);
    } catch (_) {
      if (!_disposed) {
        state = const AsyncState.error(
          'Chưa mở được run này. Kiểm tra mạng, quyền repository hoặc run đã bị xóa. App giữ nguyên run/attempt từ thông báo.',
        );
      }
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class NotificationRunView extends StatefulWidget {
  const NotificationRunView({
    super.key,
    required this.target,
    required this.auth,
    this.repository,
  });
  final NotificationTarget target;
  final AuthViewModel auth;
  final GitHubActionsRepository? repository;
  @override
  State<NotificationRunView> createState() => _NotificationRunViewState();
}

class _NotificationRunViewState extends State<NotificationRunView> {
  late final model = NotificationRunViewModel(
    widget.repository ?? GitHubActionsRepository(),
    widget.target,
    widget.auth.githubAccessToken,
  );
  @override
  void initState() {
    super.initState();
    if (model.token != null) model.load();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([model, widget.auth]),
    builder: (context, _) {
      final run = model.state.data;
      if (run != null) {
        return WorkflowRunDetailView(
          repo: model.repo,
          run: run,
          repository: model.repository,
          accessToken: model.token,
          ownerUid: widget.auth.profile?.uid,
          configuration: widget.auth.configuration,
          telemetry: widget.auth.telemetry,
        );
      }
      return Scaffold(
        appBar: const AppStackHeader(title: 'Mở workflow run'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text(
                '${widget.target.repoFullName} · run ${widget.target.runId} · attempt ${widget.target.attempt}',
              ),
              const SizedBox(height: AppSpacing.page),
              if (model.token == null) ...[
                const Text(
                  'Phiên Firebase vẫn còn, nhưng cần kết nối lại GitHub để đọc workflow run.',
                ),
                const SizedBox(height: AppSpacing.medium),
                AppButton(
                  label: 'Kết nối lại GitHub',
                  isLoading: widget.auth.busy,
                  onPressed: widget.auth.signInWithGitHub,
                ),
                if (widget.auth.actionMessage.isNotEmpty)
                  AppMessage(message: widget.auth.actionMessage),
              ] else if (model.state.isLoading)
                const AppLoading(label: 'Đang đọc workflow run từ GitHub…')
              else ...[
                AppMessage(message: model.state.message),
                AppButton(label: 'Thử lại', onPressed: model.load),
              ],
            ],
          ),
        ),
      );
    },
  );
}
