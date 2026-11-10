import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/user_profile.dart';
import '../../data/repositories/auth_repository.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    required this.profile,
    required this.repository,
    this.onProfileUpdated,
  });

  final AuthRepository repository;
  final void Function(UserProfile)? onProfileUpdated;
  final ImagePicker _picker = ImagePicker();

  UserProfile profile;

  bool _isUploadingAvatar = false;
  bool get isUploadingAvatar => _isUploadingAvatar;

  bool _isUpdatingName = false;
  bool get isUpdatingName => _isUpdatingName;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  bool _disposed = false;

  void updateInternalProfile(UserProfile newProfile) {
    profile = newProfile;
    if (!_disposed) notifyListeners();
  }

  Future<void> pickAndUploadAvatar(ImageSource source) async {
    _clearMessages();
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      _isUploadingAvatar = true;
      notifyListeners();

      final Uint8List bytes = await pickedFile.readAsBytes();
      final String extension = pickedFile.name.split('.').lastOrNull ?? 'jpg';

      final String downloadUrl = await repository.uploadAvatar(
        uid: profile.uid,
        bytes: bytes,
        fileExtension: extension,
      );

      profile = profile.copyWith(photoUrl: downloadUrl);
      onProfileUpdated?.call(profile);
      _successMessage = 'Tải ảnh đại diện lên Firebase Storage thành công!';
    } catch (e) {
      _errorMessage = 'Không thể tải ảnh lên Firebase Storage: $e';
    } finally {
      _isUploadingAvatar = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> removeAvatar() async {
    if (profile.photoUrl == null) return;
    _clearMessages();
    _isUploadingAvatar = true;
    notifyListeners();

    try {
      await repository.removeAvatar(
        uid: profile.uid,
        currentUrl: profile.photoUrl,
      );
      profile = profile.copyWith(clearPhotoUrl: true);
      onProfileUpdated?.call(profile);
      _successMessage = 'Đã xóa ảnh đại diện thành công.';
    } catch (e) {
      _errorMessage = 'Không thể xóa ảnh đại diện: $e';
    } finally {
      _isUploadingAvatar = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> updateDisplayName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Tên hiển thị không được để trống.';
      notifyListeners();
      return false;
    }
    if (trimmed == profile.displayName) return true;

    _clearMessages();
    _isUpdatingName = true;
    notifyListeners();

    try {
      await repository.updateDisplayName(
        uid: profile.uid,
        displayName: trimmed,
      );
      profile = profile.copyWith(displayName: trimmed);
      onProfileUpdated?.call(profile);
      _successMessage = 'Cập nhật tên hiển thị thành công!';
      return true;
    } catch (e) {
      _errorMessage = 'Không thể cập nhật tên hiển thị: $e';
      return false;
    } finally {
      _isUpdatingName = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  void dismissMessages() {
    _clearMessages();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
