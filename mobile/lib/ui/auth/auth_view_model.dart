import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vista_mobile/core/di/auth_provider.dart';
import 'package:vista_mobile/data/repositories/auth_repository.dart';

final loginViewModelProvider =
    StateNotifierProvider<LoginViewModel, AsyncValue<void>>((ref) {
      final repository = ref.watch(authRepositoryProvider);
      return LoginViewModel(repository);
    });

class LoginViewModel extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;
  LoginViewModel(this._authRepository) : super(const AsyncValue.data(null));

  Future<void> signInWithGitHub() async {
    if (state.isLoading) return;
    state = const AsyncValue.loading();

    final result = await AsyncValue.guard(
      _authRepository.signInWithGitHub,
    )

    if (!mounted) return;
    state = result;
  }
}
