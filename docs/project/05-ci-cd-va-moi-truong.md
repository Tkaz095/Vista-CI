# 05. CI/CD và môi trường làm việc

**v0.3 - Hạ tầng đã có và kế hoạch tiếp theo - 01/11/2026**

## 1. Phương án nhẹ đã chọn

Viết code và xem web trên máy cá nhân; build Android trên GitHub; tải APK về Genymotion. GitHub runner cài SDK/NDK để build. Genymotion là thiết bị chạy APK, không thay thế bộ công cụ build.

Hành vi Android vẫn được kiểm tra bằng APK thật. Đổi code cần một lần build và cài APK mới; chưa có hot reload qua quy trình này. Không cần tiếp tục tải NDK local để sử dụng APK cloud. Không xóa SDK/NDK hoặc file cá nhân ở bước làm tài liệu.

## 2. Workflow Android hiện có

Nguồn: `.github/workflows/android-build.yml`.

| Hạng mục | Cấu hình hiện có |
| --- | --- |
| Trigger | Push `main` có thay đổi mobile/workflow; pull request có path tương ứng; chạy thủ công |
| Runner | `ubuntu-24.04`, timeout 30 phút |
| Toolchain | Flutter `3.47.5`, Java `21` |
| Cấu hình Firebase | Kiểm tra project `vista-ci` và package `com.vista.vista_mobile` |
| Dependencies | `flutter pub get --enforce-lockfile` |
| Check | `flutter analyze --no-pub` |
| Build mặc định | Debug APK `android-x64` |
| Chạy thủ công | Chọn `android-x64`, `android-arm64` hoặc `all` |
| Cache | Flutter/pub, Gradle, debug signing key theo cơ chế cache |
| Tối ưu | Hủy run cũ cùng ref khi có run mới; artifact giữ 7 ngày |
| Kết quả | File `.apk` tải trực tiếp, không cần giải nén artifact |

