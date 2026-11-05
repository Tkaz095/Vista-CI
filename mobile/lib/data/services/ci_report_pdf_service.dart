import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/ci_analysis.dart';
import '../models/ci_report.dart';

/// Local assets only: PDF export works offline, including Vietnamese diacritics.
class CiReportPdfService implements ReportPdfGenerator {
  CiReportPdfService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;
  @override
  Future<Uint8List> generate(CiReportSnapshot report) async {
    final regular = pw.Font.ttf(
      await _bundle.load('assets/fonts/inter/Inter-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await _bundle.load('assets/fonts/inter/Inter-Bold.ttf'),
    );
    final doc = pw.Document(
      title: 'Vista CI — Báo cáo phân tích',
      author: 'Vista CI',
      creator: 'Vista CI',
    );
    final a = report.analysis;
    final blue = PdfColor.fromHex('#2563EB');
    pw.Widget heading(String label) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: blue,
        ),
      ),
    );
    List<pw.Widget> text(String value) => [
      for (final part in reportTextChunks(value))
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Text(
            part,
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
          ),
        ),
    ];
    doc.addPage(
      pw.MultiPage(
        maxPages: 80,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: blue)),
          ),
          child: pw.Text(
            'VISTA CI  /  BÁO CÁO PHÂN TÍCH',
            style: pw.TextStyle(color: blue, font: bold, fontSize: 12),
          ),
        ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'AI đề xuất · Cần kiểm chứng',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
        build: (_) => [
          heading('Thông tin lần thực thi'),
          ...text(
            'Repository: ${report.repo.fullName}\nWorkflow: ${report.run.workflowName} #${report.run.number}\nRun ID: ${report.run.id} · Attempt: ${report.run.attempt}\nCommit: ${report.run.sha}\nTrạng thái: ${report.run.status} / ${report.run.conclusion ?? "chưa có kết quả"}',
          ),
          ...text(
            'Phân tích lúc: ${a.createdAt.toUtc().toIso8601String()}\nXuất lúc: ${report.exportedAt.toUtc().toIso8601String()}',
          ),
          pw.UrlLink(
            destination: report.sourceUrl,
            child: pw.Text(
              'Mở đúng run/attempt trên GitHub',
              style: pw.TextStyle(color: blue, fontSize: 10),
            ),
          ),
          ...text(report.sourceUrl),
          heading('Tóm tắt lỗi'),
          ...text(a.summary),
          heading('Nguyên nhân có khả năng'),
          ...text(a.probableCause),
          heading('Hướng xử lý'),
          if (a.suggestions.isEmpty)
            ...text('Chưa có đề xuất.')
          else
            for (var i = 0; i < a.suggestions.length; i++)
              ...text('${i + 1}. ${a.suggestions[i]}'),
          heading('Bằng chứng từ log'),
          if (a.evidence.isEmpty)
            ...text('Chưa có bằng chứng được trích dẫn.')
          else
            for (final item in a.evidence) ...[
              ...text('Job ${item.jobId} · dòng ${item.line}'),
              ...text(item.quote),
            ],
          heading('Thông tin cần kiểm tra thêm'),
          if (a.missingContext.isEmpty)
            ...text('Không có thông tin bổ sung được liệt kê.')
          else
            for (final item in a.missingContext) ...text('- $item'),
          heading('Phạm vi và nguồn phân tích'),
          ...text(
            'Model: ${a.model}\nPrompt version: ${a.promptVersion}\n${a.incomplete ? "Phân tích dựa trên trích đoạn log, có thể thiếu ngữ cảnh." : "Báo cáo phản ánh dữ liệu phân tích đã có tại thời điểm xuất."}\nNội dung do AI đề xuất, cần kiểm chứng. Báo cáo không chứng minh CI đã được sửa hoặc chạy thành công.',
          ),
        ],
      ),
    );
    return doc.save();
  }
}

/// Small paragraphs and bounded tokens keep long logs/model output paginatable.
List<String> reportTextChunks(String source) {
  final value = redactCiText(source)
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  final wrapped = value.replaceAllMapped(RegExp(r'\S{70,}'), (match) {
    final runes = match[0]!.runes.toList();
    return [
      for (var i = 0; i < runes.length; i += 60)
        String.fromCharCodes(runes.skip(i).take(60)),
    ].join('\n');
  });
  final chunks = <String>[];
  for (final line in wrapped.split('\n')) {
    var buffer = '';
    for (final word in line.split(RegExp(r'(?<=\s)'))) {
      if (buffer.length + word.length > 600 && buffer.isNotEmpty) {
        chunks.add(buffer.trim());
        buffer = '';
      }
      buffer += word;
    }
    if (buffer.trim().isNotEmpty) chunks.add(buffer.trim());
  }
  return chunks;
}
