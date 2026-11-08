# Tự động gửi thông báo CI

Toàn bộ code nằm trong `mobile/functions/`, độc lập với `web/`. Flutter tiếp tục
dùng ViewModel/service hiện có để nhận FCM, đọc lịch sử và mở đúng run/attempt.
Phần gửi chạy trên Firebase Cloud Functions, kể cả khi app đã đóng.

```text
GitHub workflow_run (in_progress / completed)
  → githubCiWebhook: xác minh chữ ký SHA-256
  → repo và người nhận đã được quản trị viên cho phép
  → kiểm tra profile, repo trong project và ciSubscriptions
  → lưu users/{uid}/notifications/{notificationId}
  → gửi FCM tới users/{uid}/devices/* → điện thoại
```

| Tùy chọn | Sự kiện gửi |
| --- | --- |
| `failures` (mặc định khi chưa có document) | Kết thúc với `failure` hoặc `timed_out` |
| `results` | Tất cả sự kiện kết thúc |
| `all` | Bắt đầu và kết thúc |
| `off` hoặc giá trị không hợp lệ | Không gửi |

## 1. Chuẩn bị Firebase

Dùng project chính **vista-ci**, cùng project với Authentication/Firestore/FCM.
Cloud Functions cần gói **Blaze** và các API mà Firebase CLI yêu cầu khi deploy.
Không đổi project AI `vista-ai-28543` hoặc đưa private key vào Flutter.

Function dùng Application Default Credentials của runtime, không cần file
service-account JSON trong app. Runtime service account cần quyền Firestore
(`roles/datastore.user`), đọc trạng thái tài khoản Auth (`roles/firebaseauth.viewer`)
và gửi FCM (`roles/firebasecloudmessaging.admin`).
Firebase CLI sẽ yêu cầu quyền cho các API/secret cần thiết khi deploy;
nếu tổ chức chặn việc cấp IAM, quản trị viên cần cấp cho đúng runtime account.

Giữ bộ Firestore Rules đã Publish cho `projects`, `ciSubscriptions`,
`notifications`, `devices` và `ciAnalyses`. Hai collection mới bên dưới chỉ dùng
Admin SDK. Với bộ Rules hiện tại, chúng bị chặn mặc định vì không có `allow` khớp.
Không cấp quyền client cho `ciNotificationRepositories`/`ciNotificationDeliveries`.

## 2. Cho phép một repository và người nhận

Trên Firestore Console tạo document:

```text
ciNotificationRepositories/{GitHub repository ID}
```

Ví dụ cấu trúc (thay bằng repo/UID thật):

```json
{
  "enabled": true,
  "fullName": "github-owner/Vista-CI",
  "allowedUserUids": ["FIREBASE_AUTH_UID"],
  "workflowNames": ["Android APK"]
}
```

- Document ID là GitHub repository ID dạng số, không phải tên repo.
- `allowedUserUids` là array các Firebase Auth UID được phép nhận, tối đa 50.
  Chỉ thêm người đã được xác minh có quyền xem repository, đặc biệt repo private.
- `workflowNames` là array tên workflow chính xác. Bỏ field này hoặc để `[]`
  nếu muốn theo dõi tất cả workflow của repo.
- Tài khoản Firebase Auth phải còn tồn tại và không bị disable. Người nhận còn
  phải có profile `role: "user"`, `isActive: true`, repo nằm
  trong ít nhất một `users/{uid}/projects`, và đã bật/đăng ký FCM trên điện thoại.
- Tùy chọn repo áp dụng chung cho mọi project của cùng người dùng.
- Khi thu hồi quyền GitHub, quản trị viên phải xóa UID khỏi danh sách này.
  Function không tự đồng bộ quyền GitHub; không tin riêng danh sách project do
  client ghi để cấp quyền nhận thông tin của repo private.

## 3. Cấu hình secret và deploy

