# Sự kiện Firebase Analytics trên web admin

Trong tab Analytics, phần **Sự kiện sử dụng ứng dụng** đọc Google Analytics Data
API. Phần thống kê tài khoản/workspace cũ vẫn đọc Firestore.

## Cấu hình bên ngoài (chủ project thực hiện)

1. Trong Firebase project `vista-ci`, mở **Project settings → Integrations →
   Google Analytics**, mở property liên kết trong Google Analytics.
2. Trong Google Analytics, mở **Admin → Property details** (có thể nằm dưới
   Property settings / Property). Sao chép **Property ID dạng số**. Không dùng
   Firebase Project ID, project number, App ID hoặc Measurement ID `G-...`.
3. Trong **Admin → Property access management**, thêm email service account
   backend (`FIREBASE_CLIENT_EMAIL`, hoặc `client_email` trong JSON đang dùng
   local) với quyền **Viewer**. Không nhập email cá nhân thay service account.
   Quyền Firebase/Google Cloud IAM không tự cấp quyền đọc GA4 property.
4. Trong Google Cloud Console của project backend, bật **Google Analytics Data
   API** (`analyticsdata.googleapis.com`). Không cần bật BigQuery export Analytics
   cho tính năng này.
5. Trong `web/.env.local` (local) và Environment Variables Production trên Vercel:

   ```dotenv
   GA4_PROPERTY_ID=123456789
   # Tùy chọn: Admin → Data streams → chọn Android → Stream ID dạng số
   GA4_ANDROID_STREAM_ID=987654321
   ```

   Ví dụ trên là placeholder, không phải ID của Vista. Không thêm tiền tố VITE_.
   Nếu bỏ Stream ID, báo cáo gồm mọi stream Android trong property; giao diện ghi
   rõ phạm vi này. Nên cấu hình stream cụ thể nếu property có nhiều app Android.

6. Giữ credential backend hiện có. Code dùng `google-auth-library` xin scope
   `analytics.readonly` riêng, không dùng token mặc định Firebase Admin. Với ADC
   dạng user login, cần cấp scope Analytics khi đăng nhập ADC; service-account
   JSON hiện có phù hợp. Không tải private key mới chỉ để làm tính năng này.
7. Restart Vite hoặc tạo deployment mới để nhận env. Đăng nhập admin → Analytics.

## Báo cáo

- Một batch gồm ba report: tổng eventCount/totalUsers, top 100 eventName và số
  lượt/người dùng theo ngày. Phạm vi 7 ngày gồm hôm nay theo múi giờ GA4 property.
- Lọc platform Android, tùy chọn Stream ID. Bao gồm sự kiện tự động và nghiệp vụ.
- Tổng người dùng lấy report không có dimension; không cộng người dùng từng sự
  kiện/ngày (có trùng). Không phải số UID Firestore hoặc crash-free users.
- Cache thành công 60 giây, gộp yêu cầu đồng thời, timeout truy vấn 15 giây.
  Đây là cache trong từng process, không phải cache phân tán.
- Endpoint `/api/admin?resource=analytics-events` đi qua `authenticateAdmin`
  trước khi truy vấn. Không trả key/token hoặc raw lỗi provider cho trình duyệt.
- Thiếu env/API/quyền: hiện lỗi hướng dẫn và dấu —, không tạo số liệu demo.
  Query thành công không có dữ liệu: hiện trạng thái trống và 0.
- Báo cáo có độ trễ xử lý, không phải DebugView hay luồng realtime. Debug events
  có thể bị loại nếu GA4 developer-traffic filter đang Active. Dữ liệu bị lấy
  mẫu/ngưỡng bảo mật được gắn cảnh báo từ metadata của Google.

## Kiểm tra

```sh
cd web
npm run test:analytics
npm run lint
npm run build
```

Unit tests dùng HTTP/token giả, không truy cập hoặc sửa Firebase thật. Sau cấu
hình, tạo thao tác mobile (tạo project/xem workflow), chờ xử lý báo cáo rồi đối
chiếu eventName trong GA4 Events với web, cùng stream/khoảng ngày/múi giờ.

Tài liệu chính thức:
- https://developers.google.com/analytics/devguides/reporting/data/v1/quickstart
- https://developers.google.com/analytics/devguides/reporting/data/v1/rest/v1beta/properties/batchRunReports
- https://developers.google.com/analytics/devguides/reporting/data/v1/api-schema
