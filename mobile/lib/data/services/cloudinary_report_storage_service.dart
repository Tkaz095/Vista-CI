import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../cloudinary_options.dart';
import '../models/ci_report.dart';

/// Simple unsigned uploads. Firebase UID groups files; it is not a Cloudinary ACL.
class CloudinaryReportStorageService implements ReportStorage {
  CloudinaryReportStorageService({
    this.options = const CloudinaryOptions(),
    this._optionsProvider,
    http.Client Function()? clientFactory,
    this._currentUid,
    this._sessions,
    this._endpoint,
  }) : _clientFactory = clientFactory ?? http.Client.new;
  final CloudinaryOptions options;
  final CloudinaryOptions Function()? _optionsProvider;
  final http.Client Function() _clientFactory;
  final String? Function()? _currentUid;
  final Stream<String?>? _sessions;
  final Uri? _endpoint;
  @override
  String? get currentUid => _currentUid != null
      ? _currentUid()
      : FirebaseAuth.instance.currentUser?.uid;
  @override
  Stream<String?> get sessions =>
      _sessions ??
      FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
  @override
  ReportUpload upload(String ownerUid, CiReportFile file) {
    if (currentUid != ownerUid) {
      throw const CiReportException('Phiên đã thay đổi. Hãy mở lại báo cáo.');
    }
    final options = _optionsProvider?.call() ?? this.options;
    if (!options.configured) {
      throw const CiReportException(
        'Chưa cấu hình Cloudinary. Bạn vẫn có thể lưu/chia sẻ PDF trên máy.',
      );
    }
    if (file.bytes.isEmpty ||
        file.bytes.length > CiReportFile.maxBytes ||
        !RegExp(r'^ci_[1-9][0-9]*_[1-9][0-9]*_[1-9][0-9]*_[0-9]+\.pdf$')
            .hasMatch(file.filename) ||
        ownerUid.contains('/')) {
      throw const CiReportException(
        'Báo cáo không hợp lệ hoặc vượt quá 5 MiB.',
      );
    }
    final endpoint = _endpoint ?? options.uploadUrl;
    // A local endpoint is used only by real-HTTP tests; deployed calls stay HTTPS.
    if (endpoint.scheme != 'https' &&
        !(endpoint.scheme == 'http' &&
            ['127.0.0.1', 'localhost', '::1'].contains(endpoint.host))) {
      throw const CiReportException('Địa chỉ upload không hợp lệ.');
    }
    return _CloudinaryUpload(
      _clientFactory(),
      endpoint,
      options,
      ownerUid,
      file,
      () => currentUid == ownerUid,
    );
  }
}

class _CloudinaryUpload implements ReportUpload {
  _CloudinaryUpload(
    this.client,
    this.endpoint,
    this.options,
    this.uid,
    this.file,
    this.isCurrent,
  );
  final http.Client client;
  final Uri endpoint;
  final CloudinaryOptions options;
  final String uid;
  final CiReportFile file;
  final bool Function() isCurrent;
  final _progress = StreamController<double>.broadcast();
  bool _canceled = false;
  @override
  Stream<double> get progress => _progress.stream;
  @override
  late final Future<String> done = _run();
  Future<String> _run() async {
    try {
      _checkSession();
      final request = _ProgressMultipartRequest(endpoint, (value) {
        _checkSession();
        if (!_progress.isClosed) _progress.add(value);
      });
      request.followRedirects = false;
      request.fields['upload_preset'] = options.uploadPreset;
      request.fields['public_id'] = 'vista-ci/reports/$uid/${file.filename}';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes,
          filename: file.filename,
          contentType: MediaType('application', 'pdf'),
        ),
      );
      final response = await client.send(request);
      // Bound response memory and avoid including provider errors/tokens in logs.
      final buffer = <int>[];
      await for (final chunk in response.stream) {
        if (buffer.length + chunk.length > 64 * 1024) {
          throw const CiReportException(
            'Phản hồi upload quá lớn. Hãy thử lại.',
          );
        }
        buffer.addAll(chunk);
      }
      _checkSession();
      if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403) {
        throw const CiReportException(
          'Cloudinary từ chối upload. Kiểm tra cloud name và unsigned upload preset.',
        );
      }
      if (response.statusCode == 413) {
        throw const CiReportException(
          'Báo cáo vượt giới hạn của upload preset Cloudinary.',
        );
      }
      if (response.statusCode == 429) {
        throw const CiReportException(
          'Cloudinary đang giới hạn yêu cầu. Hãy thử lại sau.',
        );
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw const CiReportException(
          'Chưa upload được lên Cloudinary. Bản PDF vẫn được giữ để thử lại.',
        );
      }
      final data = jsonDecode(utf8.decode(buffer));
      final url = data is Map ? data['secure_url'] : null;
      if (url is! String ||
          !isCloudinaryReportUrl(url, cloudName: options.cloudName)) {
        throw const CiReportException(
          'Cloudinary chưa trả về liên kết PDF hợp lệ. Có thể file đã được tải lên; kiểm tra Media Library trước khi thử lại.',
        );
      }
      if (!_progress.isClosed) _progress.add(1);
      return url;
    } finally {
      client.close();
      unawaited(_progress.close());
    }
  }

  void _checkSession() {
    if (_canceled) {
      throw const CiReportException(
        'Đã hủy upload. Bản PDF vẫn được giữ trên máy.',
      );
    }
    if (!isCurrent()) {
      throw const CiReportException('Phiên đã thay đổi. Hãy mở lại báo cáo.');
    }
  }

  @override
  Future<void> cancel() async {
    _canceled = true;
    client.close();
  }
}

class _ProgressMultipartRequest extends http.MultipartRequest {
  _ProgressMultipartRequest(Uri uri, this.onProgress) : super('POST', uri);
  final void Function(double) onProgress;
  @override
  http.ByteStream finalize() {
    final total = contentLength;
    var sent = 0;
    return http.ByteStream(
      super.finalize().map((chunk) {
        sent += chunk.length;
        onProgress(total == 0 ? 0 : (sent / total).clamp(0.0, 0.98));
        return chunk;
      }),
    );
  }
}

bool isCloudinaryReportUrl(String value, {String? cloudName}) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'res.cloudinary.com' &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      (cloudName == null ||
          (uri.pathSegments.isNotEmpty &&
              uri.pathSegments.first == cloudName)) &&
      uri.path.contains('/raw/upload/') &&
      uri.path.endsWith('.pdf');
}

String reportErrorMessage(Object error) {
  if (error is CiReportException) return error.message;
  if (error is TimeoutException) {
    return 'Kết nối quá lâu. Bản PDF vẫn được giữ để thử lại.';
  }
  if (error is http.ClientException) {
    return 'Chưa kết nối được Cloudinary. Kiểm tra mạng rồi thử lại.';
  }
  return 'Chưa hoàn tất thao tác với báo cáo. Bạn có thể thử lại.';
}
