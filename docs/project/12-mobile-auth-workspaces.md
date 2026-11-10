# Bước 12 — Mobile Auth và workspace dùng chung Web

Ngày cập nhật: 01/11/2026.

## Kết quả code

- Mobile: bỏ Home tĩnh khỏi route khởi động; kiểm tra Auth → xác minh hồ sơ server → chọn workspace. Chưa có phiên thì mở đăng nhập. Phiên hợp lệ được Firebase SDK khôi phục nên không yêu cầu đăng nhập mỗi lần mở app.
- Đăng nhập Email/Password, lỗi tiếng Việt, hiện/ẩn mật khẩu; đọc `users/{uid}`, chặn nếu thiếu/isActive không true/role không hợp lệ; có kiểm tra lại và đăng xuất.
- Form dùng SingleChildScrollView để giữ đầy đủ trường validation; các danh sách dùng ListView trong vùng có chiều cao hữu hạn và SafeArea; hỗ trợ kéo bằng chuột trên emulator, cuộn khi bàn phím mở. Home cũ đã dùng ListView nên chưa đủ bằng chứng quy nguyên nhân không cuộn về thiếu ScrollView.
- Mobile dùng bottom tabs Run / Repo / Hoạt động / Tài khoản. Web dùng header navigation.
- Hai client đọc tối đa 50 workspace có UID thành viên và tối đa 50 repository/workspace. Danh sách cập nhật qua Firestore snapshot. Chưa có phân trang: thêm sau khi cần mở rộng dữ liệu.
- Run và Hoạt động là trạng thái chưa kết nối, chưa có dữ liệu CI hoặc audit thật. Repository là cấu hình đăng ký trên Vista, không chứng minh đã cấp quyền GitHub hay repo tồn tại.
- Web đăng nhập và thông tin hồ sơ đã được người dùng xác nhận hoạt động trước bước này. Codex không dùng mật khẩu của người dùng.

## Bạn thao tác trên Firebase Console

### 1. Publish Rules

Mở **Firestore Database → Rules**. Thay nội dung bằng file `firebase/firestore.rules` trong repo rồi bấm **Publish**.

Rules giữ quyền đọc hồ sơ chính mình; chỉ tài khoản có hồ sơ active và role hợp lệ được đọc workspace chứa UID của mình. Đọc repository kiểm tra membership ở workspace cha. Mọi client write đều bị chặn. Vai trò `admin` của Vista không tự vượt qua membership, không đồng nghĩa là chủ repo GitHub.

Đây là file Rules để bạn review và publish thủ công; Codex chưa deploy. Nếu Console có Rules khác đã được nhóm bổ sung, đối chiếu trước khi thay để không mất các rule đó.

### 2. Tạo workspace

Mở **Data → Start collection**:

- Collection ID: `workspaces`
- Document ID: `vista-demo` (tự nhập cho dễ theo dõi)
- Các field:

| Field | Type | Giá trị mẫu |
|---|---|---|
| name | string | Vista CI |
| description | string | Workspace phát triển Vista |
| memberUids | array | phần tử string đầu tiên là UID tài khoản Firebase Authentication của bạn |

`memberUids` phải là **array**, mỗi UID là một string, không phải chuỗi các UID ngăn bởi dấu phẩy. Dùng UID giống document `users/{uid}` mà web đã đọc thành công.

### 3. Thêm repository

Chọn document `workspaces/vista-demo` → **Start collection**:

- Subcollection ID: `repositories`
- Document ID: `vista-ci`
- `name` (string): tên thật dạng `OWNER/REPOSITORY` của bạn.
- `description` (string): `Mobile Flutter và web Vista CI`.

Không nhập GitHub token/API key vào đây. Bước này chỉ tạo danh mục, chưa thực hiện tích hợp GitHub.

### 4. Kiểm tra trên hai client

