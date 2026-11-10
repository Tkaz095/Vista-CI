# 01. Tổng quan và phạm vi Vista CI

**v0.3 - Dự thảo chờ đánh giá - 01/11/2026**

## 1. Mục đích

Vista CI là mobile app và web cơ bản, có đăng nhập, cho phép nhóm dự án xem và quản lý thông tin CI/CD của repository GitHub. Firebase cung cấp dịch vụ tài khoản, dữ liệu dùng chung và thông báo. GitHub Actions thực hiện build, kiểm tra và các bước phát hành.

Phạm vi cốt lõi do người dùng xác nhận trong trao đổi mới nhất: **đăng nhập + quản lý CI/CD, tham khảo 4 gói SAGA**. **MVP có bấm chạy/chạy lại workflow trong Vista.** Đã chốt Email/Password, hai vai trò Admin/Member và một repository Vista-CI. FCM làm sau luồng chính, ngoài nghiệm thu MVP ban đầu. Màn hình, schema, quyền chi tiết, client được thao tác và backend vẫn là thiết kế cần đánh giá.

## 2. Hai luồng phải phân biệt

| Luồng | Ý nghĩa | Hiện trạng |
| --- | --- | --- |
| CI/CD xây dựng chính Vista | Code Vista được kiểm tra, build APK và sau này deploy web | Android cloud build đã chạy thành công; web CD chưa có |
| Chức năng CI/CD trong Vista | Người dùng đăng nhập, xem dự án/run, lịch sử và quyền thao tác | Giao diện ban đầu có; dữ liệu thật và đăng nhập chưa có |

GitHub vẫn là nguồn kết quả thực thi. Firestore chỉ lưu bản dữ liệu phục vụ giao diện, không tự chạy Gradle hoặc thay GitHub Actions.

## 3. Hai vai trò đã chốt; phân quyền chi tiết đề xuất

| Vai trò | Mobile | Web |
| --- | --- | --- |
| Member | Đăng nhập, xem dự án được cấp quyền, xem run, mở artifact/log GitHub | Có thể xem các màn hình đọc nếu được chọn hỗ trợ |
| Admin | Có các quyền đọc như Member | Quản lý metadata dự án và danh sách thành viên; xem thông tin tích hợp |
| CI Publisher | Không có màn hình | Thành phần tin cậy ghi kết quả workflow vào Firestore |

MVP đã chốt dùng một repository `Tkaz095/Vista-CI`. Tài khoản demo và vai trò được chuẩn bị qua Firebase Console; tạo/khóa tài khoản Auth từ web chưa thuộc MVP.

## 4. Phạm vi MVP và thiết kế triển khai

1. Đăng nhập Firebase Email/Password, lấy profile/quyền, đăng xuất và xử lý phiên hết hiệu lực.
2. Hai client dùng chung Firebase project `vista-ci`.
3. Mobile xem danh sách dự án được cấp quyền, tổng quan, danh sách run và chi tiết run.
4. Web có giao diện đăng nhập và quản lý metadata/thành viên của dự án trong phạm vi Admin.
5. Kết quả workflow **đã kết thúc** được một publisher tin cậy đồng bộ vào Firestore. MVP chưa yêu cầu trạng thái queued/running tức thời.
6. Mở trang run, log và artifact trên GitHub. Quyền Firebase không tự cấp quyền GitHub.
7. Build APK bằng GitHub Actions; tải APK về chạy Genymotion. Web có build kiểm tra và CD Firebase Hosting ở giai đoạn riêng.

8. **Bắt buộc, đã xác nhận:** bấm chạy workflow mới và chạy lại một run ngay trong Vista, qua backend tin cậy kiểm tra quyền và lưu dấu vết thao tác. Chạy lại ở đây là chạy lại toàn bộ run; chạy riêng job lỗi chưa được chốt.

Quyền thao tác, client hỗ trợ và backend cần duyệt trước triển khai. Xác nhận này không tự bao gồm nút deploy production riêng hoặc quyền nâng cấp billing.

## 5. Giai đoạn sau MVP

| Mở rộng | Lợi ích | Điều kiện |
| --- | --- | --- |
| Firebase Google Sign-In | Thuận tiện đăng nhập | OAuth client, SHA và cấu hình theo nền tảng |
| FCM khi build thất bại - đã chốt làm sau | Người dùng nhận cảnh báo, không chặn MVP ban đầu | Thiết bị có Google Play services, quyền thông báo và sender tin cậy |
| Nhiều repository/nhóm | Mở rộng sử dụng | Cơ chế kết nối thực và cô lập dữ liệu theo dự án |
| App Distribution hoặc Google Play | Phân phối mobile thuận tiện | Khóa ký ổn định và cấu hình phát hành |

## 6. Những phần SAGA không đưa vào Vista lúc này

Không đề xuất học kỳ, course, Jira sprint/task, chấm đóng góp, peer review, graph Neo4j, Redis hay AI trong MVP Vista. Đây là nghiệp vụ/hạ tầng của SAGA, không phát sinh từ yêu cầu đăng nhập và CI/CD hiện tại.

Không chuyển nguyên 87 bảng trong SQL tham khảo sang Firestore. Thiết kế dữ liệu mới chỉ giữ khái niệm cần dùng: người dùng, quyền, dự án/repository, run, artifact và thiết bị/thông báo nếu được duyệt.

## 7. Điều kiện để gọi bản MVP là hoàn thành

- Hai tài khoản khác quyền đăng nhập được; yêu cầu đọc/ghi trái phép bị Firestore Rules từ chối.
- Chạy mới và chạy lại từ Vista tạo được run/attempt thật trên GitHub; yêu cầu trái quyền bị backend từ chối.
- Một kết quả GitHub Actions thật hiển thị trên mobile và web với cùng run ID, commit và conclusion.
- Lịch sử, lỗi mạng, không có dữ liệu, artifact hết hạn và hết quyền đều có cách hiển thị rõ ràng.
- Có APK cài được trên thiết bị đúng kiến trúc; web có URL Hosting truy cập được.
- Có kịch bản demo và bằng chứng cho từng yêu cầu; không lấy màn hình tĩnh làm bằng chứng tích hợp.

Đây là tiêu chí đề xuất. Yêu cầu/rubric chính thức của môn học chưa có trong bộ nguồn đã đọc.
