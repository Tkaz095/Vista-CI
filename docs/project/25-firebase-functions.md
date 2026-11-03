# 25. Backend Firebase Cloud Functions và Firebase Hosting

Ngày 03/11/2026. Thay thế cách chạy backend trong Vite/Vercel ở tài liệu 21–24.
Đây là hướng dẫn deploy do người dùng thực hiện. Code local không tự thay đổi cloud.

## Kiến trúc

- Firebase Authentication: đăng nhập GitHub và xác minh Firebase ID token.
- Firestore: giữ nguyên hồ sơ, workspace, liên kết repository và vault token đã mã hóa.
- `functions/src/`: OAuth callback, gia hạn token, API repo/run/job/log; chuyển từ `web/api` và `web/server`.
- Firebase Hosting: phục vụ `web/dist`, chuyển `/api/**` đến HTTPS function `vistaApi`.
- Web và Flutter gọi cùng origin `https://vista-ci.web.app`. Không cần máy tính chạy Vite, ADB reverse hoặc Vercel khi dùng bản cloud.
- GitHub Actions tiếp tục thực thi workflow. Chưa thêm agent, webhook, FCM, dispatch hoặc rerun.

## Cấu hình đã chuẩn bị trong code

- `firebase.json`: Functions Node.js 22, codebase `vista`, Hosting rewrites API trước SPA, đường dẫn Rules hiện tại.
- `vistaApi`: region `asia-southeast1`, 256 MiB, 1 CPU, concurrency 10, timeout 60 giây, minInstances 0, maxInstances 2.
- Public invoker chỉ mở transport HTTP; mỗi API dữ liệu vẫn kiểm tra Firebase ID token, profile user và owner repository. Callback dùng state/PKCE; browser mobile-open dùng ticket ngắn hạn.
- `/api/health` chỉ kiểm tra function đã khởi chạy. Nó không chứng minh OAuth, IAM, Firestore hoặc GitHub đã hoạt động end-to-end.
- Secret Manager: `GITHUB_CLIENT_SECRET`, `GITHUB_TOKEN_ENCRYPTION_KEY`; không đưa GitHub token/secret vào web/mobile.
- Admin SDK dùng Application Default Credentials của function. Không cần `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`, `FIREBASE_PROJECT_ID` hay upload JSON Admin SDK trên cloud.
- OAuth state cookie đổi thành `__session` vì Firebase Hosting chỉ chuyển tiếp cookie có tên này. Cookie vẫn mã hóa, HttpOnly, Secure trên HTTPS và có thời hạn 10 phút.
- AES-GCM binding/vault schema không đổi. Kết nối đã lưu dùng tiếp được nếu giữ nguyên OAuth App, Firebase project và khóa mã hóa.
- Mobile có origin mặc định Firebase. Lần đầu sau cập nhật, URL cũ localhost:5173 hoặc vista-ci.vercel.app được chuyển sang default Firebase; URL tùy chỉnh khác được giữ. Vẫn có thể chọn local sau đó.

## 1. Điều kiện trước khi deploy

- Project `vista-ci` đã bật Blaze và liên kết thanh toán.
- Dùng tài khoản Google có quyền triển khai project, Functions, Hosting và Secret Manager.
- Các lệnh bên dưới chạy từ thư mục gốc `Vista-CI`, không chạy trong `mobile`.
- Runtime cloud/CI là Node.js 22. Không cần tự hạ phiên bản Node toàn máy chỉ để đọc/sửa code; nếu CLI/emulator báo không hỗ trợ Node hiện tại, dùng môi trường Node 22 riêng.

```bash
npx firebase-tools login
npm ci --prefix functions
npm ci --prefix web
```

Không cần chạy `firebase init` vì cấu hình đã có; chạy lại init có thể ghi đè file.

## 2. Cấu hình thông tin không bí mật

```bash
cp functions/.env.example functions/.env.vista-ci
```

Mở `functions/.env.vista-ci` và điền:

```dotenv
VISTA_APP_ORIGIN=https://vista-ci.web.app
GITHUB_CLIENT_ID=<Client ID của OAuth App hiện tại>
```

File `.env.vista-ci` được Git ignore. Không đặt các tên reserved như `FIREBASE_PROJECT_ID` vào Functions env.

## 3. Nhập hai secret

```bash
npx firebase-tools functions:secrets:set GITHUB_CLIENT_SECRET --project vista-ci
npx firebase-tools functions:secrets:set GITHUB_TOKEN_ENCRYPTION_KEY --project vista-ci
```

CLI sẽ yêu cầu nhập giá trị. Dùng giá trị hiện đang cấu hình trên Vercel/local, không dán vào chat hay truyền giá trị trong command history.

**Giữ nguyên khóa `GITHUB_TOKEN_ENCRYPTION_KEY` hiện tại (base64 của 32 bytes).** Đổi khóa ngẫu nhiên sẽ làm token cũ trong Firestore không đọc được. Không lấy `private_key` của Firebase làm khóa này. Nếu đã mất khóa cũ, cần kế hoạch kết nối lại; không xóa cả database.

Giữ nguyên GitHub OAuth App và Client Secret hợp lệ. Các giá trị secret cần được khai báo/bind vào function; code đã làm phần đó.

## 4. Callback GitHub và Firebase

Trong GitHub OAuth App, giữ callback đăng nhập Firebase:

```text
https://vista-ci.firebaseapp.com/__/auth/handler
```

Thêm redirect URI backend mới:

```text
https://vista-ci.web.app/api/github-session?action=callback
```

