# Kết nối thống kê web admin

## Trạng thái source

Web gọi `GET /api/admin?resource=monitoring`. API hiện nằm trong `web/api/admin.ts`, được Vite dev middleware và Vercel Functions phục vụ. API kiểm tra Firebase ID token và hồ sơ `users/{uid}` có `role: admin`, `isActive: true` trước khi đọc thống kê. Không có quyền thống kê ở client.

Nhánh hiện tại không chứa cấu hình/source triển khai Firebase Functions của nhánh migration. Nếu phục vụ web qua Firebase Hosting + Functions cũ, phải tích hợp route admin vào function và deploy riêng; build static web không tự triển khai API.

- Fetch Remote Config: Cloud Monitoring, metric `firebaseremoteconfig.googleapis.com/project/fetch_request_count`, lọc app Android, cộng theo giờ UTC trong 24 giờ hoàn chỉnh gần nhất. Không có metric unique fetch users ở nguồn này, nên không hiển thị số người fetch.
- Crash: một bảng BigQuery export Crashlytics, lọc FATAL, loại trùng event ID, 7 ngày UTC gồm hôm nay; mọi phiên bản. Không trộn bảng batch và realtime.
- Tỷ lệ không crash: dùng thêm bảng Firebase Sessions, đếm bản cài đặt/phiên duy nhất theo kỳ. Không cộng tỷ lệ ngày để suy ra tỷ lệ cả kỳ. Thiếu mẫu số hoặc mẫu số nhỏ hơn tử số sẽ trả null. Số liệu export có độ trễ và không nhất thiết trùng Firebase Console đang lọc theo phiên bản.
- Không đủ quyền/chưa bật export: báo rõ từng nguồn, không tự đưa dữ liệu mẫu hay 100%.
- Cache trong bộ nhớ backend 60 giây, gộp yêu cầu đồng thời. Mỗi truy vấn BigQuery giới hạn tối đa 100 MiB; không có polling tự động. Cache không được chia sẻ giữa các server instance.

## 1. Bật nguồn Cloud Monitoring

Trong Google Cloud, chọn project `vista-ci`:

1. APIs & Services → Library → bật **Cloud Monitoring API** (`monitoring.googleapis.com`).
2. IAM & Admin → IAM → tìm service account backend đang dùng, thêm **Monitoring Viewer** (`roles/monitoring.viewer`).
3. Service account là email trong `FIREBASE_CLIENT_EMAIL`, hoặc `client_email` của file ADC. Không phải tài khoản admin dùng để đăng nhập web. Không cần generate key mới.

`MONITORING_FIREBASE_APP_ID` mặc định trỏ app Vista CI Android. Có thể ghi đè bằng env server nếu app thay đổi.

## 2. Bật export Crashlytics + Sessions

Firebase → Project settings → Integrations → BigQuery → Link/Manage:

1. Bật export **Crashlytics**, chọn app Vista CI Android.
2. Bật xuất **Firebase Sessions** cùng Crashlytics để có mẫu số cho tỷ lệ không crash.
3. Chọn region/location theo nhu cầu dự án. Giữ hai dataset cùng location.
4. Mặc định dùng batch export cho phạm vi nhỏ. Streaming export là tùy chọn; code hỗ trợ chọn một bảng realtime nếu muốn, không tự bật streaming.
5. Chờ dữ liệu export xuất hiện. Dữ liệu chưa xuất không thể đọc trực tiếp từ biểu đồ Firebase Console; không đảm bảo đầy đủ lịch sử trước khi bật export.
6. Trong BigQuery → Explorer → project `vista-ci`, sao chép **Table ID đầy đủ** của bảng Crashlytics và Sessions. Trong Dataset → Details sao chép **Data location**.

Tên ví dụ theo Android package hiện tại (phải kiểm tra bảng thực tế trước khi điền):

```dotenv
CRASHLYTICS_BIGQUERY_TABLE=vista-ci.firebase_crashlytics.com_vista_vista_mobile_ANDROID
SESSIONS_BIGQUERY_TABLE=vista-ci.firebase_sessions.com_vista_vista_mobile_ANDROID
BIGQUERY_LOCATION=US
```

`US` chỉ là ví dụ. Nếu dataset là `asia-southeast1`, dùng đúng `asia-southeast1`. Không đổi location của dataset chỉ để khớp ví dụ.

## 3. Quyền BigQuery cho backend

- Bật BigQuery API (`bigquery.googleapis.com`).
- Cấp **BigQuery Job User** (`roles/bigquery.jobUser`) cho service account backend trên project chạy truy vấn `vista-ci`.
- Trên từng dataset export `firebase_crashlytics` và `firebase_sessions`, Share → Permissions → cấp **BigQuery Data Viewer** (`roles/bigquery.dataViewer`) cho cùng service account.
- Không cần Owner/Editor, không cấp các quyền này cho browser hoặc user thông thường.

BigQuery có phí lưu trữ/truy vấn ngoài hạn mức miễn phí; giới hạn request Cloud Functions không bao gồm toàn bộ phí BigQuery. Backend đã đặt giới hạn bytes cho từng truy vấn.

## 4. Điền env server và chạy

Local: bổ sung các biến ở `web/.env.local` (không ghi đè file đang có, không commit). Production Vercel: Environment Variables của đúng môi trường rồi redeploy.

```dotenv
MONITORING_FIREBASE_APP_ID=1:1087429884658:android:cdfbf3a5d8a08c0d1a6e6b
CRASHLYTICS_BIGQUERY_TABLE=<Table ID Crashlytics>
SESSIONS_BIGQUERY_TABLE=<Table ID Sessions>
BIGQUERY_LOCATION=<Location của dataset>
```

Giữ credential Admin SDK đang chạy được. Không thêm prefix `VITE_`, không đưa private key vào source/client.

Restart Vite sau khi điền env:

```sh
cd /home/kien/FPTU/Semester-8/PRM393/Lab3-Assignment/Vista-CI/web
npm run dev
```

Đăng nhập admin → Giám sát ứng dụng → Làm mới. Do cache 60 giây và độ trễ export, thay đổi trên Console có thể chưa xuất hiện ngay. Lần đọc nguồn được hiển thị dưới biểu đồ; đây là thời điểm backend đọc, không phải watermark bảo đảm export đầy đủ.

## Nguồn chính thức

- [Cloud Monitoring Remote Config metrics](https://docs.cloud.google.com/monitoring/api/metrics_gcp_d_h#firebaseremoteconfig)
- [Monitoring access control](https://docs.cloud.google.com/monitoring/access-control)
- [Crashlytics BigQuery export](https://firebase.google.com/docs/crashlytics/bigquery-export)
- [Export schema](https://firebase.google.com/docs/crashlytics/bigquery-dataset-schema)
- [Crash-free query concepts](https://firebase.google.com/docs/crashlytics/bigquery-run-queries)
- [BigQuery IAM](https://docs.cloud.google.com/bigquery/docs/access-control)

## Kiểm chứng

TypeScript/Vite build đã chạy thành công sau khi thêm kết nối. Chưa chạy truy vấn thật, chưa xác nhận quyền IAM hay dữ liệu export, chưa deploy. Không có test mới được thêm/chạy trong thay đổi này.
