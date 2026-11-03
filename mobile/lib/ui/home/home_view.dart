import 'package:flutter/material.dart';

import '../../data/models/user_profile.dart';
import '../../data/repositories/project_repository.dart';
import '../auth/auth_view_model.dart';
import '../projects/projects_view.dart';
import '../projects/projects_view_model.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.profile, required this.viewModel});

  final UserProfile profile;
  final AuthViewModel viewModel;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final ProjectsViewModel projects;

  @override
  void initState() {
    super.initState();
    projects = ProjectsViewModel(
      ProjectRepository(),
      uid: widget.profile.uid,
      accessToken: widget.viewModel.githubAccessToken,
    );
    projects.loadProjects();
  }

  @override
  void dispose() {
    projects.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        actions: [
          TextButton.icon(
            onPressed: widget.viewModel.busy ? null : widget.viewModel.signOut,
            icon: const Icon(Icons.logout),
            label: Text(widget.viewModel.busy ? 'Đang xử lý…' : 'Đăng xuất'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.viewModel.actionMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(widget.viewModel.actionMessage),
                ),
              ),
            Expanded(
              child: ProjectsView(viewModel: projects, profile: widget.profile),
            ),
          ],
        ),
      ),
    );
  }
}
