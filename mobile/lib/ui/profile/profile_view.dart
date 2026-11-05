import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/user_profile.dart';
import '../../core/telemetry/app_telemetry.dart';
import '../../data/repositories/auth_repository.dart';
import '../settings/app_config_view_model.dart';
import '../settings/app_settings_panel.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import 'profile_view_model.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({
    super.key,
    required this.profile,
    required this.onSignOut,
    this.isSigningOut = false,
    this.onReconnectGitHub,
    this.configuration,
    this.telemetry,
    this.onDebugCrash,
    this.repository,
    this.onProfileUpdated,
  });

  final UserProfile profile;
  final AppConfigViewModel? configuration;
  final AppTelemetry? telemetry;
  final VoidCallback? onDebugCrash;
  final VoidCallback onSignOut;
  final bool isSigningOut;
  final VoidCallback? onReconnectGitHub;
  final AuthRepository? repository;
  final void Function(UserProfile)? onProfileUpdated;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late final ProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ProfileViewModel(
      profile: widget.profile,
      repository: widget.repository ?? AuthRepository(),
      onProfileUpdated: widget.onProfileUpdated,
    );
  }

  @override
  void didUpdateWidget(ProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _viewModel.updateInternalProfile(widget.profile);
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _showNotification(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAvatarOptions() {
    final profile = _viewModel.profile;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.medium),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                  vertical: AppSpacing.small,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ảnh đại diện',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lưu trữ và đồng bộ qua Firebase Storage',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Chụp ảnh mới'),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  _viewModel.pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Chọn ảnh từ thư viện'),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  _viewModel.pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              if (profile.photoUrl != null && profile.photoUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error),
                  title: const Text(
                    'Xóa ảnh đại diện',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    _showDeleteAvatarConfirm();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAvatarConfirm() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text(
            'Bạn có chắc chắn muốn xóa ảnh đại diện khỏi Firebase Storage không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _viewModel.removeAvatar();
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _viewModel.profile.displayName);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: colors.surface,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.badge_outlined, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Đổi tên hiển thị'),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AppTextField(
              controller: controller,
              label: 'Tên hiển thị',
              hint: 'Nhập tên hiển thị mới…',
              prefixIcon: Icons.person_outline,
              maxLength: 100,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isEmpty) return;
                Navigator.of(dialogContext).pop();
                await _viewModel.updateDisplayName(newName);
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  void _showSignOutConfirm() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              widget.onSignOut();
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final profile = _viewModel.profile;
        final name = profile.displayName.trim().isEmpty
            ? 'Vista User'
            : profile.displayName.trim();

        // Listen for feedback messages
        if (_viewModel.errorMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_viewModel.errorMessage != null) {
              _showNotification(_viewModel.errorMessage!, isError: true);
              _viewModel.dismissMessages();
            }
          });
        } else if (_viewModel.successMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_viewModel.successMessage != null) {
              _showNotification(_viewModel.successMessage!);
              _viewModel.dismissMessages();
            }
          });
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Text('Tài khoản', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.page),

            // Card profile chính
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Column(
                  children: [
                    // Avatar với nút Camera và Firebase Storage upload
                    _buildAvatar(theme, profile, name),
                    const SizedBox(height: AppSpacing.medium),

                    // Tên hiển thị + Nút chỉnh sửa
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Đổi tên hiển thị',
                          onPressed: _showEditNameDialog,
                        ),
                      ],
                    ),

                    if (profile.email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.email,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.medium),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.medium),

                    // Liên kết GitHub
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.small,
                      children: [
                        Image.asset(
                          'assets/logo/github-logo.png',
                          width: 20,
                          height: 20,
                          excludeFromSemantics: true,
                        ),
                        Text(
                          'Đăng nhập bằng GitHub',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (widget.onReconnectGitHub != null) ...[
              const SizedBox(height: AppSpacing.page),
              Text(
                'Phiên Vista đã được khôi phục. Kết nối lại GitHub để tải repository và CI.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.medium),
              AppButton(
                label: 'Kết nối lại GitHub',
                onPressed: widget.onReconnectGitHub,
                isLoading: widget.isSigningOut,
                icon: Icons.link,
              ),
            ],

            const SizedBox(height: AppSpacing.page),

            // Thông tin chi tiết hệ thống
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                  vertical: AppSpacing.medium,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông tin tài khoản',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.medium),

                    // Vai trò
                    _buildInfoRow(
                      icon: Icons.shield_outlined,
                      label: 'Vai trò',
                      valueWidget: _buildRoleBadge(profile.role),
                    ),
                    const Divider(height: 24),

                    // Trạng thái
                    _buildInfoRow(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Trạng thái',
                      valueWidget: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: profile.isActive
                              ? AppColors.successContainer
                              : AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          profile.isActive ? 'Đang hoạt động' : 'Vô hiệu hóa',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: profile.isActive
                                ? AppColors.onSuccessContainer
                                : AppColors.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 24),

                    // UID với nút copy
                    _buildInfoRow(
                      icon: Icons.fingerprint_rounded,
                      label: 'User ID (UID)',
                      valueWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              profile.uid.length > 12
                                  ? '${profile.uid.substring(0, 10)}…'
                                  : profile.uid,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            tooltip: 'Sao chép UID',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: profile.uid));
                              _showNotification('Đã sao chép UID vào bộ nhớ tạm');
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 24),

                    // Lưu trữ đám mây
                    _buildInfoRow(
                      icon: Icons.cloud_done_outlined,
                      label: 'Firebase Storage',
                      valueWidget: Text(
                        profile.photoUrl != null
                          ? 'Đã đồng bộ ảnh'
                          : 'Sẵn sàng tải ảnh',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.page),

            if (widget.configuration != null || widget.telemetry != null)
              AppSettingsPanel(
                configuration: widget.configuration,
                telemetry: widget.telemetry,
                onDebugCrash: widget.onDebugCrash,
              ),

            if (widget.configuration != null || widget.telemetry != null)
              const SizedBox(height: AppSpacing.page),

            // Nút đăng xuất
            AppButton(
              label: 'Đăng xuất',
              loadingLabel: 'Đang đăng xuất…',
              icon: Icons.logout,
              variant: AppButtonVariant.secondary,
              isLoading: widget.isSigningOut,
              onPressed: widget.onSignOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvatar(ThemeData theme, UserProfile profile, String name) {
    const double radius = 48.0;
    final photoUrl = profile.photoUrl;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      width: radius * 2,
                      height: radius * 2,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: theme.colorScheme.primaryContainer,
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          _buildInitialsAvatar(theme, name, radius),
                    )
                  : _buildInitialsAvatar(theme, name, radius),
            ),
          ),
          // Loading overlay khi đang tải ảnh lên Firebase Storage
          if (_viewModel.isUploadingAvatar)
            Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child: const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),

          // Nút Camera ở góc dưới avatar
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: theme.colorScheme.primary,
              shape: const CircleBorder(),
              elevation: 3,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _viewModel.isUploadingAvatar ? null : _showAvatarOptions,
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(ThemeData theme, String name, double radius) {
    final initial = name.characters.isNotEmpty
        ? name.characters.first.toUpperCase()
        : 'V';
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required Widget valueWidget,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 280) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelWidget,
              const SizedBox(height: 6),
              valueWidget,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: labelWidget),
            const SizedBox(width: 8),
            Flexible(child: Align(alignment: Alignment.centerRight, child: valueWidget)),
          ],
        );
      },
    );
  }

  Widget _buildRoleBadge(Role role) {
    final isAdmin = role == Role.admin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.tertiaryContainer
            : AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isAdmin ? 'Quản trị viên' : 'Thành viên',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isAdmin
              ? AppColors.onTertiaryContainer
              : AppColors.onPrimaryContainer,
        ),
      ),
    );
  }
}
