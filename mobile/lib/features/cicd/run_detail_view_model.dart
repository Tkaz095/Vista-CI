import 'package:flutter/foundation.dart';

import '../github/github_repository.dart';

bool failed(String? value) => value == 'failure' || value == 'timed_out';

class RunDetailViewModel extends ChangeNotifier {
  RunDetailViewModel(this.run);
  final WorkflowRun run;
  List<WorkflowJob> jobs = [];
  int? selected;
  int _page = 0;
  bool busy = false, more = false, _disposed = false;
  String error = '';
  WorkflowJob? get job {
    for (final item in jobs) {
      if (item.id == selected) return item;
    }
    return null;
  }

  void select(int value) {
    selected = value;
    notifyListeners();
  }

  Future<void> load({bool reset = false}) async {
    if (busy || _disposed) return;
    busy = true;
    error = '';
    notifyListeners();
    try {
      final page = reset ? 1 : _page + 1;
      final result = await GitHubRepository.instance.jobs(run, page);
      if (_disposed) return;
      jobs = {
        for (final item in [
          ...(reset ? <WorkflowJob>[] : jobs),
          ...result.jobs,
        ])
          item.id: item,
      }.values.toList();
      _page = page;
      more = result.more;
      if (reset || selected == null) {
        selected = null;
        for (final item in jobs) {
          if (failed(item.conclusion)) {
            selected = item.id;
            break;
          }
        }
        selected ??= jobs.isEmpty ? null : jobs.first.id;
      }
    } catch (cause) {
      if (!_disposed) error = cause.toString().replaceFirst('Exception: ', '');
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class JobLogViewModel extends ChangeNotifier {
  JobLogViewModel(this.repo, this.id);
  final String repo;
  final int id;
  String? text;
  String error = '';
  bool busy = false, truncated = false, _disposed = false;
  Future<void> load() async {
    if (busy || _disposed) return;
    busy = true;
    error = '';
    text = null;
    notifyListeners();
    try {
      final result = await GitHubRepository.instance.log(repo, id);
      if (_disposed) return;
      text = result.text;
      truncated = result.truncated;
    } catch (cause) {
      if (!_disposed) error = cause.toString().replaceFirst('Exception: ', '');
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
