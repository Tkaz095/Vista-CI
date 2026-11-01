# Vista CI — Flutter handover

Ngày 01/11/2026. Design tham chiếu: `docs/DESIGN.md`. Android package: `com.vista.vista_mobile`.

## Kiến trúc và ánh xạ màn hình

| Màn | Code | Trạng thái |
|---|---|---|
| Auth/session gate | `mobile/lib/main.dart`, `features/auth/session_view_model.dart` | Auth Firebase + profile stream |
| S-AUTH-LOGIN | `features/auth/session_views.dart` | Email/password, validation, lỗi/loading, cuộn |
| S-WS-PICK | `features/workspaces/workspace_screen.dart` | Đọc workspace theo memberUids, chọn/chuyển workspace |
| S-REPO-LIST | cùng WorkspaceScreen | Đọc subcollection repositories, chưa gọi GitHub |
| S-ACCOUNT | cùng WorkspaceScreen | Hồ sơ thật, logout |
| S-RUN-LIST / S-AUDIT-LIST | cùng WorkspaceScreen | Chỉ trạng thái chưa kết nối |

Repository đóng gói Firebase SDK; ChangeNotifier ViewModel quản lý phiên/subscription/selected workspace; View chỉ render và gọi các hành động. Model nằm gần ViewModel theo feature. Chưa cần service locator hoặc thư viện state management riêng cho quy mô này.

## Hành vi phải giữ

- Không có phiên: login. Có phiên: xác minh `users/{uid}` từ server trước khi mở dữ liệu; không dùng cache/pending write để cấp quyền.
- Hồ sơ phải active và role admin/member. Rules mới là lớp bảo vệ dữ liệu, UI gate không thay thế Rules.
- Hủy subscription khi logout, đổi workspace, retry hoặc dispose; bỏ callback cũ bằng generation. Khi workspace không còn trong danh sách, bỏ lựa chọn và repository cũ.
- Tách lỗi quyền/lỗi mạng khỏi empty state; timeout máy chủ 15 giây, có retry.
- Form dùng SingleChildScrollView, danh sách dùng ListView trong vùng chiều cao hữu hạn, bàn phím adjustResize; hỗ trợ chuột trên Genymotion. Bottom navigation bốn tab.
- Màu primary #2563EB, background #F8FAFC, target nút tối thiểu 48px. Chưa đóng gói Inter/Phosphor: hiện dùng font hệ thống và Material Icons. Chưa tuyên bố hoàn thiện toàn bộ DESIGN.md.

## Cấu hình bên ngoài

`google-services.json` cho Android đã có. Auth/Firestore plugin khai báo pubspec, Internet permission trong manifest main. Chưa cấu hình iOS hay Flutter Web; web hiện là React/Vite riêng.

Người dùng tự publish Rules và tạo workspace/repo theo `docs/project/12-mobile-auth-workspaces.md`. Không đổi Firebase/GitHub bằng thao tác tự động. Chưa triển khai backend, đồng bộ CI/log, agent, quick action, audit hay push notification.

## Bước 13 — GitHub sign-in

AuthRepository đã có `loginWithGitHub`, `linkGitHub` và getter `githubLinked`. Login dùng native Firebase provider; màn Tài khoản có GitHubAccountActions để link provider trên user hiện có. Đọc checklist cấu hình SHA-1 và liên kết UID tại `docs/project/13-github-sign-in.md`. Chưa gọi GitHub API hay lưu credential; chưa xác minh OAuth thực tế.

## Cập nhật 02/11/2026 — User only

Mọi hồ sơ mới dùng role `user`. SessionViewModel/transaction tự chuyển role cũ về user nếu hồ sơ active; không thay isActive. Dùng Rules và tài liệu bước 15. Phần Admin/Member trong các mốc trước không còn áp dụng cho cổng đăng nhập hiện tại.
