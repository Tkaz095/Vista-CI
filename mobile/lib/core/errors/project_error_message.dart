import 'package:firebase_core/firebase_core.dart';

String projectErrorMessage(Object error) {
  if (error is ArgumentError) return error.message.toString();
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'Chưa có quyền truy cập project. Hãy đăng nhập lại hoặc liên hệ người quản trị.',
      'unavailable' =>
        'Không kết nối được Firestore. Hãy kiểm tra mạng rồi thử lại.',
      'not-found' => 'Project không còn tồn tại. Hãy tải lại danh sách.',
      _ => 'Chưa hoàn tất thao tác với project. Hãy thử lại.',
    };
  }
  return 'Chưa hoàn tất thao tác với project. Hãy thử lại.';
}
