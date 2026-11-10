import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vista_mobile/cloudinary_options.dart';
import 'package:vista_mobile/core/state/async_state.dart';
import 'package:vista_mobile/core/telemetry/app_telemetry.dart';
import 'package:vista_mobile/data/models/ci_report.dart';
import 'package:vista_mobile/data/models/feature_config.dart';
import 'package:vista_mobile/data/models/workflow_run.dart';
import 'package:vista_mobile/data/repositories/ci_analysis_repository.dart';
import 'package:vista_mobile/data/repositories/ci_report_repository.dart';
import 'package:vista_mobile/data/services/ci_report_pdf_service.dart';
import 'package:vista_mobile/data/services/cloudinary_report_storage_service.dart';
import 'package:vista_mobile/ui/projects/ci_analysis_view.dart';
import 'package:vista_mobile/ui/projects/workflow_run_view_model.dart';
import 'package:vista_mobile/ui/reports/ci_report_view.dart';
import 'package:vista_mobile/ui/reports/ci_report_view_model.dart';

import 'ci_analysis_test.dart' show inputFor, validOutput, FakeCiRepository;
import 'github_actions_test.dart' show runJson, FakeActionsRepository;
import 'projects_test.dart' show savedRepo;
import 'telemetry_config_test.dart' show RecordingTelemetry;

class RealHttpOverrides extends HttpOverrides {}

http.Client realHttpClient() => HttpOverrides.runWithHttpOverrides(
  () => IOClient(HttpClient()),
  RealHttpOverrides(),
);

const reportUrl = 'https://res.cloudinary.com/demo/raw/upload/v1/test.pdf';
CiReportSnapshot fixture() {
  final run = WorkflowRun.fromJson(runJson(10));
  return CiReportSnapshot(
    ownerUid: 'user-a',
    repo: savedRepo,
    run: run,
    analysis: CiAnalysisRepository.validateOutput(inputFor(run), validOutput()),
    exportedAt: DateTime.utc(2026, 11, 5),
  );
}

class FakePdf implements ReportPdfGenerator {
  int calls = 0;
  Completer<Uint8List>? gate;
  @override
  Future<Uint8List> generate(CiReportSnapshot report) async {
    calls++;
    return gate == null
        ? Uint8List.fromList(utf8.encode('%PDF-1.7\n%%EOF'))
        : gate!.future;
  }
}

class FakeUpload implements ReportUpload {
  final events = StreamController<double>.broadcast();
  final completion = Completer<String>();
  int cancellations = 0;
  @override
  Stream<double> get progress => events.stream;
  @override
  Future<String> get done => completion.future;
  @override
  Future<void> cancel() async {
    cancellations++;
    if (!completion.isCompleted) {
      completion.completeError(const CiReportException('Đã hủy upload.'));
    }
  }
}

class FakeStorage implements ReportStorage {
  String? uid = 'user-a';
  final changes = StreamController<String?>.broadcast();
  final tasks = <FakeUpload>[];
  final names = <String>[];
  @override
  String? get currentUid => uid;
  @override
  Stream<String?> get sessions async* {
    yield uid;
    yield* changes.stream;
  }

  @override
  ReportUpload upload(String ownerUid, CiReportFile file) {
    names.add(file.filename);
    final task = FakeUpload();
    tasks.add(task);
    return task;
  }

  void emit(String? value) {
    uid = value;
    changes.add(value);
  }
}

class FakeSharing implements ReportSharing {
  int shares = 0;
  String? opened;
  @override
  Future<bool> share(CiReportFile file) async {
    shares++;
    return true;
  }

