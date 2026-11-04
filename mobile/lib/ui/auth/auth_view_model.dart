import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/auth_error_message.dart';
import '../../core/state/async_state.dart';
import '../../data/models/auth_identity.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(
    this._repository, {
    this.sessionTimeout = const Duration(seconds: 20),
  }) {
    _listen();
  }

  final AuthRepository _repository;
  final Duration sessionTimeout;
  AsyncState<UserProfile> _state = const AsyncState.loading();
  AsyncState<UserProfile> get state => _state;
  UserProfile? get profile => _state.data;
  bool busy = false;
  String actionMessage = '';
  int sessionRevision = 0;
  bool _disposed = false;
  int _generation = 0;
  AuthIdentity? _identity;
  StreamSubscription<AuthIdentity?>? _session;
  StreamSubscription<UserProfile>? _profile;
  Timer? _deadline;

  String? get githubAccessToken => _repository.githubAccessToken;

  void _publish(AsyncState<UserProfile> value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  void _listen() {
    _deadline?.cancel();
    _deadline = Timer(sessionTimeout, () {
      _publish(
        const AsyncState.error(
          'Chưa xác minh được phiên. Kiểm tra mạng rồi thử lại.',
        ),
      );
    });
    _session = _repository.authStateChanges().listen(
      _onIdentity,
      onError: (Object error) {
        _clearProfile();
        _publish(AsyncState.error(authErrorMessage(error)));
      },
    );
  }

  void _clearProfile() {
    _generation++;
    _profile?.cancel();
    _profile = null;
    _deadline?.cancel();
  }

  void _onIdentity(AuthIdentity? identity) {
    if (_disposed) return;
    final changed = _identity?.uid != identity?.uid;
    _identity = identity;
    if (identity != null && !changed && _profile != null) return;
    _clearProfile();
    if (changed) {
      sessionRevision++;
      actionMessage = '';
    }
    if (identity == null) {
      _publish(const AsyncState.empty());
      return;
    }
    final generation = _generation;
    _publish(const AsyncState.loading());
    _deadline = Timer(sessionTimeout, () {
      if (!_disposed && generation == _generation) {
        _publish(
          const AsyncState.error(
            'Chưa xác minh được hồ sơ với máy chủ. Kiểm tra mạng rồi thử lại.',
          ),
        );
      }
    });
    _profile = _repository
        .watchProfile(identity)
        .listen(
          (value) {
            if (_disposed || generation != _generation) return;
            _deadline?.cancel();
            if (value.uid != identity.uid ||
                !value.isActive ||
                value.role != Role.user) {
              _publish(
                const AsyncState.error(
                  'Hồ sơ chưa được cấp quyền hoặc đã bị vô hiệu hóa.',
                ),
              );
            } else {
              _publish(AsyncState.success(value));
            }
          },
          onError: (Object error) {
            if (_disposed || generation != _generation) return;
            _deadline?.cancel();
            _publish(AsyncState.error(authErrorMessage(error)));
          },
        );
  }

  void retrySession() {
    if (_disposed || busy) return;
    _clearProfile();
    _session?.cancel();
    _publish(const AsyncState.loading());
    _listen();
  }

  Future<void> signInWithGitHub() => _run(() async {
    final identity = await _repository.signInWithGitHub();
    if (_disposed) return;
    // Access follows the stream; OAuth completion refreshes the in-memory token.
    if (_identity?.uid == identity.uid) {
      sessionRevision++;
      if (_state.hasError) {
        _clearProfile();
        _onIdentity(identity);
      }
    }
  });

  Future<void> signOut() => _run(() async {
    await _repository.signOut();
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_disposed || busy) return;
    final startingUid = _identity?.uid;
    busy = true;
    actionMessage = '';
    notifyListeners();
    try {
      await action();
    } catch (error) {
      if (!_disposed && _identity?.uid == startingUid) {
        actionMessage = authErrorMessage(error);
      }
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
    _clearProfile();
    _session?.cancel();
    super.dispose();
  }
}