Firebase Authentication → Settings → Authorized domains: `vista-ci.web.app` đã là domain mặc định của project; xác nhận nó vẫn còn trong danh sách. Mở UI bằng đúng origin này để browser popup/cookie/origin khớp cấu hình.

Chỉ đổi `VISTA_APP_ORIGIN` sang domain khác khi đồng thời cập nhật Hosting domain, OAuth callback và URL mobile. Bản Vercel cũ còn tồn tại độc lập, không được migration tự xóa.

## 5. Deploy do người dùng chạy

```bash
npx firebase-tools deploy --only functions:vista,hosting --project vista-ci
```

Predeploy sẽ build Functions và web. Lần đầu Firebase có thể yêu cầu bật API hoặc cấp quyền Secret Manager; đọc thông báo CLI và cấp trong project đúng.

Không thêm `--only firestore:rules` trừ khi bạn chủ động muốn publish Rules hiện tại. Migration này không thay đổi cấu trúc dữ liệu và không cần publish lại Rules.

Nếu lỗi IAM khi runtime đọc Firestore/Auth, xác định service account đang chạy `vistaApi` trong phần cấu hình function (không đoán email từ file Admin SDK cũ). Cấp tối thiểu quyền cần cho nghiệp vụ: Firestore truy cập dữ liệu (`roles/datastore.user`) và xem Firebase Authentication users (`roles/firebaseauth.viewer`). Deploy/Secret Manager có các quyền riêng; không cấp Owner cho runtime chỉ để thử.

## 6. Kiểm tra sau deploy

1. Mở `https://vista-ci.web.app/api/health`: phải là JSON `status: ok`.
2. Mở `https://vista-ci.web.app/api/github-data?kind=repos` trong tab không có Bearer token: JSON 401 `FIREBASE_AUTH_REQUIRED` là đúng; không phải function crash hoặc HTML trang chủ.
3. Mở web trên `https://vista-ci.web.app`, đăng nhập GitHub, xem workspace.
4. Tài khoản → Cập nhật kết nối. Nếu cần cấp scope `public_repo`, chọn Kết nối lại GitHub rồi duyệt quyền (bao gồm đọc/ghi repo public).
5. Kiểm tra repo → CI/CD → job/step → log của một lần chạy thất bại. Đọc được job chưa chứng minh tải log được.
6. Cài bản mobile có code mới. Tài khoản hiển thị URL mặc định `https://vista-ci.web.app`; nếu đang dùng URL tùy chỉnh, lưu lại đúng URL này. Kiểm tra kết nối và CI/CD trên mobile.

Không coi `/api/health` hoặc build APK thành công là đã xác nhận OAuth, refresh sau hết hạn thật hay mobile end-to-end.

## Phát triển local, không bắt buộc khi đã dùng cloud

Cloud Functions emulator chạy trên máy tính, không phải bản online. Với web Vite dùng port 5173:

- Copy `functions/.secret.local.example` → `functions/.secret.local` và `functions/.env.example` → `functions/.env.local`.
- Đặt local `VISTA_APP_ORIGIN=http://localhost:5173`. Giá trị secret mẫu chỉ kiểm tra route/validation; muốn OAuth thật cần credential và secret thật do bạn cấu hình riêng.
- Admin SDK local đọc ADC; chỉ cấu hình `GOOGLE_APPLICATION_CREDENTIALS` cho terminal emulator nếu chủ động dùng dữ liệu Firebase thật. Test demo không dùng production credentials.

```bash
npm run build --prefix functions
npx firebase-tools emulators:start --only functions,hosting --project vista-ci
```

Terminal khác `cd web` rồi `npm run dev`. Vite chỉ proxy `/api` đến emulator, không giữ server secret. Nếu chọn Hosting emulator port 5000 thay vì Vite, đổi origin local và callback tương ứng.

## Chi phí và giới hạn

Quota request không thay thế quota CPU, RAM, network, build, image storage hay Secret Manager. `minInstances: 0` cho phép về 0 khi rảnh; `maxInstances: 2` hạn chế scale nhưng không phải giới hạn hóa đơn. Nên đặt budget alert/spend cap trên Console; cap có độ trễ và không áp dụng mọi dịch vụ.

## Bằng chứng kiểm tra local

- Build Functions và 9 test backend HTTP/OAuth/config đạt, gồm kiểm tra trên Node.js 22 đúng runtime cloud.
- Firebase CLI 15.34.2, Node.js 22, project demo tách biệt: Hosting → Function trả health 200, request thiếu Firebase ID token trả JSON 401, API không tồn tại trả JSON 404, trang SPA trả 200. Callback nhận/giải mã đúng cookie `__session` xuyên qua Hosting rewrite và xử lý việc người dùng hủy OAuth. Không đọc/ghi project Firebase thật. Emulator dừng sau kiểm tra.
- Flutter analyze đạt và 9 test Flutter đạt, gồm migration URL backend; web build/lint đạt. Build web còn cảnh báo bundle trên 500 kB.
- Chưa deploy cloud, chưa xác nhận IAM, OAuth consent thật, GitHub logs trên Functions, refresh khi hết hạn thật hoặc giao diện mobile gọi bản cloud. Những bước này cần hoàn tất sau secret/callback/deploy.

Nguồn: [Functions setup](https://firebase.google.com/docs/functions/get-started), [runtime/scaling](https://firebase.google.com/docs/functions/manage-functions), [secret parameters](https://firebase.google.com/docs/functions/config-env), [Hosting rewrites](https://firebase.google.com/docs/hosting/functions), [Hosting cookies](https://firebase.google.com/docs/hosting/manage-cache), [spend caps](https://firebase.google.com/docs/projects/billing/spend-caps).
