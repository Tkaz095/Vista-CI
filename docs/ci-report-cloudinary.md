# Xuất báo cáo CI và upload Cloudinary

Quyết định 05/11/2026: dùng Cloudinary thay Firebase Cloud Storage theo yêu cầu người dùng, ưu tiên luồng đơn giản. Không cần nâng billing Firebase để chạy phần này. GitHub/Firebase Auth, Analytics, Crashlytics và Remote Config giữ nguyên.

## Cách dùng

Mở project → repository → run lỗi → Phân tích CI → biểu tượng **Xuất báo cáo PDF** trên header.

App tạo PDF ngay trên thiết bị từ phân tích hiện có, không gọi Gemini lại. Báo cáo gắn đúng repo/run/attempt/SHA và thời điểm xuất, có tóm tắt, nguyên nhân có khả năng, đề xuất, bằng chứng, thông tin còn thiếu và cảnh báo AI. Font Inter đóng gói hỗ trợ tiếng Việt; không tải font qua mạng.

- **Lưu / chia sẻ PDF** mở trình chia sẻ của Android, dùng được cả khi Cloudinary chưa cấu hình hoặc upload lỗi.
- **Upload lên Cloudinary** gửi PDF, hiển thị phần trăm và cho hủy. Khi thành công có **Mở bản trên đám mây**.
- Lỗi upload giữ PDF để thử lại. Đổi tài khoản hoặc rời màn hình hủy request đang chạy và bỏ kết quả trễ; không xóa asset đã được provider nhận trước đó.

Đây là unsigned upload và liên kết PDF công khai. UID trong public_id chỉ để nhóm file, không phải quyền owner-only của Cloudinary. UI thông báo rõ trước khi upload. Không đặt API secret trong APK, Remote Config hoặc source. Phân quyền riêng tư, xóa file, lịch sử báo cáo và backend ký upload nằm ngoài bước này.

## Cấu hình một lần trên Cloudinary

1. Tạo/dùng tài khoản Cloudinary; lấy **Cloud name** của product environment.
2. Settings → Upload → Upload presets → tạo preset, chọn **Signing mode: Unsigned**. Ghi lại tên preset.
3. Giới hạn định dạng PDF trong preset. Giới hạn 5 MiB (5,242,880 bytes) do app kiểm tra; Cloudinary không có giới hạn kích thước riêng theo preset. Không bật tùy chọn chặn public_id từ client nếu muốn giữ cách nhóm file của app. Unsigned upload không ghi đè asset đã có.
4. Settings → Security → bật **Allow delivery of PDF and ZIP files** nếu tài khoản Free đang chặn PDF delivery.

App gửi `multipart/form-data` tới `https://api.cloudinary.com/v1_1/{cloud_name}/raw/upload`: `file` (application/pdf), `upload_preset`, `public_id`. Không gửi API secret, API key hoặc Firebase ID token. Public ID có dạng `vista-ci/reports/{uid}/ci_{repoId}_{runId}_{attempt}_{timestamp}.pdf`.

## Cấu hình trên Firebase Remote Config, không cần hardcode

Trong project chính **vista-ci**, chọn Remote Config → **Client**, tạo đủ ba parameter sau (Default value), rồi Publish:

| Parameter | Data type | Giá trị |
|---|---|---|
| `ci_analysis_enabled` | Boolean | `true` |
| `cloudinary_cloud_name` | String | Cloud name từ Cloudinary |
| `cloudinary_upload_preset` | String | Tên unsigned preset vừa tạo |

`project_repo_page_size` đã bỏ; tổng quan project cố định 5 repo mỗi trang. Nếu đã tạo key này trên Console, có thể xóa.

Bấm **Publish changes**. Cài APK mới có tính năng report; vào Profile → **Cập nhật cấu hình** rồi upload báo cáo. Những lần đổi cloud name/preset sau đó không cần build lại APK; service đọc cấu hình hiện hành mỗi lần upload. Bản debug fetch ngay; bản release dùng minimum fetch interval 12 giờ như cấu hình chung hiện có.

Đây là hai giá trị công khai phù hợp với Remote Config. `.env` của Firebase Functions chỉ dành cho server và không tự xuất hiện trong Flutter. Không lưu Cloudinary API secret vào Remote Config.

Fallback mặc định của hai key là chuỗi rỗng: chưa cấu hình thì upload báo lỗi dễ đọc, PDF local vẫn hoạt động. Đổi cấu hình trong khi một upload đang chạy chỉ ảnh hưởng request sau. Developer có thể dùng `--dart-define=CLOUDINARY_CLOUD_NAME=... --dart-define=CLOUDINARY_UPLOAD_PRESET=...` làm fallback local; không cần cách này khi dùng Remote Config.

## Code và kiểm thử

- `CiReportSnapshot` chốt dữ liệu của attempt hiện tại; `CiReportPdfService` tạo PDF offline.
- `CiReportRepository` phối hợp generator, storage và sharing.
- `CloudinaryReportStorageService` bọc HTTP multipart và xác minh secure_url; request không tự retry. Timeout hoặc hủy có thể xảy ra sau khi Cloudinary đã nhận file, nên không bảo đảm không có asset dư khi thử lại. Dùng Media Library để kiểm tra/xóa nếu cần.
- `CiReportViewModel` giữ state/progress, bỏ callback sau dispose/đổi UID và ghi hai event `ci_report_export`, `ci_report_upload`; telemetry không chứa URL, filename hoặc nội dung PDF.
- Test dùng fake repositories, HTTP server loopback và Postman stand-in. Không gửi báo cáo thật lên Cloudinary trong test tự động.

Chạy ở `mobile/`: `flutter analyze --no-pub`, `flutter test --no-pub`.

Kết quả local 05/11/2026: analyze không có issue; toàn bộ **139 tests passed** khi bật simulation, gồm 18 test mới cho báo cáo. APK debug Android x64 build thành công tại `mobile/build/app/outputs/flutter-apk/app-debug.apk`. PDF fixture tiếng Việt đã được render và đối chiếu text bằng `pdftotext`, nằm tại `mobile/build/test-reports/ci_report_vi.pdf` (dữ liệu giả).

Test HTTP với Postman (CLI hiện chưa đăng nhập nên không tìm/pull mock của nhà cung cấp; mock local dựa trên tài liệu Cloudinary):

```bash
postman simulation run postman/simulations/ci-report-upload.sim.yaml --port 4513 --no-history --output ndjson
```

Ở terminal khác, trong `mobile/`:

```bash
CLOUDINARY_SIMULATION_BASE=http://127.0.0.1:4513 flutter test --no-pub test/ci_report_test.dart
```

Simulation log phải có POST tới member `cloudinary` cho các case demo/rejected/limited/unavailable/invalid-json. Unit/widget test pass và build APK không chứng minh cloud name/preset thật đã được tạo hoặc PDF đã tải được trên tài khoản thật.

Nguồn: [Cloudinary unsigned upload](https://cloudinary.com/documentation/upload_images#unsigned_upload), [multipart Upload API](https://cloudinary.com/documentation/image_upload_api_reference#unsigned_upload_multipart_form_structure), [upload presets](https://cloudinary.com/documentation/upload_presets), [PDF delivery Free](https://cloudinary.com/documentation/pdf_optimization), [Dart PDF](https://github.com/DavBfr/dart_pdf).
