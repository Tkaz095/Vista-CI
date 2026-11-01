# Bước 15 — Một vai trò user và lỗi đọc hồ sơ

Ngày 02/11/2026. Theo quyết định mới nhất: mọi tài khoản là `user`; Admin được thiết kế ở giai đoạn sau. Các mô tả Admin/Member hoặc role member mặc định ở tài liệu trước là lịch sử, không còn là quy ước hiện hành.

## Code và Rules đã chỉnh

- Web/Android tạo hồ sơ mới với đúng ba trường: displayName, role `user`, isActive true.
- Transaction phát hiện hồ sơ đã tồn tại có isActive true và role khác user sẽ chỉ cập nhật role về user. Không thay tên hoặc isActive, không ghi đè toàn document.
- Hồ sơ inactive tiếp tục bị chặn. Không tự kích hoạt lại hoặc tạo hồ sơ thay thế cho document đang tồn tại.
- Rules self-create chỉ cho role user. Self-update chỉ cho thay role về user trên hồ sơ đang active; mọi trường khác phải giữ nguyên. Quyền Admin không được sử dụng trong cổng đăng nhập hiện tại.
- Get hồ sơ riêng chỉ dựa trên request.auth.uid trùng document ID. Không yêu cầu document đã tồn tại, không yêu cầu role hoặc isActive cho bước get. List toàn collection users bị từ chối.
- Workspace/repositories vẫn dùng memberUids. memberUids là danh sách thành viên workspace, không phải vai trò member cũ. Có role user không đồng nghĩa có quyền đọc workspace của người khác.

## Chẩn đoán lỗi đang báo

`Không có quyền đọc hồ sơ Vista...` là nhánh onSnapshot lỗi permission-denied, xảy ra trước bước kiểm tra role hoặc tự tạo hồ sơ. Vì vậy chỉnh field role đơn thuần không giải quyết được nhánh này.

Đã đối chiếu local: web và Android đều trỏ Firebase project `vista-ci`; web dùng database mặc định `(default)`. Chưa đọc được Rules đang publish trên Console; chưa thể kết luận nguyên nhân chính xác. Người dùng được yêu cầu gửi toàn bộ Rules hiện tại để đối chiếu.

Thông báo code mới ghi rõ project/database và bước đọc thay cho yêu cầu người dùng kiểm tra UID để đăng nhập.

## Người dùng thao tác Firebase và chạy lại

1. Mở đúng **project vista-ci → Firestore Database → database (default) → Rules**.
2. Nếu chưa có quy tắc khác do nhóm bổ sung, thay toàn bộ Rules bằng file `firebase/firestore.rules` hiện tại trong repo để tránh ghép thiếu hàm hoặc lồng sai match path. Nếu đã có rule khác, đối chiếu và giữ phần cần thiết trước khi publish.
3. Publish. Không sửa role thủ công từng user, không xóa Auth user hoặc hồ sơ để thử.
4. Web: tải lại trang bản code mới, đăng xuất rồi đăng nhập GitHub lại. Nếu là web đã deploy, thay đổi local không tự cập nhật bản deploy.
5. Android: dừng phiên cũ rồi `flutter run` để dùng bản mới. APK cũ không tự nhận code mới.
6. Nếu vẫn lỗi đọc: gửi nội dung Rules đang publish và thông báo mới, cho biết đang chạy local/deploy/mobile. Kiểm tra Console có đúng project/database và App Check enforcement nếu đúng Rules mà vẫn bị từ chối. Không tắt App Check hoặc mở toàn bộ database để chữa lỗi khi chưa xác định nguyên nhân.

## Phần chưa hoàn thành

Chưa xác nhận đăng nhập/auto-create/migration trên Firebase thật. Chưa tạo hoặc nhận lời mời workspace tự động, chưa kết nối repo bằng GitHub App. Các quyết định workspace ownership/capability và Admin sẽ chốt sau.

## Kiểm tra local

Không chạy tests trong bước này. Build/analyze/lint chỉ kiểm tra mã nguồn; không phải bằng chứng Rules đang publish hoặc Firebase thực tế đã hoạt động. Codex không publish Rules, sửa cloud data, commit/push/deploy.

Kết quả local: Flutter analyze không có issue; Android debug APK x64 build thành công; web build/lint thành công; git diff --check sạch. Cảnh báo Kotlin của FlutterFire và bundle Vite >500kB vẫn còn như các bước trước.
