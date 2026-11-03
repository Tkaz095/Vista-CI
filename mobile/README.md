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

Phạm vi hiện tại: đăng nhập GitHub, tạo hồ sơ Firestore nếu chưa có và mở Home với danh sách dự án GitHub. `lib/features/` được giữ nguyên, chưa nối vào luồng này.

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
5. `lib/data/services/firebase_auth_service.dart`: gọi SDK đăng nhập GitHub, giữ GitHub access token trong bộ nhớ và xóa token khi logout thành công.
6. `lib/data/services/firestore_profile_service.dart`: dùng transaction để trả hồ sơ đã có hoặc tạo `users/{uid}`. Hồ sơ hiện có được giữ nguyên.
7. `lib/data/models/`: identity, profile và dữ liệu tạo profile; role được lưu dưới dạng chuỗi.
8. `lib/ui/home/home_view.dart`: tạo và hủy ProjectsViewModel theo phiên Home, hiển thị user và nút logout.

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

## Quản lý project

Home hiển thị project của tài khoản Firebase hiện tại. User có thể tạo project rỗng hoặc chọn repo GitHub, xem chi tiết, sửa tên/mô tả/danh sách repo và xóa project. Một repo có thể nằm trong nhiều project; mỗi project không chứa ID repo trùng nhau. Xóa project chỉ xóa nhóm quản lý trong Vista.

```text
ProjectsView / ProjectFormView → ProjectsViewModel → ProjectRepository
                                                      ├── FirestoreProjectService
                                                      └── GitHubService
```

Chỉ thêm ba file runtime: `data/models/project.dart` (Project và ProjectRepo), `data/services/firestore_project_service.dart` và `ui/projects/project_form_view.dart`. ViewModel quản lý hành vi/trạng thái; View giữ controller nhập liệu, điều hướng và xác nhận xóa. Repository kiểm tra dữ liệu trước khi ghi. Các service khởi tạo trực tiếp, không có constructor dành riêng cho test.

### Dữ liệu Firestore

```text
users/{Firebase uid}/projects/{Firestore-generated projectId}
  name: string (1–100 ký tự sau trim)
  description: string (0–1000 ký tự sau trim)
  repositories: [{ id: GitHub integer ID, fullName: owner/repo }, ...]
  createdAt: server timestamp
  updatedAt: server timestamp
```

Giới hạn 50 repo/project để document gọn. `ProjectRepo` chỉ lưu ID và tên để hiển thị; không lưu OAuth token, log hoặc dữ liệu CI. Tên repo là ảnh chụp tại lúc chọn, không phải bằng chứng quyền GitHub. Khi đọc dữ liệu GitHub/CI, quyền truy cập vẫn do GitHub kiểm tra. Sửa danh sách repo ghi lại mảng trong một document; với đồ án này, lần lưu sau cùng sẽ có hiệu lực nếu cùng project được sửa trên hai thiết bị.

`ProjectPreferencesService` được tạm ngắt hoàn toàn khỏi repository và ViewModel. File và dữ liệu SharedPreferences cũ vẫn giữ nguyên, không tự di chuyển vào project.

### Luồng thao tác

1. Home tải project từ Firestore theo UID, độc lập với token/kết nối GitHub.
2. Mở form tạo/sửa mới tải repo GitHub để chọn. Repo đã lưu vẫn giữ trong bản nháp nếu GitHub lỗi hoặc không trả lại repo đó; user có thể bỏ chọn thủ công.
3. Bấm Lưu: kiểm tra tên, mô tả, số lượng/ID/tên repo, sau đó tạo hoặc cập nhật Firestore. UI chặn bấm lưu trùng.
4. Lưu lỗi: form, tên và lựa chọn được giữ để thử lại. Lưu thành công: tải lại danh sách và đóng form. Nếu chỉ bước tải lại lỗi, danh sách báo lỗi; không yêu cầu user tạo lại project đã lưu.
5. Xóa cần xác nhận. Xóa lỗi giữ project; thành công bỏ project khỏi danh sách.

### Rules cần được publish

File `../firebase/firestore.rules` đã bổ sung quyền tại `users/{uid}/projects/{projectId}`. Rules chỉ cho chính user có profile `role=user`, `isActive=true` truy cập; kiểm tra danh sách field, độ dài tên/mô tả, kiểu list/tối đa 50 repo và server timestamps. Kiểu/ID từng phần tử repo được kiểm tra tại repository; dữ liệu này chỉ là lựa chọn cá nhân, không cấp quyền GitHub. Rules profile/workspace trước đó được giữ nguyên.

**Publish toàn bộ file Rules qua Firebase Console → Firestore Database → Rules trước khi thử trên tài khoản thật.** Sửa file local không cập nhật Rules đã triển khai. App sẽ báo lỗi quyền nếu project đang dùng Rules cũ. Chưa deploy Rules lên Firebase trong lần sửa này.

### Quyền GitHub

Luồng auth vẫn xin scope OAuth `repo`, lấy token từ `result.credential?.accessToken` và chỉ giữ token trong bộ nhớ. Scope này gồm quyền đọc và ghi; tính năng hiện chỉ đọc `GET /user/repos`. GitHubService tải đủ các trang với `visibility=all`, `affiliation=owner,collaborator,organization_member`. Dữ liệu thực tế còn phụ thuộc scope đã cấp và chính sách organization/SSO.

Test tự động kiểm tra model, input không hợp lệ, CRUD/ViewModel/UI, lỗi GitHub/Firestore, thao tác trùng, hủy ViewModel và màn hình nhỏ. Luồng OAuth và SDK Firestore trên Android vẫn cần thử với project Firebase hiện tại sau khi publish Rules.

## Các tính năng tiếp theo

Đọc workflow runs/jobs/logs, lưu báo cáo và tích hợp các dịch vụ Firebase tiếp theo sẽ được bổ sung vào từng repo trong project sau. Code hiện có trong `lib/features/` được giữ nguyên để tham khảo và tích hợp ở giai đoạn đó.

Tài liệu backend chung với web: `../docs/project/22-complete-workspace-cicd-mobile.md`.
