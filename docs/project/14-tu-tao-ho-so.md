# Bước 14 — Tự tạo hồ sơ lần đầu

Ngày 02/11/2026.

## Luồng hiện tại

GitHub/Email đăng nhập → Firebase tự xác định UID → đọc hồ sơ server → nếu thiếu, tạo hồ sơ Member → chờ hồ sơ được xác nhận từ server → mở màn workspace.

Người dùng không nhập UID, không cần tạo document thủ công trong Firebase Console. Hồ sơ mới chỉ có ba trường:

```json
{
  "displayName": "Tên từ GitHub hoặc tên dự phòng",
  "role": "member",
  "isActive": true
}
```

Tên lấy từ Auth displayName, fallback phần trước @ của email, rồi `Thành viên Vista`; trim và giới hạn 100 ký tự. UID tiếp tục được dùng làm document ID nội bộ.

## Code

- Web `features/auth/authService.ts`: `ensureOwnProfile` dùng Firestore transaction; observeSession gọi sau snapshot server xác nhận document chưa tồn tại.
- Mobile `features/auth/session_view_model.dart`: repository `ensureOwnProfile` tương ứng; ViewModel xử lý trạng thái chờ/tạo/lỗi/quyền như web.
- Transaction đọc lại document trước khi tạo để xử lý đăng nhập đồng thời từ nhiều client. Nếu đã có document thì không ghi đè role, tên hoặc isActive. Không tự kích hoạt lại tài khoản bị khóa.
- Không tạo từ cache hoặc pending write. Không cấp quyền UI chỉ từ dữ liệu hồ sơ mặc định; chờ server snapshot thực tế rồi kiểm tra isActive/role.
- Mỗi phiên quan sát chỉ thử tạo một lần; thất bại có nút Kiểm tra lại. Giữ timeout 15 giây; mạng phục hồi vẫn có thể nhận kết quả server sau đó.
- Khi logout/retry/dispose, callback cũ không cập nhật UI. Transaction kiểm tra phiên hiện hành trước khi lên lịch ghi; request đã gửi không được xem là có thể hủy tuyệt đối.

## Firebase — người dùng publish

File `firebase/firestore.rules` đã cập nhật giống block self-create được hướng dẫn trong chat:

- Chỉ request.auth.uid trùng document ID được tạo hồ sơ.
- Bắt buộc đúng ba trường displayName/role/isActive, tên 1–100 ký tự.
- Chỉ được tạo role `member`, isActive true; update/delete vẫn bị chặn từ client.
- Workspace/repository tiếp tục kiểm tra membership; không cấp workspace cho mọi người có hồ sơ.

Mở Firestore → Rules, đối chiếu và publish file mới. Codex chưa publish hoặc kiểm tra Rules đang chạy trên Console. Không tạo/xóa tài khoản để thử, không xóa hồ sơ đang inactive; tài khoản bị khóa vẫn phải qua quy trình quản trị.

## Thử sau khi publish

1. Web: tải lại trang đang chạy code mới; bấm Kiểm tra lại hồ sơ nếu đang ở màn lỗi, hoặc đăng nhập GitHub.
2. Mobile: dừng phiên cũ rồi `flutter run`; đăng nhập GitHub hoặc dùng phiên đang lưu.
3. Với tài khoản chưa có hồ sơ, mong đợi vào màn workspace và tab Tài khoản hiện role member. Hồ sơ phải tự xuất hiện trong Firestore dưới UID tương ứng.
4. Nếu chưa được thêm workspace, hiện trạng thái chưa có workspace; đây là đăng nhập thành công. Chức năng tự tạo workspace/gửi lời mời chưa triển khai, không có nút giả báo thành công.
5. Hồ sơ đã tồn tại phải giữ dữ liệu cũ; hồ sơ isActive false vẫn bị chặn. Đây là các trường hợp cần kiểm tra với Firebase thật, chưa được xác nhận bằng build.

Tài khoản mới không kế thừa membership của tài khoản đã xóa dù cùng email. Hướng dẫn link ở bước 13 vẫn dùng khi tài khoản cũ còn tồn tại và người dùng muốn giữ UID. Luồng mới không bắt buộc link Email/Password để sử dụng GitHub độc lập.

## Giới hạn kiểm tra

Không chạy tests hoặc đăng nhập Firebase thật trong bước này. Fake repository test UI cũ chỉ được bổ sung phương thức để khớp interface, không thêm test case. Build/analyze local không chứng minh Rules đã publish hay auto-create đã chạy thành công trên cloud.

### Kết quả local

Flutter analyze không có issue; build Android debug APK x64 thành công. Web TypeScript/Vite build và ESLint thành công. `git diff --check` sạch. Cảnh báo bundle web >500kB và FlutterFire/Kotlin cho Flutter tương lai vẫn còn. Không có phiên Flutter run/Vite do Codex mở ở bước này; chưa commit/push/deploy.
