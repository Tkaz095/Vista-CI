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
  });

  factory UserProfile.fromFirestore({
    required String uid,
    required String email,
    required Map<String, dynamic> data,
  }) {
    final displayName = data['displayName'];

    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName is String ? displayName : "Unknow name",
      role: Role.fromFirestore(data['role']),
      isActive: data['isActive'] == true,
    );
  }

  final String uid;
  final String email;
  final String displayName;
  final Role role;
  final bool isActive;
}

class CreateProfileData {
  const CreateProfileData({
    required this.displayName,
    this.role = Role.user,
    this.isActive = true,
  });

  final String displayName;
  final Role role;
  final bool isActive;

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'role': role.toFirestore(),
      'isActive': isActive,
    };
  }
}

class ProfileObservation {
  const ProfileObservation({
    required this.profile,
    required this.serverConfirmed,
  });

  final UserProfile? profile;
  final bool serverConfirmed;
}