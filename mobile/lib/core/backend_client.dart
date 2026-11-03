import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BackendException implements Exception {
  BackendException(this.code, this.message);
  final String code, message;
  @override
  String toString() => message;
}

class BackendClient {
  static const _key = 'vista.backend.origin';
  static const _migrationKey = 'vista.backend.firebase.v1';
  static const _defined = String.fromEnvironment(
    'VISTA_BACKEND_URL',
    defaultValue: 'https://vista-ci.web.app',
  );
  static Future<String> origin() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_migrationKey) != true) {
      final saved = preferences.getString(_key)?.trim();
      // Migrate the previous local/Vercel default once; keep custom servers.
      if (saved == null ||
          saved.isEmpty ||
          const {
            'http://localhost:5173',
            'http://127.0.0.1:5173',
            'https://vista-ci.vercel.app',
          }.contains(saved.replaceFirst(RegExp(r'/$'), ''))) {
        await preferences.remove(_key);
      }
      await preferences.setBool(_migrationKey, true);
    }
    return preferences.getString(_key) ?? _defined;
  }

  static Future<void> saveOrigin(String value) async {
    validateOrigin(value);
    await (await SharedPreferences.getInstance()).setString(
      _key,
      Uri.parse(value.trim()).origin,
    );
  }

  static Uri validateOrigin(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !['', '/'].contains(uri.path) ||
        !(uri.scheme == 'https' ||
            kDebugMode &&
                uri.scheme == 'http' &&
                ['localhost', '127.0.0.1'].contains(uri.host))) {
      throw BackendException(
        'BACKEND_SETUP',
        'Nhập URL backend Firebase https://vista-ci.web.app. Debug local mới dùng localhost và adb reverse.',
      );
    }
    return uri;
  }

  static Future<http.Response> request(
    String path, {
    Map<String, String>? query,
    bool post = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw BackendException(
        'FIREBASE_AUTH_REQUIRED',
        'Đăng nhập Vista trước.',
      );
    }
    final base = validateOrigin(await origin());
    final token = await user.getIdToken();
    final headers = {
      'Authorization': 'Bearer $token',
      'X-Vista-Client': 'flutter',
    };
    final url = base.replace(path: path, queryParameters: query);
    final client = http.Client();
    late final http.Response response;
    try {
      final request = http.Request(post ? 'POST' : 'GET', url)
        ..followRedirects = false;
      request.headers.addAll(headers);
      response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 35));
    } on TimeoutException {
      throw BackendException(
        'BACKEND_TIMEOUT',
        'Quá thời gian chờ backend. Kiểm tra mạng rồi thử lại.',
      );
    } on http.ClientException {
      throw BackendException(
        'BACKEND_NETWORK',
        'Không kết nối được backend Firebase Vista. Kiểm tra URL, mạng và trạng thái deploy Functions.',
      );
    } finally {
      client.close();
    }
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw BackendException('ACCOUNT_CHANGED', 'Phiên tài khoản đã thay đổi.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.headers['content-type']?.contains('application/json') ??
          false) {
        final dynamic value = jsonDecode(response.body);
        if (value is! Map) {
          throw BackendException(
            'INVALID_RESPONSE',
            'Backend trả lỗi không hợp lệ.',
          );
        }
        throw BackendException(
          '${value['code'] ?? 'BACKEND_ERROR'}',
          '${value['message'] ?? 'Không hoàn tất yêu cầu backend.'}',
        );
      }
      if (response.headers['content-type']?.startsWith('text/plain') ?? false) {
        throw BackendException(
          'BACKEND_ERROR',
          response.body.length > 2000
              ? response.body.substring(0, 2000)
              : response.body,
        );
      }
      throw BackendException(
        'BACKEND_ERROR',
        'Không hoàn tất yêu cầu backend (HTTP ${response.statusCode}). Kiểm tra URL server.',
      );
    }
    return response;
  }

  static Future<Map<String, dynamic>> json(
    String path, {
    Map<String, String>? query,
    bool post = false,
  }) async {
    final response = await request(path, query: query, post: post);
    if (!(response.headers['content-type']?.contains('application/json') ??
        false)) {
      throw BackendException(
        'BACKEND_SETUP',
        'URL chưa phục vụ API Vista. Kiểm tra backend Vite/Vercel.',
      );
    }
    final dynamic data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw BackendException(
        'INVALID_RESPONSE',
        'Dữ liệu backend không hợp lệ.',
      );
    }
    return data;
  }
}
