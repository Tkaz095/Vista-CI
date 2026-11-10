# Vista — Bước đăng nhập Web

Ngày 01/11/2026. Người dùng yêu cầu Codex triển khai code, còn các thao tác Firebase Console/GitHub/dịch vụ bên ngoài do người dùng thực hiện theo hướng dẫn.

## Code đã thêm

- `web/src/features/auth/authService.ts`: đăng nhập Email/Password, đăng xuất, observe phiên Auth và hồ sơ `users/{uid}`.
- `useAuthSession.ts`: quản lý state phiên và vòng đời subscription, kiểm tra lại khi lỗi.
- `LoginScreen.tsx`: form email/mật khẩu, validation, hiện/ẩn mật khẩu, loading và lỗi bằng tiếng Việt.
- `auth.css`: trang đăng nhập và hồ sơ theo palette/style trên main; Inter dùng font stack hiện có, chưa thêm asset font.
- `web/src/App.tsx`: cổng session/profile, màn hình thiếu quyền/lỗi và trang hồ sơ thật có nút đăng xuất. Workspace mẫu không phải dữ liệu sau đăng nhập thật.

Luồng: khôi phục phiên → chưa đăng nhập thì form → Firebase Auth xác thực → lắng nghe hồ sơ server → kiểm tra existence/isActive/role → trang hồ sơ. Role chỉ nhận `admin` hoặc `member`; không tự tạo hoặc sửa hồ sơ. Không đặt mật khẩu/token vào localStorage, log hoặc Firestore của ứng dụng; SDK quản lý session theo cấu hình mặc định.

Không lấy snapshot cache hoặc pending writes làm bằng chứng cấp quyền. Nếu chưa xác minh server sau 15 giây, hiện lỗi để kiểm tra lại; listener vẫn có thể nhận kết quả khi kết nối phục hồi. Thay đổi hồ sơ server có thể chặn quyền UI; thay đổi Auth account/unmount hủy listener và bỏ callback cũ. Việc vô hiệu tài khoản ở Firebase Authentication còn phụ thuộc SDK refresh/revocation, không hứa phát hiện tức thì chỉ từ profile listener.

## Phần người dùng đã báo hoàn thành

Đã đăng ký Web, thêm Firebase config và `auth`/`db`, bật Email/Password, tạo tài khoản Authentication, tạo `users/{UID}` có `displayName`, `role`, `isActive` và publish Rules cho phép đọc hồ sơ chính mình. Người dùng đã xác nhận web đăng nhập và hiển thị đúng thông tin tài khoản. Codex không đăng nhập bằng credential của người dùng.

## Bước người dùng làm tiếp

1. Mở Web local và đăng nhập bằng tài khoản đã tạo. Không gửi mật khẩu trong chat.
2. Kết quả mong đợi: trang tài khoản hiện đúng tên, email, Admin/Member và UID từ Firebase.
3. Đăng xuất để quay về form. Nếu có lỗi, gửi thông báo lỗi đã hiện; không cần gửi credential.
4. Sau khi xác nhận luồng này hoạt động, chốt schema/membership và Rules cho workspace trước khi nối dữ liệu đó. Không dùng Rules đọc hồ sơ để mở quyền toàn bộ workspace hoặc ghi dữ liệu CI.

Nếu default Node trên máy vẫn là 18, dùng Node 24 sẵn có để chạy Vite, không cần nâng Node hệ thống:

```sh
cd /home/kien/FPTU/Semester-8/PRM393/Lab3-Assignment/Vista-CI/web
/home/kien/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node node_modules/vite/bin/vite.js --host localhost
```

## Giới hạn bằng chứng

Chưa chạy build/lint/tests hoặc thử đăng nhập tài khoản thật trong bước này. Chưa sửa Firebase Console, Rules, tạo workspace, gọi GitHub/AI, commit/push hoặc deploy. UI workspace mẫu vẫn dùng thiết kế prototype cũ; thay header/filter và Flutter được làm ở bước triển khai tương ứng, không tuyên bố đã hoàn thành toàn bộ DESIGN.md.

## Cập nhật bước 12

Web đã được nối màn chọn workspace/repository thật theo membership. Hướng dẫn và schema hiện hành: `12-mobile-auth-workspaces.md`. Phần hướng dẫn workspace ở trên mô tả mốc trước khi triển khai bước 12.
