import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum SessionStatus { loading, signedOut, ready, blocked, error }

class VistaProfile {
  const VistaProfile(this.uid, this.email, this.displayName, this.role);
  final String uid, email, displayName, role;
}

String authMessage(Object error) {
  final code = error is FirebaseAuthException ? error.code : '';
  return switch (code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'invalid-email' => 'Email hoặc mật khẩu không đúng.',
    'too-many-requests' => 'Bạn đã thử quá nhiều lần. Vui lòng thử lại sau.',
    'network-request-failed' =>
      'Không kết nối được Firebase. Kiểm tra mạng rồi thử lại.',
    'user-disabled' => 'Tài khoản đã bị vô hiệu hóa.',
    'operation-not-allowed' =>
      'Phương thức đăng nhập này chưa được bật trên Firebase.',
    'web-context-cancelled' ||
    'web-context-canceled' ||
    'popup-closed-by-user' ||
    'cancelled-popup-request' =>
      'Bạn đã hủy đăng nhập GitHub. Có thể thử lại khi sẵn sàng.',
    'account-exists-with-different-credential' || 'email-already-in-use' => 'Email đã có tài khoản Vista. Đăng nhập bằng Email/Password, vào Tài khoản và chọn Liên kết GitHub để giữ UID.',
    'credential-already-in-use' => 'GitHub này đã gắn với một tài khoản Vista khác. Không thể tự gộp hai tài khoản.',
    'provider-already-linked' => 'Tài khoản Vista này đã liên kết GitHub.',
    'requires-recent-login' =>
      'Đăng xuất và đăng nhập lại trước khi liên kết GitHub.',
    'no-current-user' =>
      'Phiên đã kết thúc. Đăng nhập lại trước khi liên kết GitHub.',
    'invalid-oauth-client-id' || 'invalid-oauth-provider' =>
      'Cấu hình GitHub OAuth chưa hợp lệ. Kiểm tra provider và callback URL.',
    'invalid-cert-hash' =>
      'Chưa cấu hình đúng SHA-1 của bản Android này trên Firebase.',
    'web-network-request-failed' => 'Trình duyệt không kết nối được dịch vụ GitHub. Kiểm tra mạng rồi thử lại.',
    _ => 'Chưa hoàn tất thao tác. Vui lòng thử lại.',
  };
}

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Stream<User?> get sessions => _auth.authStateChanges();
  Stream<DocumentSnapshot<Map<String, dynamic>>> profile(String uid) =>
      FirebaseFirestore.instance
          .doc('users/$uid')
          .snapshots(includeMetadataChanges: true);
  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Firebase owns the OAuth flow. Vista does not persist OAuth credentials.
  Future<void> loginWithGitHub() async {
    await _auth.signInWithProvider(GithubAuthProvider());
  }

  bool get githubLinked =>
      _auth.currentUser?.providerData.any(
        (provider) => provider.providerId == 'github.com',
      ) ??
      false;

  Future<void> linkGitHub() async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    await user.linkWithProvider(GithubAuthProvider());
  }

  // Create missing profiles; normalize legacy roles without changing activation.
  Future<void> ensureOwnProfile(User user, bool Function() isCurrent) async {
    final reference = FirebaseFirestore.instance.doc('users/${user.uid}');
    final name = user.displayName?.trim();
    final emailName = user.email?.split('@').first.trim();
    final displayName = name != null && name.isNotEmpty
        ? name
        : emailName != null && emailName.isNotEmpty
        ? emailName
        : 'Thành viên Vista';
    await FirebaseFirestore.instance.runTransaction<void>((transaction) async {
      if (!isCurrent()) return;
      final existing = await transaction.get(reference);
      if (!isCurrent()) return;
      if (existing.exists) {
        final data = existing.data();
        if (data?['isActive'] == true && data?['role'] != 'user') {
          transaction.update(reference, <String, dynamic>{'role': 'user'});
        }
        return;
      }
      transaction.set(reference, <String, dynamic>{
        'displayName': String.fromCharCodes(displayName.runes.take(100)),
        'role': 'user',
        'isActive': true,
      });
    });
  }

  Future<void> logout() => _auth.signOut();
}

