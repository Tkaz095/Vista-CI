# Build Android trên GitHub, chạy bằng Genymotion

Máy cá nhân dùng để viết code, chạy kiểm tra Dart và mở Genymotion. GitHub Actions đảm nhiệm build APK, bao gồm cài Android SDK/NDK cần thiết trên runner. Không cần cài thêm NDK trên máy cá nhân để sử dụng APK từ workflow.

## Chạy lần đầu

1. Đưa các thay đổi Firebase Android và `.github/workflows/android-build.yml` lên nhánh `main`. File `mobile/android/app/google-services.json` là cấu hình client của project `vista-ci` và phải có trong commit này.
2. Mở repository trên GitHub → **Actions** → **Android APK**.
3. Push thay đổi trong `mobile/` lên `main` sẽ tự chạy workflow. Có thể chọn **Run workflow** để chạy thủ công khi workflow đã có trên nhánh mặc định.
4. Chờ job **Analyze and build Android APK** thành công. Mở phần summary hoặc **Artifacts** để tải file `.apk`.
5. Mở thiết bị Genymotion và kéo file APK vào cửa sổ thiết bị để cài. Mở **Vista CI** trong danh sách ứng dụng.

APK được tải trực tiếp, không cần giải nén. Artifact được giữ trong 7 ngày; nếu hết hạn, chạy lại workflow để tạo APK mới.

## Chọn kiến trúc

Mặc định workflow chỉ build `android-x64`, phù hợp với thiết bị Android `x86_64` thường dùng trên Genymotion Desktop. Build một kiến trúc giảm kích thước APK và lượng công việc so với APK đa kiến trúc.

Nếu thiết bị dùng ARM64, chọn **Run workflow → target → android-arm64**. Nếu chưa biết kiến trúc, chọn **all** để build APK chứa các kiến trúc Android được Flutter hỗ trợ; file sẽ lớn hơn. Khi có ADB, có thể kiểm tra bằng:

```bash
adb shell getprop ro.product.cpu.abi
```

`x86_64` tương ứng `android-x64`; `arm64-v8a` tương ứng `android-arm64`.

## Vòng lặp phát triển

- Sửa code và kiểm tra nhanh bằng `flutter analyze` trong `mobile/`. Có thể chạy web riêng bằng `npm run dev` trong `web/`.
- Push hoặc mở pull request có thay đổi mobile để GitHub kiểm tra mã và build APK.
- Tải APK mới và cài lên Genymotion khi cần kiểm tra giao diện, Firebase hoặc chức năng Android.

APK chạy trực tiếp trên Genymotion với cấu hình Firebase Android hiện tại. Cách này chưa có hot reload: thay đổi code cần một lần build và cài lại APK. Khi cần phát triển UI liên tục với hot reload, có thể quay lại build local sau khi đủ dung lượng.

## Những gì workflow thực hiện

- Kiểm tra file Firebase đúng project và Android package trước khi tải toolchain.
- Dùng Flutter `3.47.5`, Java `21`, và dependencies từ `pubspec.lock`.
- Chạy `flutter analyze`, sau đó build debug APK.
- Cache Flutter, pub dependencies và Gradle; hủy lần chạy cũ của cùng ref khi có lần chạy mới.
- Cache debug signing key để giảm việc đổi chữ ký giữa các lần build. Cache có thể bị hết hạn hoặc không dùng chung giữa mọi nhánh. Nếu cài cập nhật báo chữ ký không khớp, cần gỡ bản debug cũ trước khi cài lại; thao tác đó xóa dữ liệu local của app. Bản phát hành sau này cần khóa ký ổn định riêng.

Đây là bản debug phục vụ kiểm tra, chưa phải bản ký để phát hành lên Google Play. Workflow tạo APK và artifact tải xuống; Auth, Firestore, FCM và deploy web lên Firebase Hosting là các bước tiếp theo.

## Trạng thái kiểm chứng

Cấu hình Firebase Android đã qua `flutter analyze`. Build local trước đó dừng khi tải NDK do ổ đĩa thiếu dung lượng. Chỉ một lần chạy GitHub Actions thành công mới xác nhận build APK trên cloud; cần mở app trên thiết bị Android để xác minh khởi tạo Firebase lúc chạy.
