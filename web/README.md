# Vista CI Web

The React + TypeScript dashboard built with Vite.

## Run locally

```bash
npm ci
npm run dev
```

Firebase client sign-in and the backend have separate configuration. Configure server-only variables in `.env.local` from `.env.example`; see the setup section below.

## Admin console

The web app is the admin console only; the user-facing Vista experience is the mobile app. Open `/` or `/admin` to sign in as an administrator with the separate Firebase Email/Password account.

All admin APIs verify the Firebase ID token on the server and require an enabled Firebase Auth user plus a `users/{uid}` Firestore document with `role: "admin"` and `isActive: true`. The browser cannot grant admin access, and Firestore rules must not be loosened for this console.

### Create an admin or test account

1. Make sure **Authentication → Sign-in method → Email/Password** is enabled.
2. In Firebase Console, open **Authentication → Users → Add user**. Create a separate email and password for the admin/test account.
3. In **Authentication → Users**, find the new account and copy its **UID**.
4. Open **Firestore Database → Data** and create `users/{UID}` (use the exact UID as the document ID) with:
   - `displayName` — string
   - `role` — `admin`
   - `isActive` — boolean `true`
5. Sign in at `/` or `/admin` with that email/password. A regular `user` account is intentionally denied access to the admin tabs.

Firebase never displays a user's password to an administrator. To test, create the separate admin account with a password you know, or use Firebase Authentication's password-reset flow. Do not copy passwords into Firestore or share them in source code/chat.

The analytics tab reports Firestore account/workspace totals and daily workspace creation for the last 14 days. It does not report Firebase Analytics event totals; those require a separately authorized Google Analytics Data API integration. The configuration tab edits and publishes the app's three existing Remote Config parameters: `ci_analysis_enabled`, `cloudinary_cloud_name`, and `cloudinary_upload_preset`.

The server's Firebase Admin credential must have Firestore read access and the Firebase Remote Config Admin permission to publish settings. Keep the credential server-side using the existing `.env.local` options; never put it in `VITE_` variables or the browser bundle.

## Phạm vi web

Web chỉ dành cho quản trị viên. Giao diện đăng nhập GitHub, workspace, repository và CI/CD của user đã được gỡ khỏi `web/src`; thành viên sử dụng ứng dụng Flutter trong `mobile`.

Các API GitHub phía server được giữ lại để không làm gián đoạn client đang sử dụng chúng. Web admin có Tổng quan (số liệu Firestore), Cấu hình ứng dụng (Remote Config), Giám sát ứng dụng và Thông báo. Mục Giám sát gọi API server đọc Cloud Monitoring và BigQuery export Crashlytics/Sessions; cần bật nguồn và cấp IAM theo hướng dẫn [26-admin-monitoring](../docs/project/26-admin-monitoring.md). Không còn dữ liệu mẫu. Không có thống kê Google Analytics trên web.

## Gửi thông báo tới app từ web admin

Trong tab **Thông báo**, chọn phạm vi **Một tài khoản** hoặc **Tất cả user đang hoạt động**, nhập tiêu đề/nội dung rồi bấm **Xem lại thông báo**. Với một tài khoản, kiểm tra bản xem trước rồi bấm **Gửi thông báo**. Với tất cả user, web tải hết các trang người nhận, hiển thị tổng số user và yêu cầu đánh dấu xác nhận trước khi bấm **Gửi cho N user**. Danh sách chỉ gồm hồ sơ `role: user`, `isActive: true` có tài khoản Firebase Auth còn hoạt động; không gửi cho admin hay tài khoản bị khóa.

Gửi đồng loạt dùng lại API gửi từng user, tối đa ba request đồng thời. Mỗi user có mã yêu cầu riêng, được giữ nguyên khi kiểm tra hoặc tiếp tục lượt gửi. UI hiển thị số tài khoản đã xử lý, đã lưu lịch sử, số thiết bị FCM chấp nhận và chi tiết tài khoản gặp lỗi. Nếu tài khoản bị vô hiệu hóa sau lúc xem lại, server từ chối tài khoản đó và tiếp tục các tài khoản khác. User mới đăng ký sau khi danh sách đã tải xong không thuộc lượt gửi này.