class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this.repository) {
    retry();
  }
  final AuthRepository repository;
  SessionStatus status = SessionStatus.loading;
  VistaProfile? profile;
  String message = '';
  StreamSubscription<User?>? _auth;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profile;
  Timer? _deadline;
  int _generation = 0;
  bool _disposed = false;

  void _set(SessionStatus next, [String text = '', VistaProfile? value]) {
    if (_disposed) return;
    status = next;
    message = text;
    profile = value;
    notifyListeners();
  }

  void retry() {
    _generation++;
    _auth?.cancel();
    _profile?.cancel();
    _deadline?.cancel();
    _set(SessionStatus.loading);
    _auth = repository.sessions.listen(
      _onUser,
      onError: (Object error) {
        _set(SessionStatus.error, authMessage(error));
      },
    );
  }

  void _onUser(User? user) {
    final generation = ++_generation;
    _profile?.cancel();
    _deadline?.cancel();
    if (user == null) {
      _set(SessionStatus.signedOut);
      return;
    }
    bool current() => !_disposed && generation == _generation;
    var provisioningAttempted = false;
    void waitForServer() {
      _set(SessionStatus.loading);
      _deadline ??= Timer(const Duration(seconds: 15), () {
        if (current()) {
          _set(
            SessionStatus.error,
            'Chưa xác minh được hồ sơ với máy chủ. Kiểm tra mạng rồi thử lại.',
          );
        }
      });
    }

    _deadline = null;
    waitForServer();
    _profile = repository
        .profile(user.uid)
        .listen(
          (snapshot) {
            if (!current()) return;
            if (snapshot.metadata.isFromCache ||
                snapshot.metadata.hasPendingWrites) {
              waitForServer();
              return;
            }
            final data = snapshot.data();
            if (!snapshot.exists ||
                (data?['isActive'] == true && data?['role'] != 'user')) {
              if (provisioningAttempted) return;
              provisioningAttempted = true;
              waitForServer();
              unawaited(
                repository.ensureOwnProfile(user, current).catchError((
                  Object error,
                ) {
                  if (!current()) return;
                  _deadline?.cancel();
                  _deadline = null;
                  _set(
                    SessionStatus.error,
                    error is FirebaseException &&
                            error.code == 'permission-denied'
                        ? 'Chưa được phép tạo hồ sơ Vista. Hãy publish Firestore Rules mới cho phép tạo hồ sơ User và chuyển vai trò cũ về user, rồi bấm Kiểm tra lại.'
                        : 'Chưa khởi tạo được hồ sơ Vista. Kiểm tra mạng rồi bấm Kiểm tra lại.',
                  );
                }),
              );
              return;
            }
            _deadline?.cancel();
            _deadline = null;
            if (data == null || data['isActive'] != true) {
              _set(
                SessionStatus.blocked,
                'Hồ sơ Vista đã bị vô hiệu hóa. Liên hệ người quản trị để được hỗ trợ.',
              );
              return;
            }
            final role = data['role'];
            if (role != 'user') {
              _set(
                SessionStatus.blocked,
                'Chưa chuyển được hồ sơ về user. Bấm Kiểm tra lại sau khi cập nhật Rules.',
              );
              return;
            }
            _set(
              SessionStatus.ready,
              '',
              VistaProfile(
                user.uid,
                user.email ?? '',
                data['displayName'] is String
                    ? (data['displayName'] as String).trim()
                    : '',
                role as String,
              ),
            );
          },
          onError: (Object error) {
            if (!current()) return;
            _deadline?.cancel();
            _deadline = null;
            _set(
              SessionStatus.error,
              error is FirebaseException && error.code == 'permission-denied'
                  ? 'Firebase từ chối đọc hồ sơ cá nhân (permission-denied). Kiểm tra Rules của project vista-ci, database (default): phải cho tài khoản đã đăng nhập đọc document users của chính mình, kể cả khi document chưa tồn tại.'
                  : 'Không tải được hồ sơ. Kiểm tra mạng rồi thử lại.',
            );
          },
        );
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _auth?.cancel();
    _profile?.cancel();
    _deadline?.cancel();
    super.dispose();
  }
}