1. Đăng nhập mobile bằng cùng tài khoản đã dùng ở web.
2. Chọn workspace Vista CI; mở tab Repo: thấy đúng tên repository vừa tạo.
3. Tab Tài khoản: đúng tên/email/role/UID. Đăng xuất: quay lại form.
4. Mở bàn phím ở ô mật khẩu trên màn hình nhỏ; kéo nội dung lên để thấy nút Đăng nhập.
5. Khi Rules chưa publish, app phải hiện lỗi quyền và nút thử lại, không báo danh sách trống.
6. Tài khoản khác không nằm trong memberUids không được đọc workspace hoặc repository bên trong. Tài khoản chưa có profile active bị chặn ở cổng Auth.

## Chạy mobile

```sh
cd /home/kien/FPTU/Semester-8/PRM393/Lab3-Assignment/Vista-CI/mobile
flutter pub get
flutter devices
flutter run -d 127.0.0.1:6562
```

Bật máy ảo Genymotion trước. Nếu ID thay đổi, dùng ID từ `flutter devices`. Nếu terminal không tìm thấy Flutter, dùng `/home/kien/development/flutter/bin/flutter` thay `flutter`.

Không qua Expo. Khi có plugin mới, cần dừng app rồi chạy lại để build native; hot reload không đủ. `q` trong terminal Flutter để dừng phiên chạy.

## Schema MVP và bước tiếp theo

Bản triển khai này dùng **memberUids ở workspace cha là nguồn membership duy nhất**, thay cho đề xuất members subcollection trong tài liệu định hướng trước đó. Không duy trì hai bảng quyền song song. Chi tiết vai trò theo workspace/invite sẽ được thiết kế khi triển khai quản lý thành viên. Với nhóm nhỏ trong MVP, array đơn giản hơn; khi tăng quy mô cần đổi schema và Rules cùng lúc.

Bước tiếp theo: kết nối GitHub qua backend tin cậy, kiểm tra quyền repo, đồng bộ workflow run/status/branch/thời gian và log. Chưa lưu token ở mobile/web/Firestore công khai. Chạy lại workflow, agent đọc log, issue/comment PR, audit và FCM chưa triển khai ở bước này. Agent provider vẫn chưa chọn, ưu tiên lựa chọn miễn phí; chưa gửi log ra dịch vụ AI.

## Bằng chứng kiểm tra

Xem kết quả kiểm tra được ghi sau khi chạy local ở cuối tài liệu. Kiểm tra bằng fake repository hoặc phân tích tĩnh không thay thế đăng nhập và membership thực tế trên Firebase sau khi bạn publish Rules.

### Kết quả local tại bước này

- `flutter pub get`: thành công, lockfile đã cập nhật.
- `flutter analyze`: không có issue.
- `flutter test`: 4/4 bài qua; fake repository, không gửi credential tới Firebase. Bao gồm route signed-out, form với inset bàn phím, kéo bằng chuột, validation trống.
- `flutter build apk --debug --target-platform android-x64`: thành công, APK ở `mobile/build/app/outputs/flutter-apk/app-debug.apk`. FlutterFire hiện có cảnh báo tương thích Kotlin cho phiên bản Flutter tương lai; build hiện tại thành công.
- Web `npm run build` và `npm run lint` với Node 24: thành công. Vite cảnh báo bundle lớn hơn 500kB; chưa tối ưu code splitting.
- `git diff --check`: sạch whitespace.
- Chưa kiểm tra runtime APK mới trên Genymotion: thiết bị đã ngắt kết nối trong lúc kiểm tra, adb connect localhost:6562 báo connection refused. Chưa thử đăng nhập mobile hoặc workspace với dữ liệu Firebase thật.
- Rules mới chưa chạy Firebase Emulator test và chưa publish; cần kiểm tra quyền với tài khoản thành viên/không thành viên sau bước Console. Không lấy build/test UI làm bằng chứng Rules đã vận hành đúng.
- Không khởi chạy Flutter run/Vite lâu dài; chưa commit/push/deploy.