Giữ trang web mở tới khi hoàn tất; chuyển tab trong web admin vẫn giữ tiến độ. Đóng/tải lại trang hoặc đăng xuất sẽ dừng khởi chạy những request còn lại, không thu hồi các request đã gửi. Không có worker chạy nền hay khôi phục lượt gửi sau khi tải lại trang. Nếu mất mạng hoặc server chưa xác nhận kết quả, lượt gửi tạm dừng: bấm **Kiểm tra kết quả**, sau đó **Tiếp tục gửi phần còn lại**. User đã hoàn tất không bị gửi lại; request chưa tìm thấy vẫn giữ mã cũ khi gửi tiếp. Kiểm tra trạng thái chưa rõ trước khi soạn lượt gửi mới.

Server kiểm tra lại người nhận, lưu thông báo vào `users/{uid}/notifications/admin_{requestId}` trước, rồi gửi FCM tới các FCM Installation ID (`fid`) trong `users/{uid}/devices`. App hiện tại đã đọc được thông báo loại này; không cần đổi Flutter hay build APK chỉ để thêm chức năng gửi trên web. Nếu không có thiết bị, thông báo vẫn xuất hiện trong lịch sử khi user mở app. Tùy chọn nhận CI của từng repo chỉ áp dụng thông báo CI; tin quản trị không kèm đường dẫn workflow và không bị lọc bởi các tùy chọn đó.

### Cấu hình Firebase và deployment

