# Vista Firebase Functions

Source backend duy nhất ở `src/`. Entrypoint `vistaApi` phục vụ `/api/github-session`, `/api/github-data`, `/api/github-job-log` và `/api/health` qua Firebase Hosting.

```bash
npm ci
npm test
```

Runtime cloud và CI: Node.js 22. Tests dùng HTTP thật trên loopback, dữ liệu giả cho OAuth state, không cần secret thật và không ghi lên Firebase/GitHub.

Deploy/callback/secrets/migration: [hướng dẫn bước 25](../docs/project/25-firebase-functions.md). Các thao tác cloud do người dùng thực hiện, không tự deploy khi chạy npm test/build.
