import 'package:flutter/material.dart';

import '../../data/models/user_profile.dart';
import '../../data/repositories/project_repository.dart';
import '../action/action_view.dart';
import '../auth/auth_view_model.dart';
import '../profile/profile_view.dart';
import '../projects/projects_view.dart';
import '../projects/projects_view_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_tab.dart';
import '../widgets/app_header.dart';
import '../widgets/app_message.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.profile, required this.viewModel});

  final UserProfile profile;
  final AuthViewModel viewModel;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final ProjectsViewModel projects;
  AppTab selectedTab = AppTab.projects;

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
    return PopScope(
      canPop: selectedTab == AppTab.projects,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selectedTab != AppTab.projects) {
          setState(() => selectedTab = AppTab.projects);
        }
      },
      child: Scaffold(
        appBar: const AppHeader(),
        bottomNavigationBar: AppBottomTab(
          selectedTab: selectedTab,
          onSelected: (tab) {
            FocusScope.of(context).unfocus();
            setState(() => selectedTab = tab);
          },
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (widget.viewModel.actionMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: AppMessage(message: widget.viewModel.actionMessage),
                ),
              Expanded(
                // Keep the project list and its scroll position when switching tabs.
                child: IndexedStack(
                  index: selectedTab.index,
                  children: [
                    ProjectsView(viewModel: projects),
                    const ActionView(),
                    ProfileView(
                      profile: widget.profile,
                      isSigningOut: widget.viewModel.busy,
                      onSignOut: widget.viewModel.signOut,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
