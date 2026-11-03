class AuthIdentity {
  const AuthIdentity({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  final String uid;
  final String email;
  final String displayName;
}