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

Enable GitHub sign-in in Firebase Authentication and publish the project Firestore Rules before testing OAuth on a device. iOS Firebase setup is not included yet; use Android for this milestone.

## Luồng auth đang chạy

Phạm vi hiện tại: đăng nhập GitHub, tạo hồ sơ Firestore nếu chưa có và mở trang Home tối thiểu. `lib/features/` được giữ nguyên, chưa nối vào luồng này.

```text
AuthView → AuthViewModel → AuthRepository
                              ├── FirebaseAuthService
                              └── FirestoreProfileService
```

Đọc code theo thứ tự:

1. `lib/main.dart`: khởi tạo Firebase và tạo ViewModel.
2. `lib/ui/auth/auth_view.dart`: hiển thị Login khi chưa có profile, Home khi đã có profile.
3. `lib/ui/auth/auth_view_model.dart`: quản lý `profile`, `busy` và thông báo lỗi bằng `ChangeNotifier`.
4. `lib/data/repositories/auth_repository.dart`: chạy đăng nhập GitHub, tạo dữ liệu hồ sơ ban đầu, lấy hoặc tạo hồ sơ và trả `UserProfile`.
5. `lib/data/services/firebase_auth_service.dart`: gọi SDK đăng nhập GitHub và logout.
6. `lib/data/services/firestore_profile_service.dart`: dùng transaction để trả hồ sơ đã có hoặc tạo `users/{uid}`. Hồ sơ hiện có được giữ nguyên.
7. `lib/data/models/`: identity, profile và dữ liệu tạo profile; role được lưu dưới dạng chuỗi.
8. `lib/ui/home/home_view.dart`: hiển thị user và nút logout.

### Quy trình đăng nhập

```text
Bấm GitHub → busy = true → Firebase xác thực
  → đọc users/{uid}
  → chưa có: tạo displayName, role user, isActive true
  → trả UserProfile → busy = false → mở Home
```

Nếu login hoặc ghi Firestore thất bại, màn hình Login hiển thị lỗi và cho phép bấm lại. Đăng xuất thành công đặt `profile = null` để trở về Login.

Repo và service khởi tạo dependency trực tiếp. App bắt đầu ở Login mỗi lần mở; phần tự khôi phục giao diện theo phiên, theo dõi profile realtime và chính sách quyền sẽ triển khai sau. Luồng này giữ nguyên role/isActive của hồ sơ đã có.

### Kiểm tra

```bash
flutter analyze
flutter test
flutter build apk --debug
```

Test model và giao diện dùng repository giả trong thư mục test; production service không có constructor hoặc nhánh dành riêng cho test. OAuth và Firestore thực tế cần được kiểm tra trên thiết bị với Firebase project hiện tại.

## Các tính năng tiếp theo

Workspace CRUD, kết nối GitHub backend và theo dõi CI/CD sẽ được triển khai từ trang Home sau. Code hiện có trong `lib/features/` được giữ nguyên để tham khảo và tích hợp ở giai đoạn đó.

Tài liệu backend chung với web: `../docs/project/22-complete-workspace-cicd-mobile.md`.