1. Web/backend phải trỏ tới cùng project chính với app, hiện là `vista-ci`; không dùng project AI riêng.
2. Trong Google Cloud Console của project chính, kiểm tra **Firebase Cloud Messaging API (HTTP v1)** đã bật.
3. Service account mà backend web sử dụng cần quyền đọc Firebase Authentication, đọc/ghi Firestore và gửi FCM. Có thể dùng các role theo phạm vi cần thiết: **Firebase Authentication Viewer**, **Cloud Datastore User** và **Firebase Cloud Messaging API Admin** (`roles/firebasecloudmessaging.admin`). Giữ quyền Remote Config/Monitoring hiện có nếu đang sử dụng các tab tương ứng. Xem [Firebase IAM roles](https://firebase.google.com/docs/projects/iam/roles-predefined-product) và [FCM server authorization](https://firebase.google.com/docs/cloud-messaging/auth-server).
4. Giữ `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` ở server theo cấu hình hiện có. Không thêm key hoặc quyền gửi FCM vào biến `VITE_`. Deploy lại web sau khi cập nhật code/env.
5. Trên điện thoại: đăng nhập, cho phép thông báo, mở màn Thông báo và đăng ký thiết bị. Đưa app xuống nền để kiểm tra thông báo hệ thống; khi app đang mở, kiểm tra lịch sử thông báo trong app.

Chức năng này gửi trực tiếp từ API server của web, **không cần deploy `mobile/functions`**. Nó không thay thế luồng tự động nhận sự kiện GitHub CI. Firebase Admin SDK ghi dữ liệu bằng IAM; giữ Rules hiện tại cho mobile, không mở quyền client ghi thông báo quản trị hoặc đọc `adminNotificationRequests`.

### API và xử lý kết quả chưa rõ

Tất cả request gửi `Authorization: Bearer <Firebase ID token admin>` và trả `Cache-Control: no-store`.

| Request | Mục đích |
| --- | --- |
| `GET /api/admin?resource=notification-recipients&cursor=...` | Tải tối đa 50 hồ sơ mỗi lượt quét; trả `recipients` và `nextCursor`. Không trả FID. |
| `POST /api/admin?resource=notifications` | Body `{requestId, uid, title, body}`; UUID v4, tiêu đề tối đa 200, nội dung tối đa 1.000 ký tự và giới hạn byte cho FCM. |
| `GET /api/admin?resource=notifications&id=...` | Xem kết quả yêu cầu của chính admin đã gửi, không phát lại push. |

Kết quả gồm `state`, `devices`, `sent`, `failed`, `uncertain`. `sent` nghĩa là FCM chấp nhận yêu cầu, chưa bảo đảm điện thoại hiển thị hoặc user đã đọc. FID hết hiệu lực được dọn mà không xóa đăng ký mới thay thế. Lỗi quyền/mạng/FCM chưa rõ được tính `uncertain`; xem Runtime Logs `[vista-admin]` để tìm mã lỗi, sửa cấu hình rồi chủ động soạn tin mới nếu cần.

`adminNotificationRequests/{requestId}` lưu người gửi, hash nội dung và trạng thái, server-only. Gửi lại cùng mã/nội dung chỉ đọc kết quả; khác nội dung trả 409. UI giữ mã khi chuyển tab và khi mất kết nối; dùng **Kiểm tra kết quả** trước khi gửi lại. Không tải lại trang trong lúc gửi vì bản nháp/mã chỉ được giữ trong phiên giao diện.

Nếu tiến trình server bị dừng sau khi lưu lịch sử, trạng thái có thể còn `sending` và một số thiết bị chưa nhận push. Không có worker tự gửi lại; cách này ưu tiên tránh phát trùng và không cam kết giao hàng đúng một lần. Thông báo đã lưu vẫn đọc được trong app.

### Kiểm thử local

Test dùng Firebase Auth/Firestore Emulator và thay FCM bằng hàm giả; không gửi push thật. Chạy hai emulator trên `127.0.0.1:9099` và `127.0.0.1:8099` với project `demo-vista-admin`, sau đó:

```bash
FIREBASE_PROJECT_ID=demo-vista-admin \
FIRESTORE_EMULATOR_HOST=127.0.0.1:8099 \
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
npm run test:notifications
```

Test backend sẽ xóa dữ liệu của project demo trong hai emulator trước mỗi ca và từ chối chạy với project/host khác. Các ca gồm xác thực HTTP, lọc người nhận, dữ liệu tương thích mobile, lưu lịch sử trước push, chống gửi trùng, FID hết hạn và lỗi FCM chưa rõ. Test service phía web dùng HTTP giả lập để kiểm tra tải hết các trang, gửi theo nhóm, tạm dừng khi mất mạng, kiểm tra trạng thái và tiếp tục bằng mã yêu cầu cũ.

## Vercel: tương thích dependency Firebase Admin

`package.json` khóa riêng `jose` bên dưới `jwks-rsa` về `5.10.0` bằng npm overrides. Firebase Admin 14 kéo `jwks-rsa` 4 dùng CommonJS `require('jose')`, trong khi jose 6 chỉ cung cấp ESM; trên runtime Vercel điều này đã gây `ERR_REQUIRE_ESM` trước khi API admin kiểm tra token.

Giữ cả `package.json` và `package-lock.json` trong lần deploy. Không sửa tay `node_modules`, không đổi Firebase credentials để xử lý lỗi nạp module. Override chỉ áp dụng cho dependency của `jwks-rsa`; cần đánh giá bỏ override khi upstream đã sửa tương thích ESM.

Sau khi merge bản sửa, tạo deployment từ commit mới của `dev` (redeploy một deployment cũ vẫn dùng lockfile cũ). Lỗi runtime chỉ được xác nhận đã hết khi API trên Vercel trả JSON thay cho `FUNCTION_INVOCATION_FAILED`; việc đăng nhập admin thành công cần kiểm tra riêng trên deployment đó.

### Admin quay lại màn hình login trên Preview

Backend phân biệt token không hợp lệ (401) với credential/IAM/mạng lỗi (503). UI giữ màn hình lỗi thay vì tự đăng xuất để không che mất nguyên nhân; mọi dữ liệu admin vẫn bị chặn đến khi server xác minh thành công.

Vercel Preview và Production có env riêng. Kiểm tra đủ `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` trong đúng environment; tên `CLIENT_EMAIL` hoặc `PRIVATE_KEY` không được backend đọc. Đường dẫn `GOOGLE_APPLICATION_CREDENTIALS` của máy local không tồn tại trên Vercel. Sau thay đổi env cần deployment mới. Không dùng việc đăng nhập Firebase client thành công làm bằng chứng Admin SDK server có credential đúng.

Request lưu Remote Config gửi `ci_analysis_enabled` dạng boolean; response đọc vẫn giữ chuỗi theo Firebase template. Kiểu request/response được tách riêng để tránh HTTP 400 khi xuất bản cấu hình. Runtime Logs ghi `[vista-admin]` kèm phase/mã lỗi; không ghi token, key hoặc nguyên văn thông báo SDK.
