# 24. Kiểm tra tự gia hạn và lỗi quyền tải log

Ngày 02/11/2026. Bản này ghi lại chẩn đoán lỗi ở bước23. Phần chẩn đoán ban đầu bên dưới dùng OAuth scope `read:user offline_access`; xem cập nhật cấp quyền sau đây cho code hiện tại.

## Cập nhật: kết nối lại để duyệt quyền log

- Code hiện tại yêu cầu `read:user public_repo offline_access` trong cả luồng web và mobile. `public_repo` là scope OAuth rộng, bao gồm quyền đọc/ghi repository public; giao diện Tài khoản thông báo rõ trước khi người dùng duyệt quyền GitHub.
- Không đổi quyền của token đã lưu một cách tự động. Refresh token không nâng scope. Người dùng phải bấm **Kết nối lại GitHub** và duyệt quyền bổ sung.
- Kiểm tra trực tiếp job `124877202889`: request công khai trả 403 `Must have admin rights to Repository`; request dùng credential GitHub CLI trả 302 có địa chỉ tải log. Không đưa token hoặc URL ký vào log chẩn đoán.
- Sau khi sửa code: khởi động lại `npm run dev`, vào **Tài khoản → Kết nối lại GitHub**, duyệt quyền, quay lại job và bấm **Tải lại log**. Không cần đổi Firebase Rules, tạo lại secret hoặc tự nhập token.
- Chưa xác nhận tải log bằng token Vista có scope mới cho đến khi người dùng hoàn tất cấp quyền. Nếu vẫn 403 sau khi cấp quyền, cần kiểm tra scope thực tế được GitHub cấp trước khi kết luận đã sửa xong.

## Bằng chứng đọc trực tiếp

Người dùng báo nghi access token hết hạn. Agent kiểm tra đúng connection của account GitHub Tkaz095, chỉ xuất metadata trạng thái/thời hạn và HTTP status, không xuất credential/token/ciphertext.

Tại thời điểm kiểm tra, connection đang connected, access token chưa hết hạn và GitHub chấp nhận token; refresh token tồn tại và chưa hết hạn. Quota còn hàng nghìn lượt. Điều này không chứng minh token ở ảnh trước chưa từng hết hạn, vì connection có thể vừa được cập nhật; cũng không chứng minh tự refresh đã chạy qua tình huống hết hạn thật.

| Yêu cầu GitHub | Kết quả đọc trực tiếp |
| --- | --- |
| Rate-limit metadata với access token hiện tại | HTTP200, còn khoảng4943 core requests |
| Danh sách runs DealBite-MVP | HTTP200 |
| Jobs đúng run/attempt | HTTP200 |
| Download job log | HTTP403, message chỉ ra yêu cầu admin rights to repository; không có dấu hiệu expiry/rate-limit |
| Download cùng log không kèm GitHub credential | HTTP403; không dùng anonymous fallback |

Header tokenScopes trả về `read:user`. Không tự kết luận scope nào đủ để tải log chỉ từ tên scope; chưa cấp quyền bổ sung để xác minh. OAuth scope `public_repo` có quyền đọc/ghi repo public, nên nếu lựa chọn hướng này phải nêu rõ phạm vi và xin chấp thuận. GitHub App với Actions read trên repo được chọn là một phương án thiết kế khác, chưa triển khai trong lượt này.

## Lỗi code đã xác định và sửa

1. **Gộp403 vào rate limit:** trước đây mọi403/429 đặt cooldown theo user. Request tải log thiếu quyền làm cả danh sách lịch sử bị chặn và tăng backoff. Nay chỉ đặt cooldown khi có dấu hiệu rate-limit: HTTP429, remaining0, Retry-After hoặc thông báo rate limit/abuse.403 quyền trả `GITHUB_PERMISSION_DENIED`, không chặn API lịch sử/job khác.
2. **Single-flight trả token vừa bị từ chối:** một caller đang cần forced refresh có thể join request đọc token bình thường và nhận lại chính token cũ. Nay chỉ dùng kết quả concurrent nếu token đã khác token bị từ chối; nếu chưa khác thì vào lại luồng refresh có Firestore lease.
3. **Bỏ qua OAuth error trên HTTP400:** trước đây kiểm tra response.ok trước body nên lỗi refresh token invalid có thể bị gộp thành lỗi mạng. Nay phân loại JSON error cả khi non-2xx: refresh hết hạn/thu hồi → reconnect; Client ID/Secret sai → server setup; lỗi mạng/dữ liệu tạm thời giữ cặp token đã lưu.
4. **Phân biệt expiry và quyền:** refresh khi còn dưới60 giây hoặc GitHub401/403 có nội dung chỉ rõ token hết hiệu lực (không phải rate limit), rồi thử API lại một lần. Không refresh liên tục khi403 do quyền. HTTP401 sau refresh vẫn đi theo xử lý reconnect có kiểm tra token/version hiện tại;403-expiry còn lặp lại có mã `GITHUB_AUTH_REJECTED` riêng.
5. **Bằng chứng gia hạn:** mỗi lần refresh lưu thành công tăng refreshCount và ghi lastRefreshedAt. Web Tài khoản hiển thị hai giá trị này. Dữ liệu cũ chưa có trường sẽ hiển thị chưa ghi nhận, không khẳng định chưa bao giờ refresh.

Đây là gia hạn khi có request: trước khi dùng token, backend kiểm tra hạn và refresh nếu cần. Không có cron nền tự chạy khi không ai dùng Vista; lần quay lại sau thời hạn vẫn đi qua kiểm tra refresh. Không cần login lại chỉ vì access token hết hạn nếu refresh còn hợp lệ.

## Người dùng kiểm tra tiếp

- Restart Vite để nạp server code mới và bỏ cooldown RAM cũ. Không cần đổi key/secret hoặc logout để xử lý403 tải log.
- Vào CI/CD → Làm mới: lịch sử/job cần tiếp tục đọc được dù log bị từ chối quyền.
- Mở log: nếu403 vẫn còn, UI phải báo quyền tải log, không báo rate limit hoặc expiry.
- Sau một lần refresh thật, Tài khoản cần có timestamp và refreshCount tăng. Chưa thực hiện rotation thật bằng credential người dùng hoặc thay expiresAt trong Firestore trong lượt này.
- Chưa tự thay GitHub scope, Firebase Rules/IAM hay cấu hình Console. Không push/deploy.

Web build/lint đã được chạy sau chỉnh sửa. Không thêm hoặc chạy test tự động. Việc xử lý hết hạn thật và rotation qua nhiều instance vẫn cần xác minh runtime riêng; không gọi build là bằng chứng auto-refresh hoạt động thực tế.

Nguồn: [GitHub OAuth refresh](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps), [phân loại lỗi API](https://docs.github.com/en/rest/using-the-rest-api/troubleshooting-the-rest-api), [OAuth scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps).
