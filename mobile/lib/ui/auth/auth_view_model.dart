import 'package:flutter/foundation.dart';

import '../../core/errors/auth_error_message.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository);

  final AuthRepository _repository;
  UserProfile? profile;
  bool busy = false;
  String actionMessage = '';
  bool _disposed = false;

  String? get githubAccessToken => _repository.githubAccessToken;

  Future<void> signInWithGitHub() => _run(() async {
    final user = await _repository.signInWithGitHub();
    if (!_disposed) profile = user;
  });

  Future<void> signOut() => _run(() async {
    await _repository.signOut();
    if (!_disposed) profile = null;
  });

  // Login and logout share the same button loading/error handling.
  Future<void> _run(Future<void> Function() action) async {
    if (_disposed || busy) return;
    busy = true;
    actionMessage = '';
    notifyListeners();
    try {
      await action();
    } catch (error) {
      if (!_disposed) actionMessage = authErrorMessage(error);
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
