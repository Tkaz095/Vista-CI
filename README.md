# Vista CI

Vista CI is a mobile app and web dashboard for viewing CI/CD pipeline status, build history, and deployment notifications.

## Project structure

- `mobile/` — Flutter mobile app
- `web/` — React + TypeScript dashboard powered by Vite
- `.github/workflows/` — GitHub Actions workflows

Both clients will connect to the same Firebase project. Firebase Core is configured for Android with project `vista-ci`; the web client is not connected yet.

## Android cloud build

The **Android APK** GitHub Actions workflow analyzes the Flutter code and builds a development APK on GitHub. Download the APK from the successful run and drag it into Genymotion. The default target is `android-x64`; manual runs also support ARM64 or a universal APK.

See [the setup and installation guide](docs/android-cloud-build.md). Building on GitHub avoids downloading another NDK on the local machine. Workflow execution still needs to be confirmed by a successful run after the changes are pushed.

## Requirements

- Flutter stable SDK
- Node.js 20.19+ or 22.12+
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
