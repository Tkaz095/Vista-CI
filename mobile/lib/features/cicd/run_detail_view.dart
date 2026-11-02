import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/session_views.dart';
import '../github/github_repository.dart';
import 'cicd_view_model.dart';
import 'run_detail_view_model.dart';

class RunDetailView extends StatefulWidget {
  const RunDetailView({super.key, required this.run, required this.onClose});
  final WorkflowRun run;
  final VoidCallback onClose;
  @override
  State<RunDetailView> createState() => _RunDetailViewState();
}

class _RunDetailViewState extends State<RunDetailView> {
  late final model = RunDetailViewModel(widget.run);
  @override
  void initState() {
    super.initState();
    unawaited(model.load(reset: true));
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final run = widget.run, job = model.job;
      return ScrollPage(
        children: [
          OutlinedButton.icon(
            onPressed: widget.onClose,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Lịch sử chạy'),
          ),
          Text(run.title, style: Theme.of(context).textTheme.headlineSmall),
          Text(
            '${run.repo}\n${run.workflow} · Lần thử ${run.attempt}\n${run.branch} · ${run.sha.length > 7 ? run.sha.substring(0, 7) : run.sha}',
          ),
          TextButton(
            onPressed: () async {
              try {
                if (!await launchUrl(
                  Uri.https(
                    'github.com',
                    '/${run.repo}/actions/runs/${run.id}/attempts/${run.attempt}',
                  ),
                  mode: LaunchMode.externalApplication,
                )) {
                  throw Exception();
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Không mở được GitHub.')),
                  );
                }
              }
            },
            child: const Text('Mở lần chạy trên GitHub ↗'),
          ),
          OutlinedButton.icon(
            onPressed: model.busy ? null : () => model.load(reset: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Cập nhật job'),
          ),
          if (model.busy) const LinearProgressIndicator(),
          if (model.error.isNotEmpty)
            Text(
              model.error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (!model.busy && model.error.isEmpty && model.jobs.isEmpty)
            const Text('GitHub chưa trả job cho lần thử này.'),
          if (model.jobs.isNotEmpty)
            DropdownButtonFormField<int>(
              key: ValueKey('${model.selected}/${model.jobs.length}'),
              initialValue: model.selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Job'),
              items: model.jobs
                  .map(
                    (job) => DropdownMenuItem(
                      value: job.id,
                      child: Text(
                        '${job.name} · ${runLabels[job.conclusion ?? job.status] ?? job.conclusion ?? job.status}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) model.select(value);
              },
            ),
          if (model.more)
            OutlinedButton(
              onPressed: model.busy ? null : () => model.load(),
              child: const Text('Tải thêm job'),
            ),
          if (job != null) ...[
            Text(job.name, style: Theme.of(context).textTheme.titleLarge),
            ...job.steps.map(
              (step) => Card(
                color: failed(step.conclusion) ? const Color(0xfffee2e2) : null,
                child: ListTile(
                  leading: Icon(
                    failed(step.conclusion)
                        ? Icons.cancel_outlined
                        : step.conclusion == 'success'
                        ? Icons.check_circle_outline
                        : Icons.schedule,
                    color: failed(step.conclusion)
                        ? const Color(0xffb91c1c)
                        : null,
                  ),
                  title: Text('${step.number}. ${step.name}'),
                  subtitle: Text(
                    runLabels[step.conclusion ?? step.status] ??
                        step.conclusion ??
                        step.status,
                  ),
                ),
              ),
            ),
            if (failed(job.conclusion))
              const Text(
                'Các step màu đỏ là lỗi GitHub trả về. Chưa có agent phân tích nguyên nhân.',
              ),
            JobLogView(
              key: ValueKey('${job.id}/${job.status}'),
              repo: run.repo,
              job: job,
            ),
          ],
        ],
      );
    },
  );
}

class JobLogView extends StatefulWidget {
  const JobLogView({super.key, required this.repo, required this.job});
  final String repo;
  final WorkflowJob job;
  @override
  State<JobLogView> createState() => _JobLogViewState();
}

class _JobLogViewState extends State<JobLogView> {
  late final model = JobLogViewModel(widget.repo, widget.job.id);
  bool wrap = true, tail = true;
  @override
  void initState() {
    super.initState();
    if (widget.job.status == 'completed') unawaited(model.load());
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final full = model.text;
      const limit = 100000;
      final text = full == null
          ? ''
          : full.length <= limit
          ? full
          : tail
          ? full.substring(full.length - limit)
          : full.substring(0, limit);
      final errors =
          full
              ?.split('\n')
              .where((line) => line.contains('##[error]'))
              .take(12)
              .join('\n') ??
          '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Log gốc', style: Theme.of(context).textTheme.titleLarge),
          OutlinedButton.icon(
            onPressed: model.busy || widget.job.status != 'completed'
                ? null
                : model.load,
            icon: const Icon(Icons.refresh),
            label: const Text('Tải lại log'),
          ),
          if (widget.job.status != 'completed')
            const Text(
              'Log đầy đủ có sau khi job hoàn tất. Bấm Cập nhật job để cập nhật.',
            ),
          if (model.busy) const LinearProgressIndicator(),
          if (model.error.isNotEmpty)
            Text(
              model.error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (errors.isNotEmpty)
            Card(
              color: const Color(0xfffee2e2),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Dòng GitHub đánh dấu lỗi — không phải phân tích AI',
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      errors,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (model.truncated)
            const Text(
              'Log lớn: backend chỉ trả 2 MiB đầu. Mở GitHub để xem toàn bộ; phần cuối có thể chưa được tải.',
            ),
          if (full != null) ...[
            if (full.length > limit)
              Text(
                'Đã tải ${full.length} ký tự; hiển thị tối đa $limit ký tự ${tail ? 'cuối' : 'đầu'} của phần đã tải.',
              ),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: () => setState(() => wrap = !wrap),
                  child: Text(wrap ? 'Tắt xuống dòng' : 'Tự xuống dòng'),
                ),
                if (full.length > limit)
                  TextButton(
                    onPressed: () => setState(() => tail = !tail),
                    child: Text(
                      tail ? 'Xem đầu phần đã tải' : 'Xem cuối phần đã tải',
                    ),
                  ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xfff1f5f9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: text.isEmpty
                  ? const Text('GitHub trả log rỗng.')
                  : wrap
                  ? SelectableText(
                      text,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.6,
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectableText(
                        text,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ),
            ),
          ],
        ],
      );
    },
  );
}
