import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ci_report.dart';
import 'cloudinary_report_storage_service.dart';

class ReportSharingService implements ReportSharing {
  @override
  Future<bool> share(CiReportFile file) =>
      Printing.sharePdf(bytes: file.bytes, filename: file.filename);
  @override
  Future<bool> openUrl(String url) {
    final uri = Uri.parse(url);
    if (!isCloudinaryReportUrl(url)) {
      throw const CiReportException(
        'Liên kết báo cáo không hợp lệ. Hãy lấy lại liên kết.',
      );
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
