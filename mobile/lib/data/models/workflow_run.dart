enum WorkflowState {
  queued,
  running,
  waiting,
  success,
  failure,
  cancelled,
  skipped,
  timedOut,
  actionRequired,
  neutral,
  unknown;

  static WorkflowState fromGitHub(String status, String? conclusion) {
    if (status == 'in_progress') return running;
    if (status == 'waiting') return waiting;
    if (['queued', 'requested', 'pending'].contains(status)) return queued;
    if (status != 'completed') return unknown;
    return switch (conclusion) {
      'success' => success,
      'failure' => failure,
      'cancelled' => cancelled,
      'skipped' => skipped,
      'timed_out' => timedOut,
      'action_required' => actionRequired,
      'neutral' => neutral,
      _ => unknown,
    };
  }
}

class WorkflowRun {
  const WorkflowRun({
    required this.id,
    required this.workflowName,
    required this.title,
    required this.number,
    required this.attempt,
    required this.status,
    this.conclusion,
    this.branch = '',
    this.sha = '',
    this.event = '',
    this.createdAt,
  });

  final int id;
  final String workflowName;
  final String title;
  final int number;
  final int attempt;
  final String status;
  final String? conclusion;
  final String branch;
  final String sha;
  final String event;
  final DateTime? createdAt;

  factory WorkflowRun.fromJson(Map<String, dynamic> data) {
    final name = data['name'] as String? ?? 'Workflow';
    return WorkflowRun(
      id: data['id'] as int,
      workflowName: name,
      title: data['display_title'] as String? ?? name,
      number: data['run_number'] as int,
      attempt: data['run_attempt'] as int? ?? 1,
      status: data['status'] as String? ?? 'unknown',
      conclusion: data['conclusion'] as String?,
      branch: data['head_branch'] as String? ?? '',
      sha: data['head_sha'] as String? ?? '',
      event: data['event'] as String? ?? '',
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? ''),
    );
  }
}

class WorkflowRunsPage {
  const WorkflowRunsPage({required this.runs, required this.hasMore});
  final List<WorkflowRun> runs;
  final bool hasMore;
}

class WorkflowRunDetails {
  const WorkflowRunDetails({required this.run, required this.jobs});
  final WorkflowRun run;
  final List<WorkflowJob> jobs;
}

class WorkflowJob {
  const WorkflowJob({
    required this.id,
    required this.name,
    required this.status,
    this.conclusion,
    this.startedAt,
    this.completedAt,
    this.steps = const [],
  });

  final int id;
  final String name;
  final String status;
  final String? conclusion;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<WorkflowStep> steps;

  factory WorkflowJob.fromJson(Map<String, dynamic> data) => WorkflowJob(
    id: data['id'] as int,
    name: data['name'] as String,
    status: data['status'] as String? ?? 'unknown',
    conclusion: data['conclusion'] as String?,
    startedAt: DateTime.tryParse(data['started_at'] as String? ?? ''),
    completedAt: DateTime.tryParse(data['completed_at'] as String? ?? ''),
    steps: (data['steps'] as List<dynamic>? ?? [])
        .map((step) => WorkflowStep.fromJson(step as Map<String, dynamic>))
        .toList(),
  );
}

class WorkflowStep {
  const WorkflowStep({
    required this.number,
    required this.name,
    required this.status,
    this.conclusion,
  });
  final int number;
  final String name;
  final String status;
  final String? conclusion;

  factory WorkflowStep.fromJson(Map<String, dynamic> data) => WorkflowStep(
    number: data['number'] as int,
    name: data['name'] as String,
    status: data['status'] as String? ?? 'unknown',
    conclusion: data['conclusion'] as String?,
  );
}

/// A bounded text preview. Commands and HTML in logs are displayed as text only.
class WorkflowLog {
  const WorkflowLog({required this.text, this.truncated = false});
  final String text;
  final bool truncated;

  List<WorkflowLogSection> get sections {
    final result = <WorkflowLogSection>[];
    final names = <String>[];
    var lines = <String>[];
    var startLine = 1;
    void flush() {
      if (lines.isEmpty) return;
      result.add(
        WorkflowLogSection(
          title: names.isEmpty ? null : names.join(' / '),
          text: lines.join('\n'),
          startLine: startLine,
        ),
      );
      lines = [];
    }

    final source = text.split('\n');
    final marker = RegExp(
      r'^(?:\d{4}-\d{2}-\d{2}T\S+\s+)?##\[(group|endgroup)\](.*)$',
    );
    for (var index = 0; index < source.length; index++) {
      final match = marker.firstMatch(source[index]);
      if (match != null && (match[1] == 'group' || names.isNotEmpty)) {
        flush();
        if (match[1] == 'group') {
          names.add(match[2]!.trim());
        } else {
          names.removeLast();
        }
        startLine = index + 2;
      } else {
        if (lines.isEmpty) startLine = index + 1;
        lines.add(source[index]);
      }
    }
    flush();
    return result;
  }

  factory WorkflowLog.fromText(String raw, {bool truncated = false}) {
    final clean = cleanText(raw);
    final lines = clean.split('\n');
    return WorkflowLog(
      text: lines.take(1000).join('\n'),
      truncated: truncated || lines.length > 1000,
    );
  }

  static String cleanText(String raw) => raw
      .replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[\x00-\x08\x0B-\x1F\x7F]'), '');
}

class WorkflowLogSection {
  const WorkflowLogSection({
    required this.title,
    required this.text,
    required this.startLine,
  });
  final String? title;
  final String text;
  final int startLine;
}

class GitHubPullRequest {
  const GitHubPullRequest({
    required this.number,
    required this.title,
    required this.headSha,
  });
  final int number;
  final String title;
  final String headSha;
  factory GitHubPullRequest.fromJson(Map<String, dynamic> data) =>
      GitHubPullRequest(
        number: data['number'] as int,
        title: data['title'] as String,
        headSha: (data['head'] as Map<String, dynamic>)['sha'] as String,
      );
}

class GitHubComment {
  const GitHubComment({required this.id, required this.url});
  final int id;
  final Uri url;
}
