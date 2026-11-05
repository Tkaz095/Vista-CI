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

Both analytics and Remote Config APIs verify the Firebase ID token on the server and require an enabled Firebase Auth user plus a `users/{uid}` Firestore document with `role: "admin"` and `isActive: true`. The browser cannot grant admin access, and Firestore rules must not be loosened for this console.

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

## Workspace, GitHub session và log

Xem `../docs/project/20-workspace-navigation-session-logs.md`. Dùng `npm run dev` để có cả web và API tải log local. API source trong `api/github-job-log.ts` được dùng chung với Vercel Function sau này; không nằm trong static dist. Web giữ kết nối GitHub trong cùng tab tối đa24h, cần reconnect một lần sau cập nhật cơ chế lưu. Agent chưa triển khai.

## Kết nối GitHub tự gia hạn — bước21

Xem `../docs/project/21-github-auto-refresh.md`. Cần cấu hình `.env.local` theo `.env.example`, thêm callback backend vào OAuth App và cấp Firebase Admin credential cho server. `npm run dev` phục vụ cả web lẫn API, cố định port5173. GitHub token lưu mã hóa trong Firestore, không ở sessionStorage; mô tả session24h phía trên là mốc20 cũ. Chưa cấu hình bên ngoài thì backend sẽ báo lỗi setup và chưa dùng luồng GitHub mới được.

## Tự cập nhật và lỗi backend — bước23

Xem `../docs/project/23-auto-update-and-backend-setup.md`. Run đang chạy cập nhật mỗi15 giây, job/step mỗi10 giây; khi hoàn tất/chưa có run dùng60 giây. Tạm dừng khi tab ẩn/offline hoặc gặp lỗi cần sửa cấu hình/quyền. Lỗi `Backend chưa cấu hình FIREBASE_PROJECT_ID` cần điền env server và restart Vite, logout/login không sửa được.
