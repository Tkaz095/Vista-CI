import 'dart:typed_data';

import 'ci_analysis.dart';
import 'project.dart';
import 'workflow_run.dart';

class CiReportException implements Exception {
  const CiReportException(this.message);
  final String message;
}

/// A frozen run/analysis snapshot; never follows a later rerun or a different UID.
class CiReportSnapshot {
  CiReportSnapshot({
    required this.ownerUid,
    required this.repo,
    required this.run,
    required CiAnalysis analysis,
    required this.exportedAt,
  }) : analysis = CiAnalysis.fromJson({
         ...analysis.toJson(),
         'suggestions': List<String>.of(analysis.suggestions),
         'missingContext': List<String>.of(analysis.missingContext),
       }) {
    if (ownerUid.isEmpty ||
        ownerUid.contains('/') ||
        !analysis.matches(repo, run) ||
        repo.id < 1 ||
        run.id < 1 ||
        run.attempt < 1) {
      throw const CiReportException(
        'Phân tích không khớp với lần thực thi cần xuất. Hãy mở lại run.',
      );
    }
  }
  final String ownerUid;
  final ProjectRepo repo;
  final WorkflowRun run;
  final CiAnalysis analysis;
  final DateTime exportedAt;
  String get filename =>
      'ci_${repo.id}_${run.id}_${run.attempt}_${exportedAt.microsecondsSinceEpoch}.pdf';
  String get sourceUrl =>
      'https://github.com/${repo.fullName}/actions/runs/${run.id}/attempts/${run.attempt}';
}

class CiReportFile {
  CiReportFile({required this.filename, required Uint8List bytes})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final String filename;
  final Uint8List bytes;
  static const maxBytes = 5 * 1024 * 1024;
}

abstract interface class ReportPdfGenerator {
  Future<Uint8List> generate(CiReportSnapshot report);
}

abstract interface class ReportSharing {
  Future<bool> share(CiReportFile file);
  Future<bool> openUrl(String url);
}

abstract interface class ReportUpload {
  Stream<double> get progress;
  Future<String> get done;
  Future<void> cancel();
}

abstract interface class ReportStorage {
  String? get currentUid;
  Stream<String?> get sessions;
  ReportUpload upload(String ownerUid, CiReportFile file);
}
