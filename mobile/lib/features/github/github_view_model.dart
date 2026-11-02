import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/session_view_model.dart';
import 'github_repository.dart';

class GitHubViewModel extends ChangeNotifier {
  GitHubViewModel() {
    scheduleMicrotask(() {
      if (!_disposed) unawaited(load());
    });
  }
  List<GitHubRepo> repos = [];
  bool pending = false, more = false, loaded = false;
  String error = '';
  int _page = 0;
  bool _disposed = false;
  int _generation = 0;
  void reset() {
    _generation++;
    pending = false;
    repos = [];
    more = false;
    loaded = false;
    error = '';
    GitHubRepository.instance.cancelConnection();
    notifyListeners();
  }

  Future<void> load({
    bool reconnect = false,
    bool includePrivate = false,
    bool next = false,
  }) async {
    if (pending) return;
    final generation = ++_generation;
    pending = true;
    error = '';
    if (!next) {
      repos = [];
      loaded = false;
      _page = 0;
      more = false;
    }
    notifyListeners();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      if (reconnect) await GitHubRepository.instance.connect(includePrivate);
      if (_disposed ||
          generation != _generation ||
          uid != FirebaseAuth.instance.currentUser?.uid) {
        return;
      }
      final target = next ? _page + 1 : 1;
      final result = await GitHubRepository.instance.page(target);
      if (_disposed ||
          generation != _generation ||
          uid != FirebaseAuth.instance.currentUser?.uid) {
        return;
      }
      _page = target;
      loaded = true;
      more = result.more;
      repos = {
        for (final repo in [...repos, ...result.repos]) repo.id: repo,
      }.values.toList();
    } catch (cause) {
      if (!_disposed && generation == _generation) {
        error = cause is FirebaseAuthException
            ? authMessage(cause)
            : cause is TimeoutException
            ? 'Quá thời gian tải repo GitHub. Kiểm tra mạng rồi thử lại.'
            : cause is http.ClientException
            ? 'Không kết nối được GitHub. Kiểm tra mạng rồi thử lại.'
            : cause is FormatException
            ? 'Dữ liệu GitHub không hợp lệ. Vui lòng tải lại.'
            : cause.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      if (!_disposed && generation == _generation) {
        pending = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    repos = [];
    super.dispose();
  }
}
