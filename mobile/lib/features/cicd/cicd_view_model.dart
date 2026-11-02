import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../github/github_repository.dart';

const runLabels = <String, String>{
  'queued': 'Đang chờ',
  'in_progress': 'Đang chạy',
  'completed': 'Đã hoàn thành',
  'success': 'Thành công',
  'failure': 'Thất bại',
  'cancelled': 'Đã hủy',
  'timed_out': 'Hết thời gian',
  'skipped': 'Bỏ qua',
  'neutral': 'Trung lập',
  'action_required': 'Cần xử lý',
  'waiting': 'Chờ phê duyệt',
  'pending': 'Đang chờ',
  'requested': 'Đã yêu cầu',
};

class RunPage {
  RunPage({
    this.runs = const [],
    this.next = 1,
    this.more = true,
    this.error = '',
  });
  final List<WorkflowRun> runs;
  final int next;
  final bool more;
  final String error;
}

class CicdViewModel extends ChangeNotifier {
  final Map<String, RunPage> pages = {};
  List<String> repos = [];
  String branch = '', status = '';
  bool busy = false, _disposed = false;
  DateTime? updated;
  int _generation = 0;
  String _configuration = '';
  List<WorkflowRun> get runs =>
      pages.values.expand((page) => page.runs).toList()
        ..sort((a, b) => b.created.compareTo(a.created));
  bool get more => repos.any(
    (repo) =>
        pages[repo] == null ||
        pages[repo]!.more ||
        pages[repo]!.error.isNotEmpty,
  );
  void configure(
    List<String> repositories,
    String selectedBranch,
    String selectedStatus,
  ) {
    final next = jsonEncode([repositories, selectedBranch, selectedStatus]);
    if (next == _configuration) return;
    _configuration = next;
    _generation++;
    repos = List.of(repositories);
    branch = selectedBranch;
    status = selectedStatus;
    pages.clear();
    updated = null;
    busy = false;
    if (repos.isNotEmpty) unawaited(load(reset: true));
  }

  Future<void> load({bool reset = false}) async {
    if (busy || _disposed) return;
    final generation = _generation,
        selectedBranch = branch,
        selectedStatus = status;
    final targets = repos
        .where(
          (repo) =>
              reset ||
              pages[repo] == null ||
              pages[repo]!.more ||
              pages[repo]!.error.isNotEmpty,
        )
        .toList();
    busy = true;
    notifyListeners();
    var cursor = 0;
    Future<void> worker() async {
      while (cursor < targets.length &&
          !_disposed &&
          generation == _generation) {
        final repo = targets[cursor++];
        final old = pages[repo];
        final page = reset ? 1 : old?.next ?? 1;
        try {
          final result = await GitHubRepository.instance.runs(
            repo,
            page,
            selectedBranch,
            selectedStatus,
          );
          if (_disposed || generation != _generation) return;
          final merged = <int, WorkflowRun>{
            for (final run
                in reset ? <WorkflowRun>[] : old?.runs ?? <WorkflowRun>[])
              run.id: run,
            for (final run in result.runs) run.id: run,
          };
          pages[repo] = RunPage(
            runs: merged.values.toList(),
            next: page + 1,
            more: result.more,
          );
        } catch (error) {
          if (_disposed || generation != _generation) return;
          pages[repo] = RunPage(
            runs: old?.runs ?? [],
            next: page,
            more: old?.more ?? true,
            error: error is TimeoutException
                ? 'Hết thời gian chờ GitHub. Thử lại.'
                : error is http.ClientException
                ? 'Không kết nối được GitHub. Kiểm tra mạng.'
                : error is FormatException
                ? 'Dữ liệu CI/CD không hợp lệ.'
                : error.toString().replaceFirst('Exception: ', ''),
          );
        }
        notifyListeners();
      }
    }

    await Future.wait(
      List.generate(targets.length < 3 ? targets.length : 3, (_) => worker()),
    );
    if (_disposed || generation != _generation) return;
    busy = false;
    updated = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
