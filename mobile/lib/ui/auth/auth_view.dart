import 'package:flutter/material.dart';

import '../../core/state/async_state.dart';
import '../home/home_view.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_message.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_header.dart';
import 'auth_view_model.dart';
import '../notifications/notification_center_view.dart';
import '../notifications/notification_run_view.dart';

/// Rebuilds the current screen when login or logout updates the ViewModel.
class AuthView extends StatelessWidget {
  const AuthView({super.key, required this.viewModel});
  final AuthViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      switch (viewModel.state.status) {
        case LoadStatus.empty:
          return LoginView(viewModel: viewModel);
        case LoadStatus.loading:
        case LoadStatus.error:
          return Scaffold(
            appBar: const AppHeader(showNotifications: false),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  if (viewModel.state.isLoading)
                    const AppLoading(label: 'Đang xác minh phiên đăng nhập…')
                  else ...[
                    AppMessage(message: viewModel.state.message),
                    const SizedBox(height: AppSpacing.medium),
                    AppButton(
                      label: 'Kiểm tra lại',
                      onPressed: viewModel.retrySession,
                    ),
                  ],
                  if (viewModel.actionMessage.isNotEmpty)
                    AppMessage(message: viewModel.actionMessage),
                  const SizedBox(height: AppSpacing.medium),
                  AppButton(
                    label: 'Đăng xuất',
                    isLoading: viewModel.busy,
                    onPressed: viewModel.signOut,
                    variant: AppButtonVariant.secondary,
                  ),
                ],
              ),
            ),
          );
        case LoadStatus.success:
          return _AuthenticatedSession(
            key: ValueKey(
              '${viewModel.profile!.uid}:${viewModel.sessionRevision}',
            ),
            viewModel: viewModel,
          );
      }
    },
  );
}

/// Every protected route belongs to this subtree, removed when access changes.
class _AuthenticatedSession extends StatefulWidget {
  const _AuthenticatedSession({super.key, required this.viewModel});
  final AuthViewModel viewModel;

  @override
  State<_AuthenticatedSession> createState() => _AuthenticatedSessionState();
}

class _AuthenticatedSessionState extends State<_AuthenticatedSession> {
  final navigator = GlobalKey<NavigatorState>();

  String? _openingId;
  int _foregroundRevision = 0;
  ScaffoldMessengerState? _messenger;
  @override
  void initState() {
    super.initState();
    _foregroundRevision =
        widget.viewModel.notifications?.foregroundRevision ?? 0;
    widget.viewModel.notifications?.addListener(_notificationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notificationChanged());
  }

  void _notificationChanged() {
    if (!mounted) return;
    final notifications = widget.viewModel.notifications;
    if (notifications == null) return;
    final item = notifications.pendingOpen;
    if (item != null &&
        item.uid == widget.viewModel.profile?.uid &&
        _openingId != item.id) {
      _openingId = item.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            notifications.pendingOpen?.id != item.id ||
            item.uid != widget.viewModel.profile?.uid) {
          return;
        }
        final nav = navigator.currentState;
        if (nav == null) {
          _openingId = null;
          return;
        }
        final target = item.target;
        // Keep a cold-start target until the GitHub reconnect rebuilds this session.
        if (target == null || widget.viewModel.githubAccessToken != null) {
          notifications.consumeOpen(item.id);
        }
        notifications.markRead(item);
        nav
            .push(
              MaterialPageRoute<void>(
                builder: (_) => target == null
                    ? NotificationCenterView(model: notifications)
                    : NotificationRunView(
                        target: target,
                        auth: widget.viewModel,
                      ),
              ),
            )
            .then((_) {
              if (!mounted) return;
              notifications.consumeOpen(item.id);
              _openingId = null;
            });
      });
    }
    if (notifications.foregroundRevision > _foregroundRevision) {
      _foregroundRevision = notifications.foregroundRevision;
      final notice = notifications.foregroundNotice;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || notice == null) return;
        _messenger = ScaffoldMessenger.maybeOf(context);
        _messenger?.showSnackBar(
          SnackBar(
            content: Text(notice.title),
            action: SnackBarAction(
              label: 'Xem',
              onPressed: () => notifications.open(notice),
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    widget.viewModel.notifications?.removeListener(_notificationChanged);
    _messenger?.clearSnackBars();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HeroControllerScope.none(
    child: NavigatorPopHandler<Object?>(
      onPopWithResult: (result) => navigator.currentState!.maybePop(result),
      child: Navigator(
        key: navigator,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => ListenableBuilder(
            listenable: widget.viewModel,
            builder: (_, _) => HomeView(
              profile: widget.viewModel.profile!,
              viewModel: widget.viewModel,
            ),
          ),
        ),
      ),
    ),
  );
}

class LoginView extends StatelessWidget {
  const LoginView({super.key, required this.viewModel});
  final AuthViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: null,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final theme = Theme.of(context);
          final colors = theme.colorScheme;
          final isDark = theme.brightness == Brightness.dark;

          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 480,
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                    vertical: AppSpacing.medium,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.section),
                          // Hero Logo with glowing aura
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        colors.primary.withValues(
                                          alpha: isDark ? 0.35 : 0.18,
                                        ),
                                        colors.primary.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: colors.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.outlineVariant.withValues(
                                        alpha: 0.7,
                                      ),
                                      width: 1.2,
                                    ),
                                    boxShadow: AppShadows.card,
                                  ),
                                  child: Image.asset(
                                    'assets/logo/logo.png',
                                    height: 54,
                                    width: 54,
                                    cacheHeight: 216,
                                    excludeFromSemantics: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.page),
                          Text(
                            'Vista',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.small),
                          Text(
                            'Quản lý project và repository GitHub của bạn.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.page),

                          // Value prop pills
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _ValuePill(
                                icon: Icons.bolt,
                                label: 'Real-time CI',
                                color: colors.primary,
                              ),
                              _ValuePill(
                                icon: Icons.notifications_active_outlined,
                                label: 'Push Alerts',
                                color: const Color(0xFF0F766E),
                              ),
                            ],
                          ),

                          const SizedBox(height: AppSpacing.section),

                          // Login Card Container
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.card),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colors.outlineVariant.withValues(
                                  alpha: 0.6,
                                ),
                                width: 0.8,
                              ),
                              boxShadow: AppShadows.card,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Đăng nhập Vista',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.medium),
                                AppButton(
                                  label: 'Tiếp tục với GitHub',
                                  loadingLabel: 'Đang xác thực…',
                                  isLoading: viewModel.busy,
                                  onPressed: viewModel.signInWithGitHub,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colors.onSurface,
                                    foregroundColor: colors.surface,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  iconWidget: Image.asset(
                                    'assets/logo/github-logo.png',
                                    width: 20,
                                    height: 20,
                                    color: colors.surface,
                                    excludeFromSemantics: true,
                                  ),
                                ),
                                if (viewModel.actionMessage.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.medium),
                                  AppMessage(message: viewModel.actionMessage),
                                ],
                                const SizedBox(height: AppSpacing.medium),
                                Text(
                                  'Vista tự tạo hồ sơ khi bạn đăng nhập lần đầu.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.section,
                          bottom: AppSpacing.small,
                        ),
                        child: Text(
                          'Để hiển thị cả repo riêng tư, GitHub sẽ yêu cầu quyền repo '
                          '(gồm đọc và ghi). Vista hiện chỉ đọc danh sách repo.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
