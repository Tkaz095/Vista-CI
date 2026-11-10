import 'package:firebase_auth/firebase_auth.dart';

String authErrorMessage(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Chưa có quyền đọc hoặc cập nhật hồ sơ Vista. Liên hệ người quản trị.';
  }
  if (error is! FirebaseAuthException) {
    return 'Chưa hoàn tất thao tác. Kiểm tra kết nối rồi thử lại.';
  }

  return switch (error.code) {
    'secure-storage-unavailable' => 'Chưa truy cập được bộ nhớ bảo mật. Hãy thử lại thao tác; nếu đang kết nối GitHub, phiên hiện tại vẫn có thể sử dụng.',
    'user-mismatch' => 'Hãy chọn tài khoản GitHub đang liên kết với phiên Vista này. Để đổi tài khoản, hãy đăng xuất trước.',
    'network-request-failed' || 'web-network-request-failed' =>
      'Không kết nối được dịch vụ đăng nhập. Kiểm tra mạng rồi thử lại.',
    'web-context-cancelled' ||
    'web-context-canceled' ||
    'popup-closed-by-user' ||
    'cancelled-popup-request' => 'Bạn đã hủy đăng nhập GitHub. Có thể thử lại.',
    'too-many-requests' => 'Bạn đã thử quá nhiều lần. Vui lòng thử lại sau.',
    'user-disabled' => 'Tài khoản đã bị vô hiệu hóa.',
    'account-exists-with-different-credential' || 'email-already-in-use' => 'Email này đã có tài khoản Vista với phương thức đăng nhập khác. Liên hệ hỗ trợ để liên kết GitHub và giữ hồ sơ cũ.',
    'operation-not-allowed' ||
    'invalid-oauth-client-id' ||
    'invalid-oauth-provider' ||
    'invalid-cert-hash' =>
      'Cấu hình đăng nhập GitHub chưa hợp lệ. Liên hệ người quản trị.',
    _ => 'Chưa đăng nhập được. Vui lòng thử lại.',
  };
}