  @override
  Future<bool> openUrl(String url) async {
    opened = url;
    return true;
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Snapshot rejects an analysis belonging to another attempt', () {
    final original = fixture();
    final wrongRun = WorkflowRun.fromJson(runJson(10, attempt: 3));
    expect(
      () => CiReportSnapshot(
        ownerUid: 'user-a',
        repo: savedRepo,
        run: wrongRun,
        analysis: original.analysis,
        exportedAt: DateTime.now(),
      ),
      throwsA(isA<CiReportException>()),
    );
  });
  test('Report text redacts credentials and splits long lines safely', () {
    final text = reportTextChunks(
      'Mật khẩu: password=private\nBearer test_secret\n${'x' * 2000}\n${'Lỗi kết nối\n' * 500}',
    ).join('\n');
    expect(text, isNot(contains('private')));
    expect(text, isNot(contains('test_secret')));
    expect(text, contains('Lỗi kết nối'));
    expect(reportTextChunks('x' * 2000).every((s) => s.length <= 600), isTrue);
    expect(
      reportTextChunks('a\n' * 2000).every((s) => !s.contains('\n')),
      isTrue,
    );
  });
  test(
    'Real PDF is generated offline with embedded Vietnamese fonts',
    () async {
      final bytes = await CiReportPdfService().generate(fixture());
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
      expect(bytes.length, lessThan(CiReportFile.maxBytes));
      final out = File('build/test-reports/ci_report_vi.pdf');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes);
    },
  );
  test('Generate once, retain PDF after upload failure, retry and open the returned URL', () async {
    final pdf = FakePdf();
    final storage = FakeStorage();
    final sharing = FakeSharing();
    final telemetry = RecordingTelemetry();
    final model = CiReportViewModel(
      CiReportRepository(pdf: pdf, storage: storage, sharing: sharing),
      fixture(),
      telemetry: telemetry,
    );
    addTearDown(model.dispose);
    await model.generate();
    await model.generate();
    expect(pdf.calls, 1);
    final file = model.file;
    final first = model.upload();
    storage.tasks.first.events.add(.4);
    await flush();
    expect(model.progress, .4);
    await model.upload();
    expect(storage.tasks.length, 1);
    storage.tasks.first.completion.completeError(
      const CiReportException('Mất mạng'),
    );
    await first;
    expect(model.state.hasError, isTrue);
    expect(model.file, same(file));
    await model.share();
    expect(sharing.shares, 1);
    final retry = model.upload();
    storage.tasks.last.completion.complete(reportUrl);
    await retry;
    expect(model.downloadUrl, reportUrl);
    expect(model.state.status, LoadStatus.success);
    expect(pdf.calls, 1);
    expect(storage.names.toSet().length, 1);
    await model.openUploaded();
    expect(sharing.opened, reportUrl);
    expect(telemetry.events, [AppEvent.reportExport, AppEvent.reportUpload]);
    await model.upload();
    expect(storage.tasks.length, 2);
  });
  test(
    'Cancel aborts the task and a late result cannot publish success',
    () async {
      final storage = FakeStorage();
      final model = CiReportViewModel(
        CiReportRepository(
          pdf: FakePdf(),
          storage: storage,
          sharing: FakeSharing(),
        ),
        fixture(),
      );
      addTearDown(model.dispose);
      await model.generate();
      final uploading = model.upload();
      await model.cancelUpload();
      await uploading;
      expect(storage.tasks.single.cancellations, 1);
      expect(model.downloadUrl, isNull);
      expect(model.uploading, isFalse);
      expect(model.file, isNotNull);
    },
  );
  test(
    'Account switch cancels upload and removes local report access',
    () async {
      final storage = FakeStorage();
      final sharing = FakeSharing();
      final model = CiReportViewModel(
        CiReportRepository(pdf: FakePdf(), storage: storage, sharing: sharing),
        fixture(),
      );
      addTearDown(model.dispose);
      await model.generate();
      await flush();
      final pending = model.upload();
      storage.emit('user-b');
      await flush();
      await pending;
      expect(model.available, isFalse);
      expect(model.file, isNull);
      expect(model.downloadUrl, isNull);
      await model.share();
      expect(sharing.shares, 0);
      expect(storage.tasks.single.cancellations, 1);
    },
  );
  test(
    'Disposal while generating ignores the result and never starts upload',
    () async {
      final pdf = FakePdf()..gate = Completer<Uint8List>();
      final storage = FakeStorage();
      final model = CiReportViewModel(
        CiReportRepository(pdf: pdf, storage: storage, sharing: FakeSharing()),
        fixture(),
      );
      final pending = model.generate();
      model.dispose();
      pdf.gate!.complete(Uint8List.fromList(utf8.encode('%PDF-1.7')));
      await pending;
      expect(model.file, isNull);
      expect(storage.tasks, isEmpty);
    },
  );
  test('Upload timeout cancels the request and preserves the PDF', () async {
    final storage = FakeStorage();
    final model = CiReportViewModel(
      CiReportRepository(
        pdf: FakePdf(),
        storage: storage,
        sharing: FakeSharing(),
      ),
      fixture(),
      uploadTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(model.dispose);
    await model.generate();
    await model.upload();
    expect(model.state.hasError, isTrue);
    expect(model.file, isNotNull);
    expect(storage.tasks.single.cancellations, 1);
  });
  test('Runtime Remote Config supplies public Cloudinary settings without changing the APK', () {
    final config = FeatureConfig.fromStrings({
      'cloudinary_cloud_name': 'demo',
      'cloudinary_upload_preset': 'report-preset',
    });
    final options = CloudinaryOptions(
      cloudName: config.cloudinaryCloudName,
      uploadPreset: config.cloudinaryUploadPreset,
    );
    expect(options.configured, isTrue);
    expect(
      options.uploadUrl.toString(),
      'https://api.cloudinary.com/v1_1/demo/raw/upload',
    );
    expect(
      const CloudinaryOptions(cloudName: 'demo', uploadPreset: '').configured,
      isFalse,
    );
  });
  test('Actual HTTP serializes PDF multipart, excludes secrets and uses runtime options', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final captured = Completer<String>();
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/v1_1/demo/raw/upload');
      expect(request.headers.value('authorization'), isNull);
      expect(request.headers.contentType!.mimeType, 'multipart/form-data');
      captured.complete(
        utf8.decode(
          await request.fold<List<int>>([], (all, chunk) => all..addAll(chunk)),
        ),
      );
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'secure_url': reportUrl}));
      await request.response.close();
    });
    var options = const CloudinaryOptions(cloudName: '', uploadPreset: '');
    final storage = CloudinaryReportStorageService(
      clientFactory: realHttpClient,
      optionsProvider: () => options,
      currentUid: () => 'user-a',
      sessions: Stream.value('user-a'),
      endpoint: Uri.parse(
        'http://127.0.0.1:${server.port}/v1_1/demo/raw/upload',
      ),
    );
    final file = CiReportFile(
      filename: fixture().filename,
      bytes: Uint8List.fromList(utf8.encode('%PDF-1.7')),
    );
    expect(
      () => storage.upload('user-a', file),
      throwsA(isA<CiReportException>()),
    );
    options = const CloudinaryOptions(
      cloudName: 'demo',
      uploadPreset: 'unsigned-test',
    );
    final task = storage.upload('user-a', file);
    final progress = <double>[];
    final sub = task.progress.listen(progress.add);
    expect(await task.done, reportUrl);
    final body = await captured.future;
    expect(body, contains('name="upload_preset"'));
    expect(body, contains('unsigned-test'));
    expect(body, contains('name="file"; filename="${file.filename}"'));
    expect(body.toLowerCase(), contains('content-type: application/pdf'));
    expect(body, contains('%PDF-1.7'));
    expect(body, isNot(contains('api_secret')));
    expect(body, isNot(contains('Bearer')));
    await flush();
    expect(progress.last, 1);
    await sub.cancel();
  });
  for (final response in [400, 429, 500, 'invalid-json', 'wrong-url']) {
    test(
      'Actual HTTP handles $response without returning a bogus download URL',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          await request.drain<void>();
          request.response.statusCode = response is int ? response : 200;
          request.response.write(
            response == 'invalid-json'
                ? '<html>Error</html>'
                : jsonEncode({'secure_url': 'https://evil.example/report.pdf'}),
          );
          await request.response.close();
        });
        final storage = CloudinaryReportStorageService(
          clientFactory: realHttpClient,
          options: const CloudinaryOptions(
            cloudName: 'demo',
            uploadPreset: 'test',
          ),
          currentUid: () => 'user-a',
          endpoint: Uri.parse('http://127.0.0.1:${server.port}/upload'),
        );
        final task = storage.upload(
          'user-a',
          CiReportFile(
            filename: fixture().filename,
            bytes: Uint8List.fromList(utf8.encode('%PDF-1.7')),
          ),
        );
        await expectLater(
          task.done,
          throwsA(
            response == 'invalid-json'
                ? isA<FormatException>()
                : isA<CiReportException>(),
          ),
        );
      },
    );
  }
  test(
    'Cloudinary delivery URL validation rejects foreign hosts and HTML files',
    () {
      expect(isCloudinaryReportUrl(reportUrl), isTrue);
      expect(
        isCloudinaryReportUrl(
          'https://res.cloudinary.com.evil.example/demo/raw/upload/a.pdf',
        ),
        isFalse,
      );
      expect(
        isCloudinaryReportUrl(
          'https://res.cloudinary.com/demo/raw/upload/a.html',
        ),
        isFalse,
      );
      expect(isCloudinaryReportUrl(reportUrl, cloudName: 'other'), isFalse);
    },
  );
  testWidgets(
    'Analysis export button opens a report with local share and Cloudinary upload',
    (tester) async {
      final github = FakeActionsRepository();
      final model = WorkflowRunViewModel(
        github,
        repo: savedRepo,
        run: fixture().run,
        accessToken: 'fake',
        ownerUid: 'user-a',
        analysisRepository: FakeCiRepository(github),
      );
      model.analysis = fixture().analysis;
      addTearDown(model.dispose);
      final storage = FakeStorage();
      await tester.pumpWidget(
        MaterialApp(
          home: CiAnalysisView(
            model: model,
            onRerun: (_) async => false,
            reportRepository: CiReportRepository(
              pdf: FakePdf(),
              storage: storage,
              sharing: FakeSharing(),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Xuất báo cáo PDF'));
      await tester.pumpAndSettle();
      expect(find.byType(CiReportView), findsOneWidget);
      expect(find.text('Lưu / chia sẻ PDF'), findsOneWidget);
      expect(find.textContaining('công khai'), findsOneWidget);
      await tester.ensureVisible(find.text('Upload lên Cloudinary'));
      await tester.tap(find.text('Upload lên Cloudinary'));
      await tester.pump();
      storage.tasks.single.events.add(.5);
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Đang tải lên 50%'), 80);
      expect(find.text('Đang tải lên 50%'), findsOneWidget);
      storage.tasks.single.completion.complete(reportUrl);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Mở bản trên đám mây'), 80);
      expect(find.text('Mở bản trên đám mây'), findsOneWidget);
    },
  );
  final simulation = Platform.environment['CLOUDINARY_SIMULATION_BASE'];
  test(
    'Cloudinary adapter runs against the Postman simulation over real HTTP',
    () async {
      for (final cloud in [
        'demo',
        'rejected',
        'limited',
        'unavailable',
        'invalid-json',
      ]) {
        final storage = CloudinaryReportStorageService(
          clientFactory: realHttpClient,
          options: CloudinaryOptions(
            cloudName: cloud,
            uploadPreset: 'simulation',
          ),
          currentUid: () => 'user-a',
          endpoint: Uri.parse('$simulation/cloudinary/v1_1/$cloud/raw/upload'),
        );
        final task = storage.upload(
          'user-a',
          CiReportFile(
            filename: fixture().filename,
            bytes: Uint8List.fromList(utf8.encode('%PDF-1.7\n%%EOF')),
          ),
        );
        if (cloud == 'demo') {
          expect(
            await task.done,
            startsWith('https://res.cloudinary.com/demo/'),
          );
        } else {
          await expectLater(task.done, throwsA(isA<Object>()));
        }
      }
    },
    skip: simulation == null
        ? 'Set CLOUDINARY_SIMULATION_BASE to run with the local Postman stand-in.'
        : false,
  );
}
