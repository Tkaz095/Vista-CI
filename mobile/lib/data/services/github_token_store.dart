import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One encrypted credential, bound to both Vista and GitHub identities.
class GitHubTokenStore {
  GitHubTokenStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'vista_github'),
          );

  static const _key = 'github_connection_v1';
  final FlutterSecureStorage _storage;
  Future<void> _pending = Future.value();

  // Stream retries and OAuth completion can overlap. Keep native operations in
  // order so a late read/delete cannot overwrite another account's credential.
  Future<T> _serial<T>(Future<T> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<String?> read({
    required String uid,
    required String githubId,
    required bool Function() isCurrent,
  }) => _serial(() async {
    if (!isCurrent()) return null;
    final raw = await _storage.read(key: _key);
    if (!isCurrent() || raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic> &&
          data['uid'] == uid &&
          data['githubId'] == githubId &&
          data['token'] is String &&
          (data['token'] as String).isNotEmpty) {
        return data['token'] as String;
      }
    } on FormatException {
      // A corrupt or mismatched record is never used for API requests.
    }
    await _storage.delete(key: _key);
    return null;
  });

  Future<void> save({
    required String uid,
    required String githubId,
    required String token,
    required bool Function() isCurrent,
  }) => _serial(() async {
    if (!isCurrent()) return;
    await _storage.write(
      key: _key,
      value: jsonEncode({'uid': uid, 'githubId': githubId, 'token': token}),
    );
    // Account changes during the native write must not leave a stale secret.
    if (!isCurrent()) await _storage.delete(key: _key);
  });

  Future<void> clear({bool Function()? isCurrent}) => _serial(() async {
    if (isCurrent == null || isCurrent()) await _storage.delete(key: _key);
  });

  Future<void> clearFor(String uid) => _serial(() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic> && data['uid'] != uid) return;
    } on FormatException {
      // Invalid records can be discarded, but valid other-user records cannot.
    }
    await _storage.delete(key: _key);
  });
}
