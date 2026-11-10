# 04. Dữ liệu và phân quyền

**v0.3 - Mô hình Firestore đề xuất, chưa tạo collections/rules/indexes - 01/11/2026**

## 1. Nguyên tắc

Firebase Auth giữ danh tính và mật khẩu; Firestore giữ profile/quyền và dữ liệu ứng dụng. GitHub giữ thông tin chạy pipeline gốc. Client không được tự ghi kết quả build. Admin SDK/server libraries bỏ qua Firestore Rules, vì vậy publisher còn phải được bảo vệ bằng IAM và giới hạn event/nguồn tin cậy. [Firestore Rules](https://firebase.google.com/docs/firestore/security/get-started).

## 2. Collection đề xuất

```text
users/{uid}
  devices/{installationId}              # giai đoạn FCM sau MVP
  notifications/{eventId}               # khi duyệt notification center
projects/{projectId}
  runs/{runId_attempt}
  commands/{requestId}                 # audit điều khiển, backend ghi
```

MVP đã chốt một repository và hai vai trò Admin/Member; schema và quyền chi tiết bên dưới vẫn là đề xuất. Với một nhóm nhỏ: danh sách UID thành viên nằm ở project (`memberUids`). Nếu sau này nhiều nhóm hoặc hàng trăm thành viên, cần đánh giá lại model membership; chưa thêm tổ chức/tenant phức tạp vào MVP.

### users/{uid}

| Trường | Kiểu | Ghi bởi | Ý nghĩa |
| --- | --- | --- | --- |
| displayName | string | Chính chủ, theo allowlist | Tên hiển thị |
| role | `admin` hoặc `member` | Firebase Console/quy trình quản trị tin cậy | Quyền ứng dụng |
| isActive | boolean | Quy trình quản trị tin cậy | Cho phép dùng dữ liệu Vista |
| createdAt, updatedAt | timestamp | Theo quy trình tạo/cập nhật | Thời gian chuẩn server |

Document ID phải bằng Firebase Auth UID. Không lưu mật khẩu, refresh token hoặc GitHub PAT. MVP tạo tài khoản và cấp role qua Console; client không được tự tạo profile Admin. Thiếu profile thì chặn có hướng dẫn, không cấp role mặc định.

### projects/{projectId}

| Trường | Kiểu/ý nghĩa |
| --- | --- |
| displayName, description | Metadata có giới hạn độ dài, do Admin sửa |
| memberUids | Mảng UID đã được cấp quyền, Admin quản lý |
| archived | boolean, ẩn khỏi danh sách hoạt động của Member |
| provider | `github` |
| sourceRepoId | string, GitHub repository ID đã xác minh |
| repoFullName | Ví dụ `Tkaz095/Vista-CI`; không thay repo ID làm định danh chuẩn |
| integrationState | `pending`, `connected`, `error`; nguồn tin cậy cập nhật |
| lastSyncedAt | timestamp/null, không lấy thời điểm render UI thay vào |
| createdAt, updatedAt | timestamp |

Đề xuất seed project `vista-ci` và repo đã biết trước khi làm UI nhiều repository. Sửa displayName hoặc repo text không tự tạo kết nối GitHub. `sourceRepoId`, `provider`, `integrationState` không nằm trong allowlist cập nhật thông thường của Admin web.

### projects/{projectId}/runs/{runId_attempt}

| Trường | Kiểu/ý nghĩa |
| --- | --- |
| runId | string từ GitHub |
| attempt | integer >= 1 |
| workflowId, workflowName | ID/name nguồn |
| branch, commitSha, event | Branch, SHA, loại event nguồn |
| status | `queued`, `in_progress`, `completed`, `unknown`; MVP publisher ghi `completed` |
| conclusion | null hoặc `success`, `failure`, `cancelled`, `timed_out`, `skipped`, `neutral`, `action_required`, `stale`, `startup_failure`, `unknown` |
| createdAt | timestamp từ GitHub, dùng làm thứ tự lịch sử ổn định |
| startedAt, completedAt | timestamp/null, lấy từ GitHub khi có |
| syncedAt | timestamp server khi Vista nhận dữ liệu |
| htmlUrl | HTTPS GitHub run URL |
| artifacts | Mảng nhỏ metadata: id, name, URL GitHub, expiresAt, sizeBytes |

Ví dụ khóa: `41219589321_1`. Cùng run/cùng attempt ghi lại vào cùng document; attempt mới có document mới. Không lưu file APK hay toàn bộ log trong Firestore. APK ở GitHub Artifacts; URL có thể cần đăng nhập GitHub và có thể hết hạn sớm nếu artifact bị xóa.

Enum lạ phải ánh xạ `unknown` và giữ UI hoạt động. Không suy diễn failure từ “đã lâu chưa có run”; không biến cancellation thành success. Giới hạn số run trong dashboard phải được thể hiện trên label, ví dụ “20 lần chạy gần nhất”, thay vì ngụ ý toàn bộ lịch sử.

### projects/{projectId}/commands/{requestId} - đề xuất cho ACT-01 bắt buộc

Backend tạo/cập nhật: `actorUid`, `action` (`dispatch`/`rerun`), workflow/ref/inputs đã kiểm tra, `sourceRunId` nếu rerun, `runId`/`attempt` khi xác định được, timestamps và trạng thái yêu cầu (`received`, `accepted`, `rejected`, `failed`, `unknown`). Không lưu token hoặc inputs chứa bí mật trong audit.

`accepted` chỉ nói GitHub đã nhận lệnh, không phải build thành công. Client gửi lệnh qua endpoint backend; không tự ghi command hoặc trạng thái chấp nhận vào Firestore. Backend đối soát request ID trùng và trường hợp chưa rõ GitHub đã nhận hay chưa, tránh tự gửi lại tạo run ngoài ý muốn. Quyền đọc audit theo project/người thao tác cần chốt cùng role; trạng thái thực thi chuẩn vẫn nằm ở run.

### Thiết bị/thông báo - giai đoạn FCM sau MVP đã chốt

Device: `token`, `platform`, `active`, `updatedAt`, `appVersion`; chỉ chủ sở hữu đăng ký/rotate/revoke. Không cho người dùng khác liệt kê tokens.

Notification: `eventId`, `projectId`, `runKey`, `title`, `body`, `createdAt`, `readAt`; sender tin cậy tạo, chính chủ chỉ được cập nhật `readAt`. Khi logout phải vô hiệu binding token với tài khoản; cùng thiết bị đổi tài khoản không được tiếp tục nhận payload riêng của người trước.

Một notification document có event ID ổn định giúp chống trùng dữ liệu. Không cam kết push exactly-once: FCM send và ghi trạng thái gửi không nằm trong cùng transaction; client cần chống hiển thị trùng theo event ID nếu thêm tự động gửi.

## 3. Ma trận quyền dự kiến

| Dữ liệu/thao tác | Chưa đăng nhập | Member đang active | Admin đang active | Publisher tin cậy |
| --- | --- | --- | --- | --- |
| Đọc profile chính mình | Không | Có | Có | Theo IAM cần thiết |
| Liệt kê profiles để chọn thành viên | Không | Không | Có | Không cần mặc định |
| Sửa displayName chính mình | Không | Có, trường cho phép | Có, trường cho phép | Không cần mặc định |
| Sửa role/isActive | Không | Không | Không qua client trong MVP | Chỉ quy trình quản trị riêng |
| Đọc project/run | Không | Chỉ project chưa archive có UID của mình | Có | Theo nhiệm vụ |
| Sửa project metadata/memberUids | Không | Không | Có, trường cho phép | Không cần mặc định |
| Ghi run/conclusion | Không | Không | Không qua client | Có |
| Đọc/ghi device token | Không | Chính chủ | Chính chủ, không mặc định đọc token người khác | Sender khi cần FCM |

Quyền chạy/chạy lại cần chốt riêng theo vai trò và project. Backend xác thực mỗi lệnh, chỉ backend ghi audit; quyền xem run không tự đồng nghĩa quyền chạy workflow.

Bảng này là hợp đồng thiết kế, không phải rules đã deploy. Quyền Admin của Vista không đồng nghĩa quyền Owner Firebase hoặc quyền admin GitHub.

## 4. Query và index

- Member list: `memberUids array-contains uid`, `archived == false`, sắp `updatedAt` giảm dần, limit 20.
- Admin list: danh sách project, phân trang.
- Runs mặc định: `createdAt` nguồn giảm dần, limit 20, dùng document ID làm tie-break khi trùng thời gian; không lấy `syncedAt` làm thời điểm run để đẩy lịch sử cũ lên đầu khi publish lại.
- Khi lọc branch/conclusion, query phải mang điều kiện đó và có composite index tương ứng.

Rules không tự lọc kết quả giúp client. Query có khả năng trả dữ liệu trái quyền sẽ bị từ chối. Phải kiểm tra query thực với Rules và index, không chỉ test document đơn lẻ. [Secure queries](https://firebase.google.com/docs/firestore/security/rules-query).

MVP đọc online là chính. Nếu dùng cache phải hiển thị dữ liệu cũ/đang chờ; không báo lưu thành công khi server chưa chấp nhận. Logout hủy subscriptions và xóa ViewModel/hook state; quyền thay đổi không được để UI tiếp tục thao tác bằng state cũ.

## 5. Đồng bộ, lỗi và nguồn chuẩn

Publisher upsert theo ID ổn định, kiểm tra project/repo mapping trước khi ghi. Lỗi publish có thể retry độc lập với build, cùng event không tạo thêm run. Nếu event không có đủ thời gian/conclusion, ghi `unknown`/null theo contract hoặc cách ly lỗi, không chế tạo dữ liệu.

Một lần chạy thành công trên GitHub nhưng chưa đồng bộ phải hiển thị là “Vista chưa cập nhật” khi có bằng chứng thích hợp; không tự sửa kết quả nguồn. Việc đối soát/publish lại lịch sử là công cụ bảo trì sau khi làm xong luồng một event.

Đối chiếu dữ liệu SAGA và phần thiết kế mới xem tài liệu 08; SQL tham khảo không được chạy vào Firebase.
