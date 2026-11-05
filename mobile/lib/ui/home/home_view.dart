import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/user_profile.dart';
import '../../data/repositories/project_repository.dart';
import '../action/action_view.dart';
import '../auth/auth_view_model.dart';
import '../notifications/notification_center_view.dart';
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
  AppTab selectedTab = AppTab.projects;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProjectsViewModel>(
      create: (_) => ProjectsViewModel(
        ProjectRepository(),
        uid: widget.profile.uid,
        accessToken: widget.viewModel.githubAccessToken,
        telemetry: widget.viewModel.telemetry,
        configuration: widget.viewModel.configuration,
      )..loadProjects(),
      child: Consumer<ProjectsViewModel>(
        builder: (context, projects, _) => PopScope(
          canPop: selectedTab == AppTab.projects,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && selectedTab != AppTab.projects) {
              setState(() => selectedTab = AppTab.projects);
            }
          },
          child: Scaffold(
            appBar: widget.viewModel.notifications == null
                ? const AppHeader(showNotifications: false)
                : PreferredSize(
                    preferredSize: const Size.fromHeight(64),
                    child: ListenableBuilder(
                      listenable: widget.viewModel.notifications!,
                      builder: (context, _) => AppHeader(
                        unreadCount:
                            widget.viewModel.notifications!.unreadCount,
                        onNotificationsPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => NotificationCenterView(
                              model: widget.viewModel.notifications!,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
                    // Keep each tab's state while switching between tabs.
                    child: IndexedStack(
                      index: selectedTab.index,
                      children: [
                        ProjectsView(viewModel: projects),
                        const ActionView(),
                        ProfileView(
                          profile: widget.profile,
                          repository: widget.viewModel.repository,
                          onProfileUpdated: widget.viewModel.updateProfile,
                          configuration: widget.viewModel.configuration,
                          telemetry: widget.viewModel.telemetry,
                          onDebugCrash: widget.viewModel.onDebugCrash,
                          isSigningOut: widget.viewModel.busy,
                          onSignOut: widget.viewModel.signOut,
                          onReconnectGitHub:
                              widget.viewModel.githubAccessToken == null
                              ? widget.viewModel.signInWithGitHub
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
