import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/auth_error_message.dart';
import '../../core/state/async_state.dart';
import '../../core/telemetry/app_telemetry.dart';
import '../settings/app_config_view_model.dart';
import '../notifications/notification_view_model.dart';
import '../../data/models/auth_identity.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(
    this._repository, {
    this.sessionTimeout = const Duration(seconds: 20),
    this.telemetry,
    this.configuration,
    this.onDebugCrash,
    this.notifications,
  }) {
    _listen();
  }

  final AuthRepository _repository;
  final NotificationViewModel? notifications;
  final AppTelemetry? telemetry;
  final AppConfigViewModel? configuration;
  final VoidCallback? onDebugCrash;
  String? _telemetryUid;
  bool _loginInProgress = false;
  String? _completedLoginUid;
  bool _sessionEventSent = false;

  void _trackVerifiedSession() {
    final user = profile;
    if (user == null) return;
    if (_telemetryUid != user.uid) {
      telemetry?.identify(user.uid);
      _telemetryUid = user.uid;
    }
    if (_sessionEventSent || (_loginInProgress && _completedLoginUid == null)) {
      return;
    }
    telemetry?.event(
      _completedLoginUid == user.uid
          ? AppEvent.login
          : AppEvent.sessionRestored,
    );
    _sessionEventSent = true;
  }

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
    notifications?.bindSession(value.data?.uid);
    if (value.data == null && _telemetryUid != null) {
      telemetry?.identify(null);
      _telemetryUid = null;
    }
    if (value.data != null) _trackVerifiedSession();
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
      onError: (Object error, StackTrace stack) {
        telemetry?.nonFatal(error, stack, AppOperation.authSession);
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
      _sessionEventSent = false;
      if (!_loginInProgress && _completedLoginUid != identity?.uid) {
        _completedLoginUid = null;
      }
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
          onError: (Object error, StackTrace stack) {
            if (_disposed || generation != _generation) return;
            telemetry?.nonFatal(error, stack, AppOperation.profileRead);
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

  Future<void> signInWithGitHub() async {
    if (_disposed || busy) return;
    _loginInProgress = true;
    _completedLoginUid = null;
    try {
      await _run(() async {
        final identity = await _repository.signInWithGitHub();
        if (_disposed) return;
        _completedLoginUid = identity.uid;
        if (_identity?.uid == identity.uid) {
          sessionRevision++;
          _trackVerifiedSession();
          if (_state.hasError) {
            _clearProfile();
            _onIdentity(identity);
          }
        }
      }, AppOperation.oauth);
    } finally {
      _loginInProgress = false;
    }
  }

  Future<void> signOut() => _run(() async {
    await notifications?.beforeSignOut();
    try {
      await _repository.signOut();
    } catch (_) {
      notifications?.bindSession(profile?.uid);
      rethrow;
    }
    if (!_disposed) {
      telemetry?.identify(null);
      _telemetryUid = null;
      telemetry?.event(AppEvent.logout);
    }
  }, AppOperation.logout);

  Future<void> _run(
    Future<void> Function() action,
    AppOperation operation,
  ) async {
    if (_disposed || busy) return;
    final startingUid = _identity?.uid;
    busy = true;
    actionMessage = '';
    notifyListeners();
    try {
      await action();
    } catch (error, stack) {
      if (!_disposed && _identity?.uid == startingUid) {
        telemetry?.nonFatal(error, stack, operation);
      }
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
    notifications?.bindSession(null);
    _clearProfile();
    _session?.cancel();
    super.dispose();
  }
}
