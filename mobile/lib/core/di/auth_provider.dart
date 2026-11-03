import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vista_mobile/data/repositories/auth_repository.dart';
import 'package:vista_mobile/data/services/firebase_auth_service.dart';

final firebaseAuthServiceProvider = Provider(
  (ref) => FirebaseAuthService(),
);

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    ref.watch(firebaseAuthServiceProvider),
  ),
);