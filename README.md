# Vista CI

Tài liệu và trạng thái triển khai: [docs/README.md](docs/README.md). Phạm vi mới nhất: [workspace cá nhân và repository](docs/project/16-workspace-ca-nhan-repositories.md).

Vista CI gồm mobile Flutter và web React/Vite dùng chung Firebase. Mốc hiện tại có đăng nhập GitHub, hồ sơ user, CRUD workspace/repository và màn CI/CD đọc lịch sử GitHub Actions; agent để giai đoạn sau.

## Project structure

- `mobile/` — Flutter mobile app
- `web/` — React + TypeScript dashboard powered by Vite
- `.github/workflows/` — GitHub Actions workflows

Both clients connect to Firebase project `vista-ci`. GitHub sign-in, account linking and automatic user-profile creation are implemented. Personal workspace CRUD uses ownerUid. GitHub repository discovery uses the OAuth token in session memory; users can select repositories and manage workspace links. See [implementation and Firebase setup](docs/project/17-workspace-crud-github.md).

Publish [Firestore Rules](firebase/firestore.rules) manually using the Firebase Console. Local code changes do not update the deployed Rules. See [user-only access and troubleshooting](docs/project/15-user-only.md). End-to-end GitHub/profile/workspace access and the new ownerUid Rules still need user confirmation after publishing.

## Android cloud build

The **Android APK** GitHub Actions workflow analyzes the Flutter code and builds a development APK on GitHub. Download the APK from the successful run and drag it into Genymotion. The default target is `android-x64`; manual runs also support ARM64 or a universal APK.

See [the setup and installation guide](docs/android-cloud-build.md). Building on GitHub avoids downloading another NDK on the local machine. The first cloud build passed in [run 41219589321](https://github.com/Tkaz095/Vista-CI/actions/runs/41219589321). APK installation, Firebase runtime behavior, and business features still need separate validation.

## Requirements

- Flutter stable SDK
- Node.js 24 recommended (Vite supports 20.19+ or 22.12+)
- npm

## Run locally

### Mobile

```bash
cd mobile
flutter pub get
flutter run
```

### Web

```bash
cd web
npm install
npm run dev
```

Màn CI/CD riêng, bộ lọc và quyền GitHub: [Bước 18](docs/project/18-cicd-screen.md). Không cần chỉnh Firebase cho bước đọc CI/CD.

Luồng web và Flutter dùng backend GitHub chung, quản lý connection và job/step/log: [Bước22](docs/project/22-complete-workspace-cicd-mobile.md). Cần cấu hình callback/env/IAM theo bước21 trước khi dùng API thật; APK biên dịch thành công không thay cho kiểm tra OAuth/điện thoại.
