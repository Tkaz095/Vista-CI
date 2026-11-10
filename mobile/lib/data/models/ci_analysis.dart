import 'project.dart';
import 'workflow_run.dart';

class CiAnalysisException implements Exception {
  const CiAnalysisException(this.message);
  final String message;

  @override
  String toString() => 'CiAnalysisException: $message';
}

/// Only these redacted, numbered excerpts are sent to the model.
class CiJobLog {
  const CiJobLog({
    required this.jobId,
    required this.name,
    required this.lines,
    required this.incomplete,
  });
  final int jobId;
  final String name;
  final Map<int, String> lines;
  final bool incomplete;

  factory CiJobLog.fromLog(WorkflowJob job, WorkflowLog log) {
    final source = redactCiText(log.text).split('\n');
    final selected = <int>{};
    // Preserve the tail and context around error messages, in source order.
    for (var i = source.length - 1; i >= 0 && selected.length < 40; i--) {
      selected.add(i);
    }
    final error = RegExp(
      r'error|exception|failed|fatal|timed?\s*out',
      caseSensitive: false,
    );
    for (var i = source.length - 1; i >= 0 && selected.length < 80; i--) {
      if (!error.hasMatch(source[i])) continue;
      for (var j = i - 3; j <= i + 3 && selected.length < 80; j++) {
        if (j >= 0 && j < source.length) selected.add(j);
      }
    }
    var remaining = 12000;
    final lines = <int, String>{};
    // Reserve the end of the log first when the character budget is reached.
    for (final index in selected.toList()..sort((a, b) => b.compareTo(a))) {
      final text = source[index];
      final preview = text.length > 300 ? '${text.substring(0, 300)}…' : text;
      if (preview.length > remaining) continue;
      lines[index + 1] = preview;
      remaining -= preview.length;
    }
    return CiJobLog(
      jobId: job.id,
      name: redactCiText(job.name),
      lines: Map.fromEntries(
        lines.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      ),
      incomplete:
          log.truncated ||
          lines.length < source.length ||
          source.any((line) => line.length > 300),
    );
  }

  Map<String, dynamic> toJson() => {
    'jobId': jobId,
    'jobName': name,
    'incomplete': incomplete,
    'lines': [
      for (final entry in lines.entries)
        {'line': entry.key, 'text': entry.value},
    ],
  };
}

