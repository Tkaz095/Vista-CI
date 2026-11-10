import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/auth_identity.dart';
import 'github_token_store.dart';

class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth, GitHubTokenStore? tokenStore})
    : _auth = auth ?? FirebaseAuth.instance,
      _tokens = tokenStore ?? GitHubTokenStore();

  final FirebaseAuth _auth;
  final GitHubTokenStore _tokens;
  String? _githubAccessToken;
  String? _tokenUid;
  int _tokenRevision = 0;
  bool isCurrent(String uid) => _auth.currentUser?.uid == uid;
  String? get githubAccessToken =>
      _tokenUid == _auth.currentUser?.uid ? _githubAccessToken : null;

  Stream<AuthIdentity?> authStateChanges() =>
      _auth.authStateChanges().asyncMap(_restoreConnection);

  void _forgetToken() {
    _tokenRevision++;
    _githubAccessToken = null;
    _tokenUid = null;
  }

  String? _githubId(User user) {
    for (final provider in user.providerData) {
      if (provider.providerId == 'github.com') return provider.uid;
    }
    return null;
  }

  Future<AuthIdentity?> _restoreConnection(User? user) async {
    // Firebase may have advanced to a new account while an older event waited.
    if (_auth.currentUser?.uid != user?.uid) return null;
    if (user?.uid != _tokenUid) _forgetToken();
    try {
      if (user == null) {
        _forgetToken();
        await _tokens.clear(isCurrent: () => _auth.currentUser == null);
        return null;
      }
      if (_githubAccessToken == null) {
        final githubId = _githubId(user);
        final revision = _tokenRevision;
        bool current() => isCurrent(user.uid) && revision == _tokenRevision;
        if (githubId == null) {
          await _tokens.clear(isCurrent: current);
        } else {
          final token = await _tokens.read(
            uid: user.uid,
            githubId: githubId,
            isCurrent: current,
          );
          if (token != null && current()) {
            final usable = await _isTokenUsable(token, githubId);
            if (!current()) {
              return isCurrent(user.uid) ? _identity(user) : null;
            }
            if (usable) {
              _githubAccessToken = token;
              _tokenUid = user.uid;
              _tokenRevision++;
            } else {
              await _tokens.clearFor(user.uid);
            }
          }
        }
      }
    } on PlatformException {
      // Keystore/OS storage unavailable: preserve the Firebase session and let
      // the user reconnect GitHub. Never fall back to plaintext persistence.
    }
    return user != null && isCurrent(user.uid) ? _identity(user) : null;
  }

  Future<bool> _isTokenUsable(String token, String githubId) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.https('api.github.com', '/user'))
        ..followRedirects = false
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2026-03-10',
        });
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 401) return false;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> &&
            data['id']?.toString() == githubId;
      }
    } on TimeoutException {
      // Temporary network/rate-limit failures do not revoke a saved connection.
    } on http.ClientException {
      // The normal GitHub requests still enforce authentication and repo access.
    } on FormatException {
      // An unreadable response is not proof that the credential was revoked.
    } finally {
      client.close();
    }
    return true;
  }

  AuthIdentity _identity(User user) => AuthIdentity(
    uid: user.uid,
    email: user.email ?? '',
    displayName: user.displayName ?? '',
  );

  Future<AuthIdentity> signInWithGitHub() async {
    final provider = GithubAuthProvider()..addScope('repo');
    final current = _auth.currentUser;
    final result = current == null
        ? await _auth.signInWithProvider(provider)
        : await current.reauthenticateWithProvider(provider);
    final user = result.user;
    if (user == null) throw StateError('Firebase returned no user');
    if (_auth.currentUser?.uid != user.uid) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    final githubId = _githubId(user);
    if (githubId == null) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    final credential = result.credential?.accessToken ?? githubAccessToken;
    final token = credential == null || credential.isEmpty ? null : credential;
    final revision = ++_tokenRevision;
    _githubAccessToken = token;
    _tokenUid = user.uid;
    try {
      if (token != null && token.isNotEmpty) {
        await _tokens.save(
          uid: user.uid,
          githubId: githubId,
          token: token,
          isCurrent: () => isCurrent(user.uid) && revision == _tokenRevision,
        );
      } else {
        await _tokens.clearFor(user.uid);
      }
    } on PlatformException {
      // Do not expose the native exception or a serialized credential to logs.
      throw FirebaseAuthException(code: 'secure-storage-unavailable');
    }
    if (!isCurrent(user.uid) || revision != _tokenRevision) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    return _identity(user);
  }

  Future<void> signOut() async {
    _forgetToken();
    // A failed secure delete must not be reported as a successful sign-out.
    try {
      await _tokens.clear();
    } on PlatformException {
      throw FirebaseAuthException(code: 'secure-storage-unavailable');
    }
    await _auth.signOut();
  }
}
