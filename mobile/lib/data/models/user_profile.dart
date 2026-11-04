enum Role {
  admin,
  user,
  unknown;

  static Role fromFirestore(Object? value) {
    return switch (value) {
      'admin' => Role.admin,
      'user' => Role.user,
      _ => Role.unknown,
    };
  }

  String toFirestore() {
    if (this == Role.unknown) {
      throw StateError('Cannot save an unknown role');
    }
    return name;
  }
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    this.photoUrl,
  });

  factory UserProfile.fromFirestore({
    required String uid,
    required String email,
    required Map<String, dynamic> data,
    String? authPhotoUrl,
  }) {
    final displayName = data['displayName'];
    final photoUrl = data['photoUrl'] ?? authPhotoUrl;

    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName is String ? displayName.trim() : '',
      role: Role.fromFirestore(data['role']),
      isActive: data['isActive'] == true,
      photoUrl: photoUrl is String && photoUrl.trim().isNotEmpty
          ? photoUrl.trim()
          : null,
    );
  }

  final String uid;
  final String email;
  final String displayName;
  final Role role;
  final bool isActive;
  final String? photoUrl;

  UserProfile copyWith({
    String? displayName,
    String? photoUrl,
    bool clearPhotoUrl = false,
    Role? role,
    bool? isActive,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'role': role.toFirestore(),
      'isActive': isActive,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
  }
}

class CreateProfileData {
  const CreateProfileData({
    required this.displayName,
    this.role = Role.user,
    this.isActive = true,
    this.photoUrl,
  });

  final String displayName;
  final Role role;
  final bool isActive;
  final String? photoUrl;

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'role': role.toFirestore(),
      'isActive': isActive,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
  }
}
