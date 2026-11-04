import 'package:flutter/material.dart';

import '../../data/models/project.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_message.dart';
import '../widgets/app_stack_header.dart';
import '../widgets/app_text_field.dart';
import 'projects_view_model.dart';

class SelectRepositoriesView extends StatefulWidget {
  const SelectRepositoriesView({super.key, required this.viewModel});
  final ProjectsViewModel viewModel;

  @override
  State<SelectRepositoriesView> createState() => _SelectRepositoriesViewState();
}

class _SelectRepositoriesViewState extends State<SelectRepositoriesView> {
  late final List<ProjectRepo> previousSelection;
  bool confirmed = false;

  @override
  void initState() {
    super.initState();
    previousSelection = [...widget.viewModel.selectedRepositories];
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final model = widget.viewModel;
      final selected = model.selectedRepositories
          .map((repo) => repo.id)
          .toSet();
      final repos = model.visibleRepositories;
      final theme = Theme.of(context);
      return PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop && !confirmed) {
            model.restoreRepositorySelection(previousSelection);
          }
        },
        child: Scaffold(
          appBar: const AppStackHeader(title: 'Chọn repository'),
          bottomNavigationBar: Material(
            color: theme.colorScheme.surface,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${selected.length} repositories đã chọn',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.small),
                      AppButton(
                        label: 'Xác nhận lựa chọn',
                        onPressed: model.saving
                            ? null
                            : () {
                                confirmed = true;
                                Navigator.of(context).pop();
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: model.loadGitHubRepositories,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount:
                    model.loadingRepositories &&
                        model.githubRepositories.isEmpty
                    ? 1
                    : repos.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.page),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Repository',
                                style: theme.textTheme.headlineMedium,
                              ),
                              Chip(
                                label: Text('${selected.length} đã chọn'),
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.small),
                          const Text('Chọn repository cho project của bạn.'),
                          const SizedBox(height: AppSpacing.page),
                          AppTextField(
                            label: 'Tìm repo',
                            prefixIcon: Icons.search,
                            initialValue: model.repositorySearch,
                            onChanged: model.setRepositorySearch,
                          ),
                          const SizedBox(height: AppSpacing.medium),
                          if (model.loadingRepositories)
                            AppLoading(
                              label: 'Đang tải repository…',
                              compact: model.githubRepositories.isNotEmpty,
                            ),
                          if (model.repositoryError.isNotEmpty)
                            AppMessage(message: model.repositoryError),
                          if (!model.loadingRepositories &&
                              model.repositoryError.isEmpty &&
                              repos.isEmpty)
                            AppEmptyState(
                              message: model.repositorySearch.trim().isEmpty
                                  ? 'GitHub chưa trả về repo nào.'
                                  : 'Không tìm thấy repo phù hợp.',
                            ),
                          if (selected.length >= Project.maxRepositories)
                            Text(
                              'Mỗi project chọn tối đa ${Project.maxRepositories} repo. Bỏ chọn một repo để chọn repo khác.',
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    );
                  }
                  final repo = repos[index - 1];
                  final checked = selected.contains(repo.id);
                  return CheckboxListTile(
                    key: ValueKey(repo.id),
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                      vertical: AppSpacing.control,
                    ),
                    shape: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    tileColor: checked
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surface,
                    title: Text(
                      repo.fullName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'GeistMono',
                      ),
                    ),
                    subtitle: Text(
                      [
                        repo.isPrivate ? 'Riêng tư' : 'Công khai',
                        if (repo.language.isNotEmpty) repo.language,
                      ].join(' · '),
                    ),
                    value: checked,
                    onChanged:
                        model.saving ||
                            model.loadingRepositories ||
                            (!checked &&
                                selected.length >= Project.maxRepositories)
                        ? null
                        : (_) => model.toggleRepository(repo),
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}
