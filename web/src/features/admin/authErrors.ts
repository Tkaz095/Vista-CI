export function authErrorMessage(error: unknown): string {
  const code = typeof error === 'object' && error !== null && 'code' in error
    ? String(error.code) : ''
  switch (code) {
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
    case 'auth/user-not-found':
    case 'auth/invalid-email':
      return 'Email hoặc mật khẩu không đúng. Vui lòng kiểm tra lại.'
    case 'auth/too-many-requests':
      return 'Có quá nhiều lần thử đăng nhập. Vui lòng thử lại sau.'
    case 'auth/network-request-failed':
      return 'Không kết nối được dịch vụ đăng nhập. Kiểm tra mạng rồi thử lại.'
    case 'auth/user-disabled':
      return 'Tài khoản đã bị vô hiệu hóa. Vui lòng liên hệ người quản trị.'
    case 'auth/operation-not-allowed':
      return 'Đăng nhập Email/Password chưa được bật trên Firebase.'
    default:
      return 'Chưa thể hoàn tất thao tác đăng nhập. Vui lòng thử lại.'
  }
}
