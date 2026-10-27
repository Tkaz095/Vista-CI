# Vista CI

Vista CI is a mobile app and web dashboard for viewing CI/CD pipeline status, build history, and deployment notifications.

## Project structure

- `mobile/` — Flutter mobile app
- `web/` — React + TypeScript dashboard powered by Vite
- `.github/workflows/` — GitHub Actions workflows

Both clients will connect to the same Firebase project. Firebase setup and deployment workflows will be added after the Firebase project and app identifiers are configured.

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
