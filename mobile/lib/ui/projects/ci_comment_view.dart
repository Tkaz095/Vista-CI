import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_message.dart';
import '../widgets/app_stack_header.dart';
import '../widgets/app_text_field.dart';
import 'workflow_run_view_model.dart';

/// The editor owns its text; the run ViewModel owns GitHub state and requests.
class CiCommentView extends StatefulWidget {
  const CiCommentView({super.key, required this.model});
  final WorkflowRunViewModel model;

  @override
  State<CiCommentView> createState() => _CiCommentViewState();
}

class _CiCommentViewState extends State<CiCommentView> {
  late final TextEditingController draft;

  @override
  void initState() {
    super.initState();
    draft = TextEditingController(
      text:
          widget.model.analysis?.comment(widget.model.repo, widget.model.run) ??
          '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.model.loadPullRequests();
    });
  }

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  Future<void> _open(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Keep the editable draft when the browser cannot open.
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chưa mở được GitHub.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final pull = model.selectedPullRequest;
        final posted = model.postedComments[pull?.number];
        final uncertain = model.uncertainComments.contains(pull?.number);
        return PopScope(
          canPop: !model.postingComment,
          child: Scaffold(
            appBar: AppStackHeader(
              title: 'Comment phân tích CI',
              canGoBack: !model.postingComment,
              actions: [
                if (pull != null)
                  IconButton(
                    tooltip: 'Mở PR trên GitHub',
                    onPressed: () => _open(
                      Uri.https(
                        'github.com',
                        '${model.repo.fullName}/pull/${pull.number}',
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new),
                  ),
              ],
            ),
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: model.loadPullRequests,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.page),
                  children: [
                    Text(
                      model.repo.fullName,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    if (model.loadingPullRequests ||
                        !model.hasLoadedPullRequests)
                      const AppLoading(
                        label: 'Đang tìm PR liên quan…',
                        compact: true,
                      ),
                    if (model.hasLoadedPullRequests &&
                        !model.loadingPullRequests &&
                        model.pullRequests.isEmpty &&
                        model.commentError.isEmpty)
                      const AppEmptyState(
                        message:
                            'Không có PR đang mở liên quan đến lần chạy này.',
                      ),
                    if (model.pullRequests.isNotEmpty)
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Pull request',
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            itemHeight: null,
                            value: pull?.number,
                            hint: const Text('Chọn PR'),
                            onChanged:
                                model.postingComment ||
                                    model.loadingPullRequests
                                ? null
                                : (number) {
                                    if (number != null) {
                                      model.selectPullRequest(
                                        model.pullRequests.firstWhere(
                                          (item) => item.number == number,
                                        ),
                                      );
                                    }
                                  },
                            items: [
                              for (final item in model.pullRequests)
                                DropdownMenuItem(
                                  value: item.number,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.small,
                                    ),
                                    child: Text(
                                      '#${item.number} · ${item.title}',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.medium),
                    Text(
                      'Phân tích cho commit ${model.run.sha}, attempt ${model.run.attempt}.',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (pull != null && pull.headSha != model.run.sha) ...[
                      const SizedBox(height: AppSpacing.small),
                      const AppMessage(
                        message: 'SHA đầu PR khác SHA của run (có thể là merge commit hoặc PR đã cập nhật). Đối chiếu nội dung trước khi gửi.',
                        type: AppMessageType.info,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.medium),
                    AppTextField(
                      label: 'Nội dung comment',
                      controller: draft,
                      maxLines: null,
                      maxLength: 30000,
                      enabled: !model.postingComment && posted == null,
                      helperText: 'Bạn có thể chỉnh sửa bản phân tích trước khi gửi lên PR.',
                    ),
                    if (model.commentError.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.medium),
                      AppMessage(message: model.commentError),
                    ],
                    if (posted != null) ...[
                      const SizedBox(height: AppSpacing.medium),
                      const AppMessage(
                        message: 'Đã có comment phân tích cho lần thực thi này. App không gửi thêm bản trùng.',
                        type: AppMessageType.success,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SafeArea(
                minimum: const EdgeInsets.all(AppSpacing.medium),
                child: AppButton(
                  label: posted != null
                      ? 'Mở comment trên GitHub'
                      : uncertain
                      ? 'Kiểm tra comment đã gửi'
                      : 'Gửi comment',
                  isLoading: model.postingComment,
                  loadingLabel: uncertain
                      ? 'Đang kiểm tra…'
                      : 'Đang gửi comment…',
                  onPressed: posted != null
                      ? () => _open(posted.url)
                      : pull == null ||
                            model.loadingPullRequests ||
                            model.analysis == null
                      ? null
                      : () => model.postComment(draft.text),
                  icon: posted != null
                      ? Icons.open_in_new
                      : Icons.send_outlined,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