Bằng chứng chạy: [run 41219589321](https://github.com/Tkaz095/Vista-CI/actions/runs/41219589321), commit `b1771ef`, kết quả success. PR #1 đã merge vào `main` ngày 01/11/2026. Checkout local tại lúc soạn vẫn ở `ci/android-cloud-build`; tài liệu này không chuyển nhánh hay push gì thêm.

Đây là CI + phân phối APK demo. Chưa có test nghiệp vụ tự động trong workflow, chưa phát hành Play Store, chưa deploy web và chưa ghi kết quả run vào Firestore.

## 3. Thao tác chạy APK sau khi người dùng chọn kiểm tra

1. Mở GitHub repository → Actions → Android APK.
2. Chọn một run success; tải APK tương ứng.
3. Mở Genymotion đúng kiến trúc và kéo APK vào thiết bị để cài.
4. Mở Vista CI; kiểm tra app chạy và Firebase Core khởi tạo.

Đã có file local lịch sử tại:

```text
/home/kien/Downloads/Vista-CI/vista-ci-debug-android-x64-b1771ef.apk
```

File này chứng minh bản build nền tảng cũ; nó chưa có đăng nhập/Firestore data hay toàn bộ nghiệp vụ đề xuất trong bộ tài liệu.

APK cloud mặc định có Flutter runtime x86_64. ARM64 cần build target ARM64; `all` tăng dung lượng nhưng hỗ trợ nhiều kiến trúc hơn. Khi có ADB có thể kiểm tra bằng `adb shell getprop ro.product.cpu.abi`. Xem chi tiết ở [hướng dẫn Android](../android-cloud-build.md).

Debug signing key đang được cache, không phải khóa phát hành ổn định. Cache có thể hết hạn hoặc khác theo phạm vi nhánh; nếu chữ ký đổi phải gỡ bản debug trước khi cài lại, mất dữ liệu local. Chỉ thiết kế release signing khi bước phân phối chính thức được duyệt.

## 4. CI web và Hosting - kế hoạch, chưa tạo workflow

Đề xuất một workflow riêng cho `web/**` để thay đổi web không buộc build Android:

```text
PR web -> npm ci -> npm run lint -> npm run build -> kết quả CI
Merge main -> cùng kiểm tra -> deploy web/dist lên Firebase Hosting -> URL kiểm tra
```

Dùng Node phù hợp package/Vite đang khóa; Node 24 là lựa chọn tương thích đề xuất, chưa phải runtime CI web đã cấu hình. Cache npm; giữ deployment trên nhánh/môi trường được duyệt. Preview PR là tùy chọn sau, không cần mặc định để demo nhẹ.

Thiết lập Hosting dự kiến ở repo root:

| Mục | Giá trị đề xuất |
| --- | --- |
| Firebase project | `vista-ci` |
| Sản phẩm | Firebase Hosting cho SPA tĩnh |
| Public directory | `web/dist` |
| SPA fallback | Các route ứng dụng quay về `index.html` |
| Build trước deploy | Trong `web/`, chạy `npm ci`, lint và build |
| Đăng nhập/deploy quyền | Tài khoản Firebase do người dùng kiểm soát |

Không dùng Firebase App Hosting/SSR cho React Vite SPA này. Cấu hình Firebase web, Auth/Firestore SDK và index/rules phải hoàn thành trước khi coi URL web là app tích hợp thật.

Firebase có tích hợp GitHub Hosting với credential service account lưu trong GitHub Secret. Đây là cấu hình tương lai; không yêu cầu người dùng gửi private key trong chat hay commit vào repo. [Firebase Hosting GitHub integration](https://firebase.google.com/docs/hosting/github-integration?hl=en).

## 5. Publisher dữ liệu - kế hoạch riêng

Workflow build hiện có chỉ xuất APK. Đề xuất thêm publisher kết quả workflow hoàn tất theo kiến trúc tài liệu 03:

- Nhánh/default workflow tin cậy; allowlist repo ID, source event và branch.
- Đọc kết quả từ GitHub, không lấy kết luận do client gửi.
- Ghi run vào Firestore bằng credential server giới hạn quyền; không expose cho workflow PR/fork tùy ý.
- Retry/upsert cùng `{runId}_{attempt}`. Tách lỗi đồng bộ khỏi kết quả build.
- Ở giai đoạn FCM sau MVP đã chốt, sender có thể chạy cùng publisher sau khi dữ liệu hợp lệ; không coi đó là backend để tùy ý chạy lệnh từ client.

`workflow_run` là cơ chế có thể mang quyền cao hơn workflow nguồn, cần kiểm tra event trước khi dùng credential; không checkout/chạy mã nguồn PR trong publisher. [GitHub workflow_run](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run).

## 6. Quota và chi phí cần đánh giá

- Giữ mục tiêu Spark nếu tính năng chỉ cần Auth, Firestore, Hosting và FCM trong giới hạn được hỗ trợ; không hứa toàn bộ dự án miễn phí trong mọi tình huống.
- Cloud Functions deploy yêu cầu Blaze; không tự nâng cấp billing để làm nút điều khiển workflow.
- Dùng Firestore thay vì Cloud Storage để lưu metadata; APK/log vẫn ở GitHub. Không yêu cầu Cloud Storage cho MVP.
- Giới hạn query/listener, không đọc toàn bộ lịch sử mỗi lần render; hủy listener khi đóng màn hình.
- Không đặt số phút CI/quota Firebase cố định trong đặc tả; kiểm tra theo tài khoản/plan thực tế lúc triển khai. Screenshot trước cho thấy Spark, chưa có kiểm tra billing trực tiếp trong lần soạn.

Nguồn: [Firebase pricing](https://firebase.google.com/pricing), [Firebase Functions](https://firebase.google.com/docs/functions).

## 7. Cách làm việc tiếp theo

Sau khi bạn duyệt thiết kế, hướng dẫn từng bước và chờ bạn thực hiện. Tách các thay đổi nhỏ để dễ review: Auth; dữ liệu/rules; publisher; web CI/CD; backend và nút chạy/chạy lại bắt buộc; FCM ở giai đoạn sau MVP đã chốt. Việc đọc/duyệt bộ tài liệu chưa phải yêu cầu tự viết code, commit, push hoặc deploy.
