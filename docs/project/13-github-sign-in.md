# Bước 13 — Đăng nhập GitHub và liên kết tài khoản hiện có

Ngày 01/11/2026. Người dùng đã báo Save provider GitHub trên Firebase; Codex chưa xác minh cấu hình Console hoặc thực hiện OAuth với tài khoản thật.

## Phần code đã triển khai

- Web: `GithubAuthProvider` + `signInWithPopup`; nút GitHub là hành động chính trên màn đăng nhập.
- Android Flutter: `GithubAuthProvider` + `signInWithProvider`, SDK mở trình duyệt cho OAuth.
- Tài khoản → Liên kết GitHub dùng `linkWithPopup` (web) / `currentUser.linkWithProvider` (Android). Gắn provider vào Firebase user đã đăng nhập để giữ UID, hồ sơ và membership. Không dùng một lần sign-in GitHub riêng để thay thế thao tác link.
- Email/Password giữ lại cho tài khoản đã tạo và bước liên kết lần đầu. Người dùng sau khi liên kết có thể đăng nhập bằng GitHub.
- Hiện trạng liên kết lấy từ Firebase Auth `providerData`, không suy ra từ email hoặc tự đặt cờ Firestore. Sau link cập nhật trạng thái UI.
- Có lỗi tiếng Việt cho hủy OAuth, popup bị chặn, domain chưa cho phép, provider chưa bật, email/provider trùng, credential thuộc tài khoản khác và cần đăng nhập lại.
- Token OAuth nhận về được bỏ qua trong bước xác thực; Vista không tự lưu token/secret vào Firestore, localStorage, file config hoặc log. Firebase SDK tiếp tục quản lý phiên Auth theo cơ chế của SDK.
- Không yêu cầu scope `repo`, không gọi GitHub API, không tự nhập repo hoặc tạo GitHub App ở bước này. Kết nối repo/CI theo GitHub App là bước riêng cần backend.

## Việc bạn làm tiếp — nên thử web trước

1. Khởi động web như trước và **đăng nhập bằng Email/Password hiện có**.
2. Vào **Tài khoản**, ghi nhận UID đang hiển thị.
3. Bấm **Liên kết GitHub**, hoàn tất đăng nhập/Authorize ở cửa sổ GitHub. Chọn đúng tài khoản GitHub bạn muốn sử dụng cho Vista.
4. Khi trở về, màn hình báo đã liên kết. UID phải giữ nguyên; hồ sơ và quyền workspace cũ vẫn thuộc UID đó.
5. Bấm Đăng xuất. Tại màn đăng nhập, bấm **Tiếp tục với GitHub**.
6. Kết quả mong đợi: vào cùng tài khoản Vista; mở Tài khoản để đối chiếu UID. Đăng nhập GitHub thành công chưa chứng minh đã kết nối repository.

Nếu trình duyệt chặn popup, cho phép popup ở origin của Vista rồi thử lại. Firebase → Authentication → Settings → Authorized domains cần chứa `localhost` khi chạy `http://localhost:5173`, hoặc tên miền deploy thực tế. Nếu dùng `127.0.0.1` thay localhost, cấu hình đúng origin tương ứng; ưu tiên localhost theo hướng dẫn hiện có.

Không cần gửi Client Secret, token hoặc mật khẩu vào chat. Nếu có lỗi, gửi nội dung thông báo trên Vista hoặc ảnh đã che thông tin nhạy cảm.

## Android — cấu hình chứng thư trước khi thử OAuth

Firebase yêu cầu SHA-1 của chứng thư ký app cho GitHub sign-in trên Android. Nếu chưa thêm:

```sh
cd /home/kien/FPTU/Semester-8/PRM393/Lab3-Assignment/Vista-CI/mobile/android
./gradlew signingReport
```

Lấy dòng **SHA1** thuộc **Variant: debug** của module app, rồi vào:

**Firebase → Project settings → Your apps → Android `com.vista.vista_mobile` → Add fingerprint → Save**.

Tải lại `google-services.json` từ đúng Android app và đặt ở `mobile/android/app/google-services.json`. Dừng phiên Flutter đang chạy rồi chạy lại:

