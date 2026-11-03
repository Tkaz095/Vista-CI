import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:vista_mobile/ui/auth/auth_view_model.dart';

class LoginView extends ConsumerWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loginState = ref.watch(loginViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập Vista CI')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Chào mừng đến với Vista CI',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Gap(32),

            // Nút bấm đăng nhập GitHub
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: loginState.isLoading
                    ? null // Đang loading thì khóa nút lại
                    : () {
                        // Kích hoạt hàm đăng nhập trong ViewModel
                        ref
                            .read(loginViewModelProvider.notifier)
                            .signInWithGitHub();
                      },
                icon: const Icon(Icons.code),
                label: loginState.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Đăng nhập với GitHub'),
              ),
            ),

            // Hiển thị lỗi nếu có
            if (loginState.hasError) ...[
              const Gap(16),
              Text(
                'Lỗi: ${loginState.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
