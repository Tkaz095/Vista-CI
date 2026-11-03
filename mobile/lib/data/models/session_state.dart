import 'package:vista_mobile/data/models/user_profile.dart';

enum SessionStatus {
  loading,
  signedOut,
  ready,
  blocked,
  error,
}

class SessionState {
  const SessionState(
    this.status, {
    this.profile,
    this.message = '',
  }) : assert(
         status != SessionStatus.ready || profile != null,
       );

  final SessionStatus status;
  final UserProfile? profile;
  final String message;
}