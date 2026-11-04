import '../models/ci_report.dart';
import '../services/ci_report_pdf_service.dart';
import '../services/cloudinary_report_storage_service.dart';
import '../services/report_sharing_service.dart';

class CiReportRepository {
  CiReportRepository({
    ReportPdfGenerator? pdf,
    ReportStorage? storage,
    ReportSharing? sharing,
  }) : pdf = pdf ?? CiReportPdfService(),
       storage = storage ?? CloudinaryReportStorageService(),
       sharing = sharing ?? ReportSharingService();
  final ReportPdfGenerator pdf;
  final ReportStorage storage;
  final ReportSharing sharing;
  void requireOwner(String uid) {
    if (storage.currentUid != uid) {
      throw const CiReportException('Phiên đã thay đổi. Hãy mở lại báo cáo.');
    }
  }

  Future<CiReportFile> generate(CiReportSnapshot report) async {
    requireOwner(report.ownerUid);
    final bytes = await pdf.generate(report);
    requireOwner(report.ownerUid);
    if (bytes.length < 5 ||
        String.fromCharCodes(bytes.take(5)) != '%PDF-' ||
        bytes.length > CiReportFile.maxBytes) {
      throw const CiReportException(
        'Chưa tạo được PDF hợp lệ hoặc báo cáo vượt quá 5 MiB.',
      );
    }
    return CiReportFile(filename: report.filename, bytes: bytes);
  }
}
