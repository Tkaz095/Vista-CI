import 'package:go_router/go_router.dart';
import 'package:vista_mobile/ui/auth/auth_view.dart';

// Khởi tạo router toàn cục
final goRouter = GoRouter(
  initialLocation: '/login', // Màn hình đầu tiên khi mở app
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginView(),
    ),
    // Sau này làm màn hình Dashboard, bạn chỉ cần add thêm vào đây:
    // GoRoute(
    //   path: '/dashboard',
    //   builder: (context, state) => const DashboardView(),
    // ),
  ],
);