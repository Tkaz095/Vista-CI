# Vista CI

Tài liệu và trạng thái triển khai: [docs/README.md](docs/README.md). Phạm vi mới nhất: [workspace cá nhân và repository](docs/project/16-workspace-ca-nhan-repositories.md).

Vista CI gồm mobile Flutter và web React/Vite dùng chung Firebase. Mốc hiện tại tập trung đăng nhập GitHub, hồ sơ user và nền tảng workspace/repository; CI/CD và agent để giai đoạn sau.

## Project structure

- `mobile/` — Flutter mobile app
- `web/` — React + TypeScript dashboard powered by Vite
- `.github/workflows/` — GitHub Actions workflows

Both clients connect to Firebase project `vista-ci`. GitHub sign-in, account linking and automatic user-profile creation are implemented. Workspace/repository views currently read membership-based Firestore data; self-service workspace creation and GitHub repository discovery are planned in scope 16.

Publish [Firestore Rules](firebase/firestore.rules) manually using the Firebase Console. Local code changes do not update the deployed Rules. See [user-only access and troubleshooting](docs/project/15-user-only.md). End-to-end GitHub/profile access on Firebase still needs user confirmation.

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
