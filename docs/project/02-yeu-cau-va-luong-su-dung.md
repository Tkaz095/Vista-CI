# 02. Yêu cầu và luồng sử dụng

**v0.3 - Đề xuất, chưa triển khai - 01/11/2026**

Nguồn yêu cầu: ý định mới nhất của người dùng, quy trình đăng nhập/phân quyền của SAGA và thiết kế CI/CD mới cho Vista. Email/Password, hai vai trò Admin/Member, một repository và chạy/chạy lại đã được duyệt về phạm vi. FCM đã chốt làm sau luồng chính. Các yêu cầu bên dưới không phải danh sách tính năng đã có; chi tiết kỹ thuật và quyền vẫn cần đánh giá.

## 1. Danh mục yêu cầu

| ID | Yêu cầu | Mức đề xuất | Tiêu chí chấp nhận chính |
| --- | --- | --- | --- |
| AUTH-01 | Đăng nhập Email/Password trên mobile và web | MVP, phương thức đã chốt | Tài khoản hợp lệ vào màn hình phù hợp; sai mật khẩu không vào dữ liệu |
| AUTH-02 | Đọc profile và quyền truy cập | MVP | Thiếu profile, inactive hoặc không có quyền thì chặn; không mặc định Admin |
| AUTH-03 | Khôi phục phiên và đăng xuất | MVP | Chờ kiểm tra phiên trước khi render dữ liệu; logout xóa state và hủy subscriptions |
| AUTH-04 | Gửi yêu cầu đặt lại mật khẩu | Sau luồng chính | Không tiết lộ tài khoản có tồn tại; xử lý lỗi/rate limit |
| PRJ-01 | Xem dự án được cấp quyền | MVP | Member chỉ truy vấn dự án chứa UID của mình; Admin có danh sách quản lý |
| PRJ-02 | Admin quản lý tên, mô tả, thành viên và archive dự án | MVP | Kiểm tra quyền tại Firestore, không chỉ ẩn nút trên UI |
| RUN-01 | Tổng quan run gần nhất | MVP | Hiển thị repository, branch, commit, conclusion và thời điểm nguồn; không có dữ liệu thì hiển thị trống |
| RUN-02 | Danh sách run và lọc | MVP | Trang đầu tối đa 20, có phân trang; xác định rõ bộ lọc branch/conclusion |
| RUN-03 | Chi tiết run và đường dẫn GitHub/artifact | MVP | Hiển thị run ID, attempt, commit và kết quả; xử lý link cần quyền hoặc hết hạn |
| SYNC-01 | Đưa kết quả run thật vào Firestore | MVP | Publisher ghi một document/attempt; chạy lại xử lý cùng event không tạo bản sao |
| INF-01 | CI Android và APK Genymotion | Đã có hạ tầng, cần kiểm tra thiết bị | Analyze + build + artifact; cài/chạy app là kiểm tra riêng |
| INF-02 | CI web và deploy Firebase Hosting | MVP mục tiêu | Build/lint đạt trước deploy; chỉ nhánh/môi trường được duyệt được deploy live |
| NTF-01 | Nhận thông báo FCM về run | Đã chốt giai đoạn sau MVP | Không có token/quyền thì app vẫn dùng được; không coi FCM accepted là đã nhận |
| ACT-01 | Chạy/chạy lại workflow trong Vista | MVP bắt buộc, đã xác nhận | Backend kiểm tra Firebase identity, vai trò, project và GitHub permission; không lộ token cho client |

## 2. Danh sách màn hình đề xuất

| Màn hình | Mobile | Web | Trạng thái bắt buộc |
| --- | --- | --- | --- |
| Đăng nhập | Có | Có | Chưa nhập, đang gửi, lỗi, bị chặn |
| Danh sách dự án | Có | Có | Loading, empty, data, error, permission denied |
| Tổng quan dự án | Có | Có | Chưa kết nối nguồn, chưa có run, đã có run, dữ liệu cũ |
| Danh sách/chi tiết run | Có | Có | Phân trang, không tìm thấy, mất quyền, artifact hết hạn |
| Điều khiển workflow | Client hỗ trợ cần chốt | Client hỗ trợ cần chốt | Đang gửi, đã nhận, bị từ chối, lỗi, chưa rõ kết quả; liên kết run khi xác định được |
| Quản lý dự án | Không bắt buộc | Admin | Validation, đang lưu, lưu thành công, bị từ chối |
| Tài khoản/thông báo | Tối thiểu logout; FCM ở giai đoạn sau | Tối thiểu logout | Phiên thay đổi, quyền thông báo bị từ chối |

Giao diện overview hiện có chỉ là khung. Không coi đó là đã đáp ứng RUN-01 hoặc SYNC-01.

## 3. UC-01 - Đăng nhập và xác định quyền

**Actor:** Admin hoặc Member. **Điều kiện:** tài khoản Auth tồn tại và profile đã được cấp quyền.

1. Người dùng nhập Email/Password.
2. Firebase Authentication xác thực; client chưa mở dữ liệu dự án ngay.
3. Repository lấy `users/{uid}` và kiểm tra `isActive`/`role`.
4. ViewModel/hook chuyển sang trạng thái đã xác thực và điều hướng theo quyền.
5. Query dự án bằng đúng phạm vi của người dùng.

