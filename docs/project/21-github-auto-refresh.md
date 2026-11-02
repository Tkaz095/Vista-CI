# 21. Ổn định kết nối GitHub public và tự làm mới token — web

Ngày 02/11/2026. Triển khai mục1 của backlog: đăng nhập Vista bắt buộc, repo public thuộc account, giữ kết nối qua reload/restart và tự refresh. Agent/private/mobile không thuộc lượt này.

**Trạng thái:** đã có code backend + web và mẫu cấu hình. Chưa kết nối dịch vụ thật vì các bước cấp quyền/callback/secret bên ngoài do người dùng thực hiện. Không coi build thành công là bằng chứng refresh hoạt động thực tế.

## 1. Vì sao cần callback backend

Firebase SDK công khai `OAuthCredential.accessToken`, không cung cấp trường refresh token tương ứng trong hợp đồng public đang sử dụng. Không phụ thuộc `_tokenResponse` nội bộ. Vì vậy giữ Firebase để đăng nhập Vista, thêm một lần kết nối OAuth backend với `offline_access` để backend trực tiếp nhận `access_token`, `refresh_token`, `expires_in`, `refresh_token_expires_in`.

GitHub hỗ trợ OAuth expiring tokens: https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps

Đây là hai bước xác thực khác mục đích: đăng nhập Vista xác định Firebase UID; kết nối GitHub backend cấp quyền API dài hạn. Sau khi kết nối một lần thành công, không kết nối lại mỗi F5 hoặc mỗi8h. Người dùng vẫn phải đăng nhập Vista khi phiên Firebase không còn hợp lệ.

## 2. Đã triển khai trong code

- `/api/github-session?action=start` POST: kiểm tra Origin, Firebase ID token/revocation, hồ sơ user active và GitHub provider liên kết; tạo state/PKCE trong cookie mã hóa HttpOnly10 phút.
- Callback GET đổi authorization code, so khớp GitHub numeric ID với provider của Firebase UID; không ghi nhầm account. Không trả token về client qua response/postMessage/URL.
- AES-256-GCM mã hóa cặp token với UID/GitHub ID trong AAD; khóa server32byte tách Firestore. Vault `githubConnections/{uid}` chỉ backend truy cập.
- Hạn token lấy từ response GitHub, bỏ TTL24h tự đặt. Refresh khi access token còn dưới60 giây; lưu cặp token mới sau mỗi lần đổi.
- Single-flight trong process + transaction lease45s trong Firestore chống đổi cùng refresh token giữa request/instance. Kết nối mới có connectionId để response refresh cũ không ghi đè.
- GitHub401: thử refresh và đọc lại một lần. Refresh hết hạn/thu hồi: báo RECONNECT_REQUIRED. Mạng/config/rate limit có mã riêng, không tự logout Firebase hoặc mở popup liên tục.
- `/api/github-data`: repos/runs/jobs; `/api/github-job-log`: log plaintext. Client chỉ gửi Firebase ID token. Server xác minh GitHub repo public và owner numeric ID. Không xin scope repo, không hỗ trợ repo private/organization-owned/collaborator-owned ở mốc này.
- Xóa credential cũ trong sessionStorage; không lưu GitHub access/refresh token phía client nữa. Điều hướng workspace/repo vẫn lưu riêng.
- Vault là phụ thuộc tối thiểu từ mục2 để refresh không mất sau restart/serverless; chưa triển khai đầy đủ UI quản lý/ngắt kết nối, lịch sử token hoặc tác vụ nền.

## 3. Thao tác GitHub — người dùng thực hiện

GitHub → Settings → Developer settings → OAuth Apps → ứng dụng Vista đang dùng:

1. Giữ callback Firebase hiện có `https://vista-ci.firebaseapp.com/__/auth/handler` để đăng nhập Vista.
2. **Thêm**, không thay thế, redirect URI local:

   `http://localhost:5173/api/github-session?action=callback`

3. Giữ/bật **Expire user access tokens**. Code cũng yêu cầu `offline_access`.
4. Dùng Client ID/Client Secret của OAuth App đó cho backend. Không gửi secret vào chat, không điền vào source/biến VITE_.

Vite cố định port5173 và strictPort để không tự đổi origin khi port bận. Truy cập đúng `http://localhost:5173`; nếu dùng127.0.0.1 cần cấu hình origin/callback tương ứng.

## 4. Thao tác local — người dùng thực hiện

Trong thư mục `web`:

```bash
cp -n .env.example .env.local
```

Nếu `.env.local` đã có, giữ file đó và bổ sung các biến còn thiếu. Tự điền `.env.local` (file đã được ignore):

| Biến | Giá trị cần cung cấp |
|---|---|
| VISTA_APP_ORIGIN | http://localhost:5173 |
| FIREBASE_PROJECT_ID | vista-ci |
| GITHUB_CLIENT_ID | Client ID OAuth App Vista |
| GITHUB_CLIENT_SECRET | Client Secret cùng OAuth App |
| GITHUB_TOKEN_ENCRYPTION_KEY | Khóa ngẫu nhiên32byte dạng base64 |

Tạo khóa trên terminal riêng rồi tự copy vào `.env.local`:

