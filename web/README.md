# Vista CI Web

The React + TypeScript dashboard built with Vite.

## Run locally

```bash
npm ci
npm run dev
```

Firebase client sign-in and the backend have separate configuration. Configure server-only variables in `.env.local` from `.env.example`; see the setup section below.

## Workspace, GitHub session và log

Xem `../docs/project/20-workspace-navigation-session-logs.md`. Dùng `npm run dev` để có cả web và API tải log local. API source trong `api/github-job-log.ts` được dùng chung với Vercel Function sau này; không nằm trong static dist. Web giữ kết nối GitHub trong cùng tab tối đa24h, cần reconnect một lần sau cập nhật cơ chế lưu. Agent chưa triển khai.

## Kết nối GitHub tự gia hạn — bước21

Xem `../docs/project/21-github-auto-refresh.md`. Cần cấu hình `.env.local` theo `.env.example`, thêm callback backend vào OAuth App và cấp Firebase Admin credential cho server. `npm run dev` phục vụ cả web lẫn API, cố định port5173. GitHub token lưu mã hóa trong Firestore, không ở sessionStorage; mô tả session24h phía trên là mốc20 cũ. Chưa cấu hình bên ngoài thì backend sẽ báo lỗi setup và chưa dùng luồng GitHub mới được.

## Tự cập nhật và lỗi backend — bước23

Xem `../docs/project/23-auto-update-and-backend-setup.md`. Run đang chạy cập nhật mỗi15 giây, job/step mỗi10 giây; khi hoàn tất/chưa có run dùng60 giây. Tạm dừng khi tab ẩn/offline hoặc gặp lỗi cần sửa cấu hình/quyền. Lỗi `Backend chưa cấu hình FIREBASE_PROJECT_ID` cần điền env server và restart Vite, logout/login không sửa được.
