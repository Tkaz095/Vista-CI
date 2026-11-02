# Vista CI — Flutter handover

**Hiện hành: Bước 18 ở cuối file và `docs/project/18-cicd-screen.md`.** Ba tab Workspace/CI-CD/Tài khoản, ownerUid và role user; bảng khởi tạo và các mốc trước dưới đây là lịch sử.

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

## Bước 17 — Workspace cá nhân

WorkspaceRepository đã tách file riêng: query ownerUid, create batch, edit, remove theo trạng thái deleting; WorkspaceViewModel quan sát server và bỏ callback cũ. WorkspaceScreen có create/edit và ba tab Workspace/Repo/Tài khoản; RepositoryCard xử lý edit/remove link. features/github tách API/token memory, ViewModel phân trang và panel chọn/tải repo. Token lấy từ sign-in/link/reauth native Firebase, không ghi disk/Firestore. Thêm dependencies http/url_launcher, cold restart sau pub get. Chi tiết publish Rules, quyền private và giới hạn kiểm tra ở tài liệu 17. Các ánh xạ Run/Audit và membership trong mốc cũ chưa áp dụng cho UI hiện hành.

## Bước 18 — Màn CI/CD riêng

Điều hướng hiện tại: Workspace | CI/CD | Tài khoản. Danh sách GitHub repo được giữ trong Tài khoản để thêm vào workspace. features/cicd có ViewModel phân trang theo repo, concurrency tối đa 3, filter branch/status phía GitHub, tách status/conclusion, báo lỗi riêng từng repo và bỏ callback cũ bằng generation. Màn CI/CD dùng ScrollPage, chọn repo trong workspace, refresh/tải thêm và mở job/log trên trình duyệt ngoài. Chi tiết và giới hạn tại docs/project/18-cicd-screen.md. Không đổi Firebase Rules/schema trong bước này; chưa có PR/job/log detail trong app, agent/actions/audit/FCM.

## Bước21 — Web GitHub auto-refresh

Web đã chuyển sang backend OAuth/vault/refresh, còn chờ cấu hình và nghiệm thu; Flutter chưa chuyển, vẫn token memory. API web gửi Firebase ID token cho backend để lấy repo/runs/jobs/log; không trả cặp token GitHub cho client. Chi tiết ở docs/project/21-github-auto-refresh.md. Không coi thay đổi web là xác nhận native OAuth/refresh đã hoạt động.

## Bước22 — Flutter dùng backend chung

BackendClient gửi Firebase ID token, từ chối redirect và URL HTTP ngoài loopback debug. GitHubRepository gọi repos/runs/jobs/log/connection, không giữ GitHub token. BackendPanel cấu hình URL + quản lý kết nối. Browser OAuth dùng ticket một lần và polling request có UID; không đưa secret vào app. WorkspaceScreen thêm repo tại chỗ, mở đúng CI, lưu metadata navigation theo UID; RunDetailViewModel/JobLogViewModel đọc job/step/log đúng attempt, bỏ callback sau dispose. GitHubViewModel có generation reset khi đổi backend/kết nối. SharedPreferences chỉ lưu URL/navigation, không credential. Android HTTP loopback chỉ ở debug manifest. Xem tài liệu22 và checklist thật; chưa chứng minh runtime trên điện thoại vì ADB chưa thấy device ở lúc kiểm tra.
