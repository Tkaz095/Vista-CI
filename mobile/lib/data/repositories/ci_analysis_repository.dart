import '../models/ci_analysis.dart';
import '../models/project.dart';
import '../models/workflow_run.dart';
import '../services/firestore_ci_analysis_service.dart';
import '../services/gemini_analysis_service.dart';
import 'github_actions_repository.dart';

class CiAnalysisRepository {
  CiAnalysisRepository(this._github);
  final GitHubActionsRepository _github;
  final GeminiAnalysisService _gemini = GeminiAnalysisService();
  final FirestoreCiAnalysisService _store = FirestoreCiAnalysisService();

  Future<CiAnalysis?> readSaved(ProjectRepo repo, WorkflowRun run) async {
    final data = await _store.read('${repo.id}_${run.id}_${run.attempt}');
    if (data == null) return null;
    try {
      final analysis = CiAnalysis.fromJson(data);
      return analysis.matches(repo, run) ? analysis : null;
    } on FormatException {
      throw const CiAnalysisException(
        'Bản phân tích đã lưu không hợp lệ. Có thể phân tích lại.',
      );
    } on TypeError {
      throw const CiAnalysisException(
        'Bản phân tích đã lưu không hợp lệ. Có thể phân tích lại.',
      );
    }
  }

  Future<CiAnalysisInput> prepare(
    String? token,
    ProjectRepo repo,
    WorkflowRun run,
  ) async {
    final details = await _github.getRunDetails(token, repo, run);
    if (details.run.status != 'completed' || details.run.sha.isEmpty) {
      throw const CiAnalysisException('Chờ CI hoàn tất rồi phân tích lỗi.');
    }
    final failed = details.jobs
        .where(
          (job) => job.conclusion == 'failure' || job.conclusion == 'timed_out',
        )
        .toList();
    if (failed.isEmpty) {
      throw const CiAnalysisException('Không có job lỗi để phân tích.');
    }
    final logs = <CiJobLog>[];
    // Keep token usage predictable. Tell both the user and model about omitted jobs.
    for (final job in failed.take(5)) {
      final log = await _github.getAnalysisLog(token, repo, job.id);
      logs.add(CiJobLog.fromLog(job, log));
    }
    if (logs.every(
      (log) => log.lines.values.every((line) => line.trim().isEmpty),
    )) {
      throw const CiAnalysisException(
        'Log đang trống. Kéo xuống cập nhật rồi thử lại.',
      );
    }
    return CiAnalysisInput(
      repo: repo,
      run: details.run,
      logs: logs,
      failedJobCount: failed.length,
    );
  }

  Future<CiAnalysis> analyze(CiAnalysisInput input) async {
    final output = await _gemini.analyze(input);
    return validateOutput(input, output);
  }

  /// Metadata is assigned by the app, never taken from model output.
  static CiAnalysis validateOutput(
    CiAnalysisInput input,
    Map<String, dynamic> output,
  ) {
    try {
      final analysis = CiAnalysis.fromJson({
        ...output,
        'repoId': input.repo.id,
        'runId': input.run.id,
        'attempt': input.run.attempt,
        'sha': input.run.sha,
        'incomplete': input.incomplete,
        'model': GeminiAnalysisService.modelName,
        'promptVersion': GeminiAnalysisService.promptVersion,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      if (analysis.evidence.isEmpty && analysis.missingContext.isEmpty) {
        throw const CiAnalysisException(
          'Phân tích chưa có bằng chứng hoặc thông tin cần kiểm tra. Hãy thử lại.',
        );
      }
      final jobs = {for (final log in input.logs) log.jobId: log};
      for (final evidence in analysis.evidence) {
        final line = jobs[evidence.jobId]?.lines[evidence.line];
        if (line == null || !line.contains(evidence.quote)) {
          throw const CiAnalysisException(
            'AI trích dẫn dòng log không khớp. Chưa sử dụng kết quả này; hãy phân tích lại.',
          );
        }
      }
      return analysis;
    } on FormatException {
      throw const CiAnalysisException(
        'Kết quả phân tích chưa hợp lệ. Hãy thử lại.',
      );
    } on TypeError {
      throw const CiAnalysisException(
        'Kết quả phân tích chưa hợp lệ. Hãy thử lại.',
      );
    }
  }

  Future<void> save(CiAnalysis analysis) => _store.save(analysis);
}
