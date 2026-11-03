# Vista CI Web

React + TypeScript + Vite. Production web chạy trên Firebase Hosting; `/api/**` được chuyển đến Firebase Cloud Function `vistaApi`. Source backend ở `../functions/`, không còn nằm trong web/api hoặc Vercel Functions.

## Run locally

```bash
npm ci
npm run dev
```

Vite port 5173 proxy `/api` đến Functions emulator port 5001. Chạy emulator và cấu hình origin/secret theo [bước 25](../docs/project/25-firebase-functions.md). Không cần chạy Vite khi mobile sử dụng backend Firebase đã deploy.

## Build và kiểm tra

```bash
npm run build
npm run lint
```

Web không cần Firebase Admin private key hoặc GitHub client secret. `.env.local` cũ của Vercel/Vite không còn được backend đọc. Không copy secret thành biến VITE_.

Đăng nhập Firebase và kết nối OAuth backend vẫn là hai bước: token GitHub được mã hóa trong Firestore, backend tự gia hạn; không lưu token GitHub trong trình duyệt. Workspace/repo → CI/CD → job/step/log là phạm vi hiện tại, agent để sau.

## Deploy

Từ root Vista-CI, làm [hướng dẫn Firebase](../docs/project/25-firebase-functions.md). Hosting build ra `web/dist`, Functions build độc lập trong `functions/lib`. Chưa có deploy tự động từ GitHub; workflow backend-check chỉ build/test.
