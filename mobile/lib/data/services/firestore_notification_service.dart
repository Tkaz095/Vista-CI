import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';

abstract interface class NotificationHistory {
  Stream<List<AppNotification>> watch(String uid);
  Future<void> receive(String uid, AppNotification notification);
  Future<void> markRead(String uid, String id);
  Future<void> saveRegistration(String uid, String fid);
  Future<void> removeRegistration(String uid);
}

class FirestoreNotificationService implements NotificationHistory {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  void _check(String uid) {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Session changed');
    }
  }

  CollectionReference<Map<String, dynamic>> _inbox(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');
  @override
  Stream<List<AppNotification>> watch(String uid) {
    _check(uid);
    return _inbox(uid)
        .orderBy('received_at', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          _check(uid);
          return snapshot.docs
              .map(
                (doc) => AppNotification.parse({
                  ...doc.data(),
                  'notification_id': doc.id,
                }),
              )
              .where((item) => item != null && item.uid == uid)
              .cast<AppNotification>()
              .toList();
        });
  }

  @override
  Future<void> receive(String uid, AppNotification notification) async {
    _check(uid);
    if (notification.uid != uid) return;
    final ref = _inbox(uid).doc(notification.id);
    await _db
        .runTransaction((transaction) async {
          final existing = await transaction.get(ref);
          _check(uid);
          if (!existing.exists) {
            transaction.set(ref, {...notification.toJson(), 'read': false});
          }
        })
        .timeout(const Duration(seconds: 15));
  }

  @override
  Future<void> markRead(String uid, String id) async {
    _check(uid);
    await _inbox(uid)
        .doc(id)
        .update({'read': true})
        .timeout(const Duration(seconds: 15));
  }

  Future<String>? _installationId;
  Future<String> _installation() => _installationId ??= _loadInstallation();
  Future<String> _loadInstallation() async {
    final prefs = SharedPreferencesAsync();
    final current = await prefs.getString('fcm_installation_id');
    if (current != null) return current;
    final random = Random.secure();
    final id = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await prefs.setString('fcm_installation_id', id);
    return id;
  }

  @override
  Future<void> saveRegistration(String uid, String fid) async {
    final installation = await _installation();
    _check(uid);
    await _db
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(installation)
        .set({
          'fid': fid,
          'platform': 'android',
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 15));
  }

  @override
  Future<void> removeRegistration(String uid) async {
    final installation = await _installation();
    _check(uid);
    await _db
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(installation)
        .delete()
        .timeout(const Duration(seconds: 5));
  }
}