Nhánh lỗi: sai thông tin -> thông báo đăng nhập chung; mất mạng -> cho thử lại; thiếu profile -> thông báo chưa được cấp quyền; Firestore denied -> xóa state dữ liệu và hiện lỗi quyền. Không tự tạo profile Admin để “sửa lỗi”.

Kết thúc: có phiên hợp lệ và UI đúng quyền. Firebase Auth và đăng nhập GitHub là hai danh tính khác nhau.

## 4. UC-02 - Xem kết quả build

1. Member chọn một dự án có quyền xem.
2. App lấy/lắng nghe tối đa 20 run gần nhất.
3. Người dùng mở chi tiết để xem branch, commit, conclusion và liên kết nguồn.
4. Khi publisher thêm kết quả run mới, Firestore cập nhật UI đang kết nối.
5. Người dùng mở GitHub để xem log hoặc tải artifact.

MVP chỉ phản ánh các run đã kết thúc. Không có event mới không đồng nghĩa pipeline đang chạy tốt. Hiển thị thời điểm đồng bộ; nếu dữ liệu cũ phải ghi rõ.

Nếu người dùng không có quyền repository GitHub, Vista không tự mở khóa log/artifact. Nếu artifact bị xóa hoặc hết hạn, vẫn giữ được metadata run và chỉ dẫn chạy build mới trên GitHub.

## 5. UC-03 - Quản lý metadata và thành viên

1. Admin mở quản lý dự án trên web.
2. Sửa `displayName`, `description`, `memberUids` hoặc `archived` trong danh sách trường được phép.
3. Client gửi thay đổi; Firestore Rules xác thực quyền và các trường được sửa.
4. Chỉ báo thành công sau khi server chấp nhận.
5. Member mới xuất hiện dự án ở danh sách; member bị gỡ không được đọc dữ liệu mới.

MVP dùng một repository đã chốt; đề xuất seed một project đã nối nguồn qua quy trình kỹ thuật. Sửa tên repository hoặc bấm lưu metadata không được hiển thị “đã kết nối GitHub”. Kết nối repository mới và tạo/quản lý Firebase Auth users từ web là phạm vi riêng.

## 6. UC-04 - Xuất bản kết quả pipeline

Actor hệ thống là publisher tin cậy, không phải người dùng mobile.

1. Workflow build đã kết thúc phát sinh event.
2. Publisher kiểm tra repository, loại event và nhánh nằm trong allowlist.
3. Lấy metadata run/conclusion/artifact từ GitHub, chuẩn hóa thành schema Vista.
4. Upsert document khóa `{runId}_{attempt}` trong project tương ứng.
5. Nếu ghi thất bại, báo lỗi đồng bộ riêng. Build nguồn thành công không được đổi thành thất bại chỉ vì Vista chưa nhận dữ liệu.

Run thất bại/cancelled vẫn cần được biểu diễn. Thiết kế chỉ ghi dữ liệu ở bước build thành công là không đáp ứng SYNC-01.

## 7. UC-05 - Chạy và chạy lại workflow (MVP bắt buộc)

Vai trò được thao tác và mobile/web hỗ trợ nút nào vẫn cần chốt, không mặc định mọi Member có quyền chạy.

1. Người dùng có phiên hợp lệ chọn project và thao tác chạy mới hoặc chạy lại một run.
2. Chạy mới chọn workflow/ref/inputs thuộc allowlist. Chạy lại chọn run nguồn đúng repository; backend kiểm tra điều kiện chạy lại trên GitHub.
3. Client gửi Firebase ID token và request ID đến backend tin cậy; không giữ GitHub credential.
4. Backend kiểm tra người dùng active, quyền thao tác, quyền project và nguồn được phép; từ chối yêu cầu không hợp lệ.
5. Backend ghi dấu vết yêu cầu và gọi GitHub API. UI phân biệt “đã nhận yêu cầu” với “workflow hoàn tất”; chỉ hiển thị run ID khi xác định được.
6. Publisher đồng bộ kết quả run/attempt thật để người dùng đối chiếu. Chạy lại toàn bộ run là phạm vi được đề xuất cho ACT-01.

Chống bấm lặp bằng request ID và trạng thái backend. Nếu mất kết nối sau khi gửi GitHub, cần đối soát trước khi gửi lại; không hứa thực thi đúng một lần hoặc tự tạo run ID. Nút chạy workflow có thể kích hoạt các bước deploy vốn có trong workflow; danh sách workflow/ref được cho phép phải được duyệt.

## 8. Quy tắc chung

- Không coi số commit, số build hoặc build xanh là điểm chất lượng/đóng góp con người; đây là bài học từ review SAGA.
- Tách lỗi xác thực, lỗi quyền, lỗi nguồn GitHub và lỗi đồng bộ.
- Không hiển thị số 0 như kết quả đo thật khi chưa có dữ liệu.
- UI không giữ dữ liệu người dùng trước sau logout hoặc chuyển tài khoản.
- Member không được ghi `role`, `memberUids`, `conclusion` hoặc dữ liệu tích hợp đáng tin cậy.
- Nút điều khiển workflow bắt buộc phải có trạng thái đang gửi, request ID và kết quả thực thi; bấm nút không đồng nghĩa workflow đã chạy xong.
