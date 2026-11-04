# Analytics, Crashlytics và Remote Config — Flutter Android

Triển khai 04–05/11/2026. FirebaseApp mặc định là `vista-ci`; project AI riêng giữ nguyên. Analytics plan được viết trước tracking tại [analytics-plan.md](analytics-plan.md).

## Phần code đã có

- `FirebaseAnalyticsService` bọc Analytics SDK. 12 event đã nối vào Auth/Projects/ProjectDetail/WorkflowRun ViewModels. Ghi sau kết quả nghiệp vụ, không từ build; restore/reconnect không nhân đôi login.
- `TelemetryService` serialize UID và event theo từng sink, tách hai hàng đợi để lỗi Analytics không chặn Crashlytics. Có timeout, thông báo lỗi cục bộ và không ném lỗi SDK ngược vào thao tác người dùng. Khi đặt/xóa UID thất bại, sink đó ngừng nhận thêm event/report cho đến một lần identify thành công.
- `FirebaseCrashReportingService` cài `FlutterError.onError` và `PlatformDispatcher.instance.onError`, bật collection và key `build_mode`. Các catch thực tế của auth, project, run/log, Gemini, lưu phân tích, rerun, PR/comment và config gọi non-fatal. Report có key `app_area`, chỉ giữ tên operation/loại exception và stack; không gửi raw error/message hay log CI.
- `AppConfigViewModel` fetch nền lúc bootstrap, state Loading/Success/Empty/Error, có retry trong Profile. Lỗi fetch dùng defaults local và hiện thông báo. Không chặn Login/Home khi Remote Config không khả dụng.
- Profile có **Cấu hình ứng dụng**; bản debug có **Kiểm tra tích hợp · Debug**, nút non-fatal và nút crash cần xác nhận. Release/profile không dựng vùng test; service/ViewModel cũng kiểm tra `kDebugMode`.
- Android đã khai báo Crashlytics Gradle plugin `3.0.8` trong settings và apply ở app. Không thêm BoM/native SDK trùng vì các FlutterFire plugin quản lý dependency native.

## Remote Config parameters

Tạo trong project chính và Publish:

| Key | Kiểu | Default trong app | Tác động |
|---|---|---|---|
| `ci_analysis_enabled` | Boolean | `true` | `false` chặn prepare/analyze mới và hiển thị thông báo ở run/analysis. Phân tích đang chạy được hoàn tất; bản đã lưu vẫn đọc được; rerun/comment không bị khóa. |
| `project_repo_page_size` | Number, số nguyên | `5` | Số repo mỗi trang tổng quan project, giới hạn 1–20. Áp dụng khi mở project, refresh tổng quan hoặc bấm tải thêm; không cắt danh sách repo đã lưu trong project. |

Thiếu/sai kiểu dùng default từng key; page size ngoài khoảng được clamp 1–20. Fetch thất bại dùng toàn bộ local defaults, không dùng kết quả cấu hình lỗi. Debug fetch interval bằng 0 để demo; release/profile 12 giờ, fetch timeout 10 giây. Không dùng Remote Config làm quyền truy cập hay nơi chứa secrets. Các giá trị áp dụng sau fetch/activate thành công; không có realtime subscription trong bước này.

Ví dụ demo: publish `false` và `2` → Profile **Cập nhật cấu hình** → thấy “Tắt”/“2” → mở project có ≥3 repo thấy trang đầu 2 repo → mở run lỗi thấy phân tích mới tạm tắt. Publish lại `true` → cập nhật → có thể phân tích. Tắt mạng rồi cập nhật → thông báo fallback, giá trị `true`/`5`, các luồng khác vẫn dùng được.

## Cấu hình Console và cấu hình Firebase

1. Mở đúng project `vista-ci`, app Android `com.vista.vista_mobile`. Bật/liên kết Google Analytics nếu project chưa có, mở Crashlytics hoàn tất phần bắt đầu và tạo hai Remote Config parameter trên.
2. Repo đã có FlutterFire Android config. Lần tích hợp này giữ nguyên `google-services.json`, `firebase_options.dart` và project AI; không tự tạo/thay Firebase app trên Console. Gradle plugin được cập nhật trực tiếp trong repo và đã kiểm tra bằng build Android.
3. Khi app Firebase cần đồng bộ lại cấu hình, chạy trong `mobile/`: `flutterfire configure --project=vista-ci --platforms=android --android-package-name=com.vista.vista_mobile`. Kiểm tra diff để không thay cấu hình project AI hoặc đăng ký app ngoài phạm vi. Không chạy lại configure chỉ để thử event.
4. Rebuild và cài APK mới; hot reload không thêm native plugins.

## Thu bằng chứng trên Android

Analytics DebugView:

```bash
adb shell setprop debug.firebase.analytics.app com.vista.vista_mobile
```

Mở app → GitHub login → tạo/sửa project → mở project/run → phân tích CI thử nghiệm. Trong DebugView đối chiếu event và parameters với plan; logout/đổi tài khoản kiểm tra User ID được xóa/đổi. Không gửi repo name, email, log, prompt hoặc comment lên Analytics. Khi xong:

```bash
adb shell setprop debug.firebase.analytics.app .none.
```

Crashlytics: dùng APK debug → Profile → vùng Debug → gửi non-fatal. Tìm operation `debugTest` trong Console, custom key `build_mode=debug` và `app_area=debugTest`. Thử crash cần xác nhận; app sẽ đóng và phải mở lại để gửi báo cáo. Có thể cần chờ Console xử lý. Nút báo “đã xếp hàng” không chứng minh server đã nhận. Các lỗi Dart global được đánh dấu fatal; native crash test/ANR do SDK native xử lý.

Bằng chứng cần lưu: commit, ngày, thiết bị/API Android, DebugView, non-fatal/fatal report, UID/custom keys, Remote Config published values và ảnh UI thay đổi/fallback. Không chụp token, email hoặc dữ liệu repo riêng tư vào báo cáo công khai.

## Kiểm tra local và giới hạn

Kết quả local ngày 05/11/2026: `flutter analyze --no-pub` không có issue, toàn bộ **121 test passed**, `flutter build apk --debug --target-platform android-x64 --no-pub` thành công. APK nằm tại `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

Các test dùng fake Analytics/Crash sinks và fake Remote Config source để kiểm tra thứ tự UID, filtering, failure isolation, login/restore/reconnect, event sau write, cấu hình ảnh hưởng phân trang và AI, fallback UI và xác nhận crash. Không gọi Gemini/GitHub thật và không tạo crash thật trong test.

Build APK chỉ chứng minh native dependencies/Gradle biên dịch được; unit/widget tests không chứng minh event/report đã lên Firebase. ADB chưa có thiết bị kết nối ở lần kiểm tra này; chưa thu bằng chứng Console hoặc bật/thay tham số trên Firebase project.

Nguồn API: [Analytics events](https://firebase.google.com/docs/analytics/flutter/events), [Crashlytics Flutter](https://firebase.google.com/docs/crashlytics/flutter/get-started), [Crashlytics Android Gradle](https://firebase.google.com/docs/crashlytics/android/get-started), [Remote Config Flutter](https://firebase.google.com/docs/remote-config/flutter/get-started), [Analytics DebugView](https://firebase.google.com/docs/analytics/debugview).
