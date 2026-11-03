import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vista_mobile/data/models/user_profile.dart';

void main() {
  test('Role parsing accepts stored values and rejects unknown values', () {
    expect(Role.fromFirestore('user'), Role.user);
    expect(Role.fromFirestore('admin'), Role.admin);

    for (final value in <Object?>[null, 'owner', 'USER', 1, true]) {
      expect(Role.fromFirestore(value), Role.unknown);
    }
  });

  test('New profiles serialize to primitive values with user defaults', () {
    const data = CreateProfileData(displayName: 'Linh');

    expect(jsonDecode(jsonEncode(data.toFirestore())), {
      'displayName': 'Linh',
      'role': 'user',
      'isActive': true,
    });
  });

  test('Profile creation preserves explicit role and activation values', () {
    const data = CreateProfileData(
      displayName: 'Linh',
      role: Role.admin,
      isActive: false,
    );

    expect(data.toFirestore(), {
      'displayName': 'Linh',
      'role': 'admin',
      'isActive': false,
    });
  });

  test('An unknown role cannot be written to Firestore', () {
    const data = CreateProfileData(displayName: 'Linh', role: Role.unknown);

    expect(data.toFirestore, throwsStateError);
  });

  test('Profile reading combines identity with stored profile data', () {
    final profile = UserProfile.fromFirestore(
      uid: 'firebase-uid',
      email: 'linh@example.com',
      data: {'displayName': 'Linh', 'role': 'user', 'isActive': true},
    );

    expect(profile.uid, 'firebase-uid');
    expect(profile.email, 'linh@example.com');
    expect(profile.displayName, 'Linh');
    expect(profile.role, Role.user);
    expect(profile.isActive, isTrue);
  });

  test('Missing or malformed profile data never defaults to active access', () {
    for (final data in <Map<String, dynamic>>[
      {},
      {'displayName': 1, 'role': 'owner', 'isActive': 'true'},
    ]) {
      final profile = UserProfile.fromFirestore(
        uid: 'firebase-uid',
        email: '',
        data: data,
      );

      expect(profile.displayName, '');
      expect(profile.role, Role.unknown);
      expect(profile.isActive, isFalse);
    }
  });

  test('Reading an inactive profile keeps it inactive', () {
    final profile = UserProfile.fromFirestore(
      uid: 'firebase-uid',
      email: '',
      data: {'displayName': 'Linh', 'role': 'user', 'isActive': false},
    );

    expect(profile.role, Role.user);
    expect(profile.isActive, isFalse);
  });
}