Chạy từ **mobile/**; cần Node.js 22 và Firebase CLI:

```bash
npm ci --prefix functions
npm run build --prefix functions
firebase functions:secrets:set GITHUB_WEBHOOK_SECRET --project vista-ci
firebase deploy --only functions:ci-notifications --project vista-ci
```

Tạo secret ngẫu nhiên tối thiểu 32 ký tự, nhập vào lệnh `secrets:set`, rồi dùng
cùng giá trị khi tạo GitHub webhook. Ví dụ tạo riêng trên máy: `openssl rand -hex 32`.
Không commit hoặc gửi secret qua chat. Function chỉ đọc secret khi nhận request.

Lưu URL `githubCiWebhook` do CLI in ra sau deploy. Function ở `asia-southeast1`,
không giữ instance chạy thường trực, giới hạn 2 instance để giảm chi phí ngoài ý muốn.
Blaze tính theo mức sử dụng; các giới hạn này không phải giới hạn ngân sách cứng.

## 4. Cấu hình GitHub webhook

Repository → **Settings → Webhooks → Add webhook**:

- Payload URL: URL `githubCiWebhook` vừa deploy.
- Content type: **application/json**.
- Secret: đúng `GITHUB_WEBHOOK_SECRET` đã lưu trên Firebase.
- SSL verification: bật.
- **Let me select individual events → Workflow runs**; không cần chọn Push.
- Active: bật.

Ping ban đầu phải trả HTTP 200. Request thiếu/sai chữ ký trả 401;
event/action không dùng được xác minh rồi trả 200 với `ignored`.

Push code, mở PR hoặc rerun một workflow thật. Trong **Recent Deliveries**,
kiểm tra `workflow_run` và response `notificationsCreated`, `pushesSent`,
`pushesFailed`. Mở điện thoại để kiểm tra thông báo và đường dẫn đến run/attempt.
Nếu app đã đóng và mất GitHub token trong RAM, kết nối lại GitHub khi app yêu cầu.

## 5. Gửi trùng và lỗi gửi

- Inbox dùng ID ổn định `run_{repoId}_{runId}_{attempt}_{phase}`; webhook được
  redeliver không ghi đè trạng thái đã đọc. Nhiều project chứa cùng repo không
  làm phát sinh nhiều inbox item cho một user.
- `ciNotificationDeliveries` giữ claim riêng cho từng thiết bị. Gửi đồng thời/
  redelivery không gửi lại claim đã tồn tại. Attempt mới có ID riêng.
- Start tới sau khi đã lưu completed sẽ bị bỏ qua. Cùng run/attempt dùng chung
  Android tag để bản kết quả có thể thay thông báo bắt đầu.
- FID bị FCM trả `UNREGISTERED` bị xóa khỏi devices; không xóa một FID mới vừa
  thay thế trong lúc gửi. Người dùng có thể đăng xuất/đăng nhập lại để đăng ký lại.
- Timeout/lỗi chưa rõ kết quả được lưu `state: "uncertain"`, không tự gửi lại để
  tránh thông báo hai lần. Inbox vẫn có thể đọc ngay cả khi push thất bại.
- Claim còn `sending` có thể là function bị dừng giữa chừng. Không có bảo đảm
  exactly-once giữa Firestore và FCM: inbox bền vững, push là best effort.
- GitHub không tự động redeliver mọi lần thất bại. Dùng **Redeliver** trong
  Recent Deliveries sau khi sửa lỗi Firestore/cấu hình. Claim đã gửi hoặc chưa rõ
  kết quả vẫn được giữ để tránh phát lại; cần kiểm tra trước khi xóa claim thủ công.

## 6. Kiểm thử local

Firestore Emulator cần Java 21 trở lên. Từ `mobile/`:

```bash
firebase emulators:exec --only firestore --project demo-vista-ci-notifications "npm --prefix functions test"
```

Tests dùng Firestore Emulator thật và FCM giả, không gửi push hay ghi dữ liệu
production. Kiểm tra chữ ký theo test vector chính thức của GitHub, endpoint HTTP,
tùy chọn người nhận, ghi inbox trước push, chạy đồng thời, attempt, late-start,
lỗi FCM và bảo toàn đăng ký mới. Chạy Firebase CLI với demo project khi test.

Muốn thử cả Functions Emulator, tạo `functions/.secret.local` (đã gitignore)
chứa `GITHUB_WEBHOOK_SECRET=<secret-local-tối-thiểu-32-ký-tự>`, rồi chạy:

```bash
firebase emulators:start --only functions,firestore --project demo-vista-ci-notifications
```

Endpoint local:
`http://127.0.0.1:5001/demo-vista-ci-notifications/asia-southeast1/githubCiWebhook`.
Chỉ gửi payload đã ký bằng secret local; không trỏ GitHub production vào localhost.

Tham khảo: [GitHub signatures](https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries),
[workflow_run](https://docs.github.com/en/webhooks/webhook-events-and-payloads#workflow_run),
[Firebase HTTPS functions](https://firebase.google.com/docs/functions/http-events),
[FCM](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk).
