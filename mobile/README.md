# Vista CI Mobile

The Flutter client for Vista CI.

## Recommended: cloud build + Genymotion

Use the **Android APK** GitHub Actions workflow to build the app, then download the APK and drag it into Genymotion. This avoids installing another Android NDK on your workstation. See [the cloud build guide](../docs/android-cloud-build.md) for the first run, architecture selection, and signing limitations.

## Run locally (requires the Android build toolchain)

```bash
flutter pub get
flutter run
```

Firebase Core is configured for Android with project `vista-ci` and package ID `com.vista.vista_mobile`. The Android Google Services Gradle plugin reads `android/app/google-services.json`; `main.dart` initializes Firebase before starting the app.

Authentication, Firestore, and notifications still need to be configured. iOS Firebase setup is not included yet; run on an Android device or emulator for this milestone.

## Flutter architecture (MVVM)

The structure below is the target layout as the mobile app grows. The current app is a small prototype in `lib/main.dart`; authentication, repositories, and the other listed files have not been implemented yet. Add folders and files when their features are built.

```text
lib/
├── main.dart                         # Entry point; initializes Firebase and starts the app
├── core/                             # App-wide configuration and utilities
│   ├── constants/                    # Shared colors, strings, and non-secret constants
│   │   ├── app_colors.dart
│   │   └── app_constants.dart
│   ├── di/
│   │   └── locator.dart              # Dependency registration, if/when needed
│   ├── routes/
│   │   └── app_router.dart
│   └── theme/
│       └── app_theme.dart
├── data/                             # Data access and domain models
│   ├── models/
│   │   ├── app_user.dart
│   │   ├── project.dart
│   │   ├── run_history.dart
│   │   └── ai_summary.dart
│   ├── repositories/                 # Data sources exposed to ViewModels
│   │   ├── auth_repository.dart
│   │   ├── project_repository.dart
│   │   ├── workflow_repository.dart
│   │   └── action_repository.dart
│   └── services/                     # Firebase and backend SDK access
│       ├── firebase_auth_service.dart
│       ├── firestore_service.dart
│       ├── cloud_functions_service.dart
│       └── firebase_messaging_service.dart
└── ui/                               # Views, ViewModels, and reusable widgets
    ├── auth/
    │   ├── login_view.dart
    │   └── login_view_model.dart
    ├── dashboard/
    │   ├── dashboard_view.dart
    │   └── dashboard_view_model.dart
    ├── workflow/
    │   ├── run_list_view.dart
    │   ├── run_list_view_model.dart
    │   ├── run_detail_view.dart
    │   └── run_detail_view_model.dart
    └── shared_widgets/
        ├── custom_button.dart
        ├── loading_overlay.dart
        ├── ai_alert_card.dart
        └── status_badge.dart
```

### MVVM responsibilities and data flow

- **View** (`login_view.dart`) renders state and forwards user actions, such as tapping **Sign in**. It does not call Firebase directly.
- **ViewModel** (`login_view_model.dart`) validates view input, calls the repository, and exposes UI state such as loading, signed-in user, or an error message. It does not depend on Flutter widgets.
- **Repository** (`auth_repository.dart`) provides the authentication operations to the ViewModel and coordinates data sources. It keeps the ViewModel independent of Firebase details.
- **Service** (`firebase_auth_service.dart`) wraps Firebase Auth SDK calls and returns authentication results to the repository.
- **Model** (`app_user.dart`) represents user data used by the app; it is not the UI state itself.

Example sign-in flow:

```text
User taps Sign in
  → LoginView calls LoginViewModel.signIn(email, password)
  → LoginViewModel sets loading state and calls AuthRepository.signIn(...)
  → AuthRepository delegates to FirebaseAuthService.signIn(...)
  → FirebaseAuthService calls Firebase Auth and returns the result
  → Repository returns the app-level result to the ViewModel
  → ViewModel updates loading/user/error state
  → LoginView redraws from that state and routes on success
```

### Naming conventions

- Use `snake_case.dart` for Dart file names, for example `login_view_model.dart`.
- Use `UpperCamelCase` for types, for example `LoginViewModel` and `AppUser`.
- Use `lowerCamelCase` for methods, parameters, and variables, for example `signIn`, `email`, and `isLoading`.
- Use `lowerCamelCase` for constants too; use `const` or `static const` to mark them, for example `defaultPageSize`.
- Prefix private Dart identifiers with `_`, for example `_firebaseAuth`.
- Keep ViewModels paired with their Views and named after the feature. Put genuinely reusable UI components in `shared_widgets/`.

Do not put API keys or other secrets in `core/constants/`; use platform configuration or a secret store appropriate to the environment.