```bash
node -e "process.stdout.write(require('node:crypto').randomBytes(32).toString('base64'))"
```

Giữ nguyên khóa qua restart; đổi/xóa khóa khiến token vault cũ không giải mã được và phải kết nối lại. Sao lưu/quản lý khóa trong hệ thống secret khi deploy; không commit hoặc gửi vào chat.

### Firebase Admin cho backend local

Backend cần credential **server**, khác `google-services.json` và web firebaseConfig. Dùng Application Default Credentials đã có quyền trên project, hoặc tự tạo service-account credential trong Firebase/Google Cloud Console theo tài liệu Admin SDK.

Nếu dùng file JSON: giữ file ngoài repo, tự đặt đường dẫn tuyệt đối vào:

```dotenv
GOOGLE_APPLICATION_CREDENTIALS=/duong/dan/ngoai/repo/service-account.json
```

Không đưa nội dung JSON vào chat hoặc source. Không cần tạo một role Admin trong ứng dụng Vista; đây là quyền máy chủ truy cập Firebase.

SDK cần đọc người dùng Firebase Auth và đọc/ghi Firestore. IAM phải cho phép các thao tác đó; Firestore Admin SDK không chịu client Rules. Dùng service account dành cho backend và giới hạn quyền phù hợp (Auth read / Firestore data access), không đặt credential này trong VITE_*.

Tham chiếu: https://firebase.google.com/docs/admin/setup

Sau khi điền, dừng Vite cũ rồi chạy:

```bash
npm run dev
```

Không có lệnh backend riêng; Vite phục vụ các route local. Thay đổi `.env.local` cần restart Vite để nạp lại.

## 5. Thao tác Firestore Rules — người dùng thực hiện

Publish nội dung hiện tại của `firebase/firestore.rules`. Đã bổ sung explicit deny:

```text
match /githubConnections/{uid} {
  allow read, write: if false;
}
```

Không tự tạo document token, không paste token vào Console. Backend tự tạo sau callback thành công. Không mở read/write để sửa lỗi backend: SDK server dùng IAM. Không cần index mới hoặc Cloud Functions. Lưu/read/transaction Firestore vẫn tính theo quota/usage hiện có.

## 6. Lần kết nối đầu tiên

1. Đăng nhập Vista bằng GitHub như cũ.
2. Vào Tài khoản hoặc Thêm repository trong workspace.
3. Bấm **Kết nối GitHub tự động gia hạn**; chọn đúng GitHub account đã dùng đăng nhập.
4. Sau callback thành công, danh sách repo public được tải bằng backend.
5. F5/restart Vite cùng cấu hình, hoặc mở lại web và khôi phục phiên Firebase: backend dùng connection đã lưu. Không cần nhập UID/token thủ công.

Nếu SERVER_SETUP_REQUIRED/BACKEND_UNAVAILABLE: sửa env/IAM/network; đây không phải yêu cầu đăng nhập GitHub lại. Chỉ reconnect khi chưa có connection, refresh token hết hiệu lực hoặc GitHub authorization không còn hợp lệ.

## 7. Vercel sau này

Root Directory `web`; deploy source có `api/` và `server/` cùng package-lock. Đặt secret trong server Environment Variables, không dùng đường dẫn JSON local. Đặt cặp FIREBASE_CLIENT_EMAIL/FIREBASE_PRIVATE_KEY thay ADC file, cùng FIREBASE_PROJECT_ID.

Đặt VISTA_APP_ORIGIN là origin HTTPS ổn định và thêm redirect URI tương ứng `/api/github-session?action=callback` trong OAuth App. Thêm domain đó vào Firebase Authorized domains để Firebase sign-in hoạt động. Preview domain ngẫu nhiên cần cấu hình riêng; không tự wildcard callback. Giữ khóa mã hóa ổn định nếu dùng chung vault.

Chưa deploy hoặc thay đổi Console trong lượt này.

## 8. Xác minh và giới hạn

- TypeScript/Vite build và ESLint đã chạy thành công trên code mới; Vite vẫn cảnh báo bundle >500kB.
- Không chạy unit/integration tests, không gọi callback/refresh với credential người dùng, chưa đợi8h hoặc thử trên browser thực tế. Cấu hình dịch vụ thật còn chờ người dùng.
- Kiểm tra dependency sau thêm firebase-admin còn advisory ở cây Firebase/gRPC và các dependency Google; không chạy audit fix --force hoặc downgrade Firebase trong task này. Chưa coi dependency tree là đã xử lý hết advisory.
- Nghiệm thu runtime cần: đúng account; từ chối khác account; F5/restart không reconnect; access token gần hết hạn tự refresh; nhiều request đồng thời chỉ rotate một lần; lỗi mạng không bắt reconnect; thu hồi refresh yêu cầu kết nối lại.
- Mốc này web trước. Flutter vẫn có cơ chế token cũ và chưa gọi backend; chuyển Flutter thuộc mục5 của backlog.
- Logout Vista xóa phiên client, không xóa/revoke connection backend; lần đăng nhập lại đúng UID có thể dùng lại connection. Tính năng ngắt kết nối/xóa grant cần làm ở phần quản lý connection sau.
- Chưa commit/push/deploy.