```sh
cd /home/kien/FPTU/Semester-8/PRM393/Lab3-Assignment/Vista-CI/mobile
flutter run
```

Bật Genymotion hoặc kết nối điện thoại trước. Dùng trình duyệt trên thiết bị để hoàn tất GitHub OAuth. Nếu đã liên kết thành công ở web, mobile có thể dùng **Tiếp tục với GitHub** ngay; không cần tạo liên kết riêng cho mỗi client. Cần kết nối mạng để kiểm tra hồ sơ server.

SHA-1 phụ thuộc chứng thư ký, không chỉ package name. APK cloud build hoặc bản release có thể dùng chứng thư khác; cấu hình thêm fingerprint tương ứng khi thử những bản đó. Không giả định fingerprint debug của máy local đúng với mọi bản APK.

## Khi đã lỡ đăng nhập GitHub thành tài khoản Firebase mới

Nếu chưa link từ tài khoản cũ, Firebase có thể tạo user mới (tùy email và chính sách trùng tài khoản). User mới không có `users/{uid}` sẽ bị chặn và hiện hướng dẫn. Vista không tự tạo Admin, không sao chép quyền theo email, không ghi profile từ client.

- Nếu có lỗi trùng email: quay về tài khoản Email/Password cũ rồi link GitHub.
- Nếu có lỗi credential thuộc tài khoản khác: cần xử lý tài khoản trùng có chủ đích. Chưa triển khai tự merge/unlink/delete; không xóa user hoặc profile để thử mò.
- Nếu là người dùng mới thực sự: người quản trị cấp hồ sơ active/role và membership bằng quy trình Console hiện có; onboarding tự động là phần chưa triển khai.

## Kết nối repo ở bước sau

OAuth App cấu hình cho Firebase xác thực danh tính. GitHub App kết nối repository sẽ quản lý quyền theo repo, webhook và credential backend cho việc đọc workflow/log, chạy lại, issue/comment. Chưa có backend hoặc webhook được tạo trong bước này. Dữ liệu repositories trên Firestore hiện vẫn là danh mục theo bước 12.

## Nguồn chính thức

- [Firebase Flutter — GitHub OAuth](https://firebase.google.com/docs/auth/flutter/federated-auth)
- [Firebase Web — GitHub](https://firebase.google.com/docs/auth/web/github-auth)
- [Firebase Web — Account linking](https://firebase.google.com/docs/auth/web/account-linking)
- [Firebase Android — GitHub và SHA-1](https://firebase.google.com/docs/auth/android/github-auth)

## Bằng chứng local

Kết quả build/analyze ghi sau khi chạy local. Chưa thử OAuth với tài khoản thật, chưa chạy tests ở bước này, chưa thao tác Firebase/GitHub Console, chưa commit/push/deploy. Fake repository trong test UI cũ được cập nhật chữ ký phương thức và loại nút để khớp code mới; không thêm test case mới.

### Kết quả kiểm tra mã nguồn

- Flutter analyze: không có issue sau khi sửa hai lint về dấu ngoặc.
- Android debug APK x64: build thành công. Cảnh báo FlutterFire/Kotlin cho các bản Flutter tương lai vẫn còn như bước 12.
- Web TypeScript/Vite build và ESLint: thành công; cảnh báo bundle hơn 500kB vẫn còn.
- `git diff --check`: sạch whitespace.
- Chưa chạy OAuth thực tế hoặc kiểm thử runtime trên Genymotion. Chưa chạy lại bộ test UI cũ trong bước này. Người dùng thực hiện kiểm tra liên kết UID và đăng nhập thật theo checklist ở trên.

## Cập nhật 02/11/2026 — Hồ sơ lần đầu

Phần mô tả chặn user mới vì thiếu hồ sơ ở trên là hành vi cũ. Theo bước 14, tài khoản đăng nhập chưa có hồ sơ được tự tạo hồ sơ Member. Hồ sơ bị vô hiệu hóa vẫn bị chặn. Rules cho phép self-create phải được publish trước khi dùng luồng mới. Xem `14-tu-tao-ho-so.md`.
