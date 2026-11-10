import 'package:flutter/material.dart';

import '../../core/telemetry/app_telemetry.dart';
import '../../data/models/ci_report.dart';
import '../../data/repositories/ci_report_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_message.dart';
import '../widgets/app_stack_header.dart';
import 'ci_report_view_model.dart';

class CiReportView extends StatefulWidget {
  const CiReportView({
    super.key,
    required this.report,
    this.repository,
    this.telemetry,
  });
  final CiReportSnapshot report;
  final CiReportRepository? repository;
  final AppTelemetry? telemetry;
  @override
  State<CiReportView> createState() => _CiReportViewState();
}

class _CiReportViewState extends State<CiReportView> {
  late final CiReportViewModel model;
  @override
  void initState() {
    super.initState();
    model = CiReportViewModel(
      widget.repository ?? CiReportRepository(),
      widget.report,
      telemetry: widget.telemetry,
    );
    model.generate();
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
      final pdf = model.file;
      return Scaffold(
        appBar: const AppStackHeader(title: 'Báo cáo CI'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text(
                widget.report.repo.fullName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                '${widget.report.run.workflowName} #${widget.report.run.number} · attempt ${widget.report.run.attempt}',
              ),
              const SizedBox(height: AppSpacing.page),
              const Text(
                'PDF gồm thông tin run/commit, tóm tắt, nguyên nhân, hướng xử lý và bằng chứng từ phân tích hiện có. Không gọi Gemini lại.',
              ),
              const SizedBox(height: AppSpacing.page),
              if (model.state.isLoading && pdf == null)
                const AppLoading(label: 'Đang tạo báo cáo PDF…'),
              if (model.state.hasError) ...[
                AppMessage(message: model.state.message),
                const SizedBox(height: AppSpacing.medium),
                if (pdf == null && model.available)
                  AppButton(label: 'Tạo lại PDF', onPressed: model.generate),
              ],
              if (pdf != null) ...[
                Text(
                  pdf.filename,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  '${(pdf.bytes.length / 1024).toStringAsFixed(1)} KiB · PDF',
                ),
                const SizedBox(height: AppSpacing.page),
                AppButton(
                  label: 'Lưu / chia sẻ PDF',
                  icon: Icons.save_alt,
                  isLoading: model.sharing,
                  onPressed: model.busy ? null : model.share,
                ),
                const SizedBox(height: AppSpacing.medium),
                const Text(
                  'Upload tạo liên kết PDF công khai. Chỉ tải lên nội dung bạn muốn chia sẻ.',
                ),
                const SizedBox(height: AppSpacing.small),
                AppButton(
                  label: model.downloadUrl != null
                      ? 'Đã lưu lên đám mây'
                      : 'Upload lên Cloudinary',
                  icon: Icons.cloud_upload_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: model.busy || model.downloadUrl != null
                      ? null
                      : model.upload,
                ),
                if (model.uploading) ...[
                  const SizedBox(height: AppSpacing.medium),
                  LinearProgressIndicator(
                    value: model.progress,
                    semanticsLabel: 'Tiến trình tải báo cáo',
                    semanticsValue: '${(model.progress * 100).round()}%',
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    model.uploaded
                        ? 'Đang lấy liên kết tải…'
                        : 'Đang tải lên ${(model.progress * 100).round()}%',
                  ),
                  AppButton(
                    label: 'Hủy upload',
                    onPressed: model.cancelUpload,
                    variant: AppButtonVariant.text,
                  ),
                ],
                if (model.downloadUrl != null) ...[
                  const SizedBox(height: AppSpacing.medium),
                  AppButton(
                    label: 'Mở bản trên đám mây',
                    icon: Icons.open_in_new,
                    isLoading: model.opening,
                    onPressed: model.busy ? null : model.openUploaded,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  const Text('Ai có liên kết đều có thể tải báo cáo.'),
                ],
              ],
              if (model.message.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.medium),
                AppMessage(message: model.message, type: AppMessageType.info),
              ],
              const SizedBox(height: AppSpacing.page),
              const Text(
                'Nội dung do AI đề xuất, cần kiểm chứng. Báo cáo thuộc đúng attempt tại thời điểm xuất.',
              ),
            ],
          ),
        ),
      );
    },
  );
}