/// Best-effort redaction. A preview remains available before anything leaves the app.
String redactCiText(String text) {
  // Masking must not move evidence to a different source line.
  String mask(Match match, String replacement) {
    final removedLines =
        match[0]!.split('\n').length - replacement.split('\n').length;
    return replacement + '\n' * (removedLines > 0 ? removedLines : 0);
  }

  var value = text;
  void replace(RegExp pattern, String replacement) {
    value = value.replaceAllMapped(
      pattern,
      (match) => mask(match, replacement),
    );
  }

  replace(
    RegExp(
      r'-----BEGIN [^-]*PRIVATE KEY-----[\s\S]*?(?:-----END [^-]*PRIVATE KEY-----|$)',
    ),
    '[REDACTED PRIVATE KEY]',
  );
  replace(
    RegExp(r'(?:github_pat_|gh[pousr]_)[A-Za-z0-9_]+'),
    '[REDACTED TOKEN]',
  );
  replace(RegExp(r'AIza[A-Za-z0-9_-]{20,}'), '[REDACTED API KEY]');
  replace(RegExp(r'\bAKIA[A-Z0-9]{16}\b'), '[REDACTED ACCESS KEY]');
  replace(
    RegExp(r'\bBearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
    'Bearer [REDACTED]',
  );
  value = value.replaceAllMapped(
    RegExp(
      r'''((?:authorization|[\w-]*(?:token|password|secret|api[_-]?key)[\w-]*)\s*[=:]\s*)(?:"[^"]*"|'[^']*'|[^\s,;]+)''',
      caseSensitive: false,
    ),
    (match) => mask(match, '${match[1]}[REDACTED]'),
  );
  replace(RegExp(r'(https?://)[^\s/@]+:[^\s/@]+@'), 'https://[REDACTED]@');
  return value;
}

class CiEvidence {
  const CiEvidence({
    required this.jobId,
    required this.line,
    required this.quote,
  });
  final int jobId;
  final int line;
  final String quote;
  Map<String, dynamic> toJson() => {
    'jobId': jobId,
    'line': line,
    'quote': quote,
  };
}

class CiAnalysis {
  const CiAnalysis({
    required this.repoId,
    required this.runId,
    required this.attempt,
    required this.sha,
    required this.summary,
    required this.probableCause,
    required this.suggestions,
    required this.evidence,
    required this.missingContext,
    required this.incomplete,
    required this.model,
    required this.createdAt,
    this.promptVersion = 1,
  });
  final int repoId;
  final int runId;
  final int attempt;
  final String sha;
  final String summary;
  final String probableCause;
  final List<String> suggestions;
  final List<CiEvidence> evidence;
  final List<String> missingContext;
  final bool incomplete;
  final String model;
  final DateTime createdAt;
  final int promptVersion;

  String get documentId => '${repoId}_${runId}_$attempt';
  bool matches(ProjectRepo repo, WorkflowRun run) =>
      repoId == repo.id &&
      runId == run.id &&
      attempt == run.attempt &&
      sha == run.sha;

  factory CiAnalysis.fromJson(Map<String, dynamic> data) {
    String text(String key) {
      final value = data[key];
      if (value is! String || value.trim().isEmpty || value.length > 4000) {
        throw const FormatException('Invalid analysis text');
      }
      return value.trim();
    }

    List<String> strings(String key) {
      final list = data[key];
      if (list is! List ||
          list.length > 10 ||
          list.any((s) => s is! String || s.length > 2000)) {
        throw const FormatException('Invalid analysis list');
      }
      return list.cast<String>();
    }

    final rawEvidence = data['evidence'] as List;
    if (rawEvidence.length > 10) {
      throw const FormatException('Too much evidence');
    }
    final evidence = rawEvidence.map((item) {
      final map = item as Map;
      final quote = map['quote'] as String;
      final line = map['line'] as int;
      final jobId = map['jobId'] as int;
      if (quote.trim().isEmpty || quote.length > 300 || line < 1 || jobId < 1) {
        throw const FormatException('Invalid evidence');
      }
      return CiEvidence(jobId: jobId, line: line, quote: quote);
    }).toList();
    return CiAnalysis(
      repoId: data['repoId'] as int,
      runId: data['runId'] as int,
      attempt: data['attempt'] as int,
      sha: text('sha'),
      summary: text('summary'),
      probableCause: text('probableCause'),
      suggestions: strings('suggestions'),
      evidence: evidence,
      missingContext: strings('missingContext'),
      incomplete: data['incomplete'] as bool,
      model: text('model'),
      createdAt: DateTime.parse(data['createdAt'] as String),
      promptVersion: data['promptVersion'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'repoId': repoId,
    'runId': runId,
    'attempt': attempt,
    'sha': sha,
    'summary': summary,
    'probableCause': probableCause,
    'suggestions': suggestions,
    'evidence': evidence.map((item) => item.toJson()).toList(),
    'missingContext': missingContext,
    'incomplete': incomplete,
    'model': model,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'promptVersion': promptVersion,
  };

  String comment(ProjectRepo repo, WorkflowRun run) {
    // Neutralize accidental mentions from model/log content. User can edit the draft.
    String safe(String value) => value.replaceAll('@', '@\u200b');
    return '''Vista CI — Phân tích lỗi bằng AI

Repository: ${repo.fullName}
Workflow: ${safe(run.workflowName)} #${run.number} — attempt $attempt
Commit: $sha
Nguồn: https://github.com/${repo.fullName}/actions/runs/$runId/attempts/$attempt

Tóm tắt:
${safe(summary)}

Nguyên nhân có khả năng:
${safe(probableCause)}

Bằng chứng:
${evidence.map((item) => '- Job ${item.jobId}, dòng ${item.line}: ${safe(item.quote)}').join('\n')}

Hướng xử lý:
${suggestions.map((item) => '- ${safe(item)}').join('\n')}
${missingContext.isEmpty ? '' : '\nThông tin còn thiếu:\n${missingContext.map((item) => '- ${safe(item)}').join('\n')}\n'}
${incomplete ? 'Phân tích dựa trên trích đoạn log, có thể thiếu ngữ cảnh.\n' : ''}Nội dung do AI đề xuất, cần được kiểm chứng.''';
  }
}

class CiAnalysisInput {
  const CiAnalysisInput({
    required this.repo,
    required this.run,
    required this.logs,
    required this.failedJobCount,
  });
  final ProjectRepo repo;
  final WorkflowRun run;
  final List<CiJobLog> logs;
  final int failedJobCount;
  bool get incomplete =>
      logs.length < failedJobCount || logs.any((log) => log.incomplete);

  Map<String, dynamic> toJson() => {
    'repository': repo.fullName,
    'workflow': redactCiText(run.workflowName),
    'runId': run.id,
    'attempt': run.attempt,
    'sha': run.sha,
    'failedJobCount': failedJobCount,
    'incomplete': incomplete,
    'logs': logs.map((log) => log.toJson()).toList(),
  };
}
