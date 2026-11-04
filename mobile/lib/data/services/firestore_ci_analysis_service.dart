import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ci_analysis.dart';

class FirestoreCiAnalysisService {
  String? _ownerUid;

  DocumentReference<Map<String, dynamic>> _document(String id) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw const CiAnalysisException('Cần đăng nhập để lưu và đọc phân tích.');
    }
    if (_ownerUid != null && _ownerUid != uid) {
      throw const CiAnalysisException(
        'Tài khoản đã thay đổi. Hãy mở lại lần chạy CI.',
      );
    }
    _ownerUid = uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('ciAnalyses')
        .doc(id);
  }

  Future<Map<String, dynamic>?> read(String id) async {
    try {
      // Recheck server permissions rather than silently using a disk cache.
      final snapshot = await _document(id)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
      if (FirebaseAuth.instance.currentUser?.uid != _ownerUid) {
        throw const CiAnalysisException(
          'Tài khoản đã thay đổi. Hãy mở lại lần chạy CI.',
        );
      }
      return snapshot.data();
    } catch (error) {
      throw CiAnalysisException(errorMessage(error, action: 'đọc'));
    }
  }

  Future<void> save(CiAnalysis analysis) async {
    try {
      await _document(analysis.documentId)
          .set({...analysis.toJson(), 'savedAt': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      throw CiAnalysisException(errorMessage(error, action: 'lưu'));
    }
  }

  static String errorMessage(Object error, {required String action}) {
    if (error is CiAnalysisException) return error.message;
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Firestore chưa cho phép $action phân tích. Kiểm tra và Publish Rules cho ciAnalyses cùng quyền hồ sơ của tài khoản. (permission-denied)';
      }
      if (error.code == 'unauthenticated') {
        return 'Phiên Firebase chưa hợp lệ để $action phân tích. Hãy đăng nhập lại. (unauthenticated)';
      }
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return 'Chưa kết nối được Firestore để $action phân tích. Kiểm tra mạng rồi kéo xuống làm mới. (${error.code})';
      }
      return 'Chưa $action được phân tích trong Firestore. Mã lỗi: ${error.code}.';
    }
    return 'Chưa $action được phân tích trong Firestore. Kiểm tra kết nối rồi thử lại.';
  }
}
