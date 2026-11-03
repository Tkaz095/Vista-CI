import 'package:flutter/material.dart';

import '../../data/models/user_profile.dart';
import '../auth/auth_view_model.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.profile, required this.viewModel});

  final UserProfile profile;
  final AuthViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName.isEmpty
        ? 'Vista User'
        : profile.displayName;

    return Scaffold(
      appBar: AppBar(title: const Text('Trang chủ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Xin chào, $name',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (profile.email.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(profile.email),
            ],
            const SizedBox(height: 20),
            const Text('Bạn đã đăng nhập GitHub thành công.'),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: viewModel.busy ? null : viewModel.signOut,
              icon: const Icon(Icons.logout),
              label: Text(viewModel.busy ? 'Đang xử lý…' : 'Đăng xuất'),
            ),
            if (viewModel.actionMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Semantics(liveRegion: true, child: Text(viewModel.actionMessage)),
            ],
          ],
        ),
      ),
    );
  }
}
