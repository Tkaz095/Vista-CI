# Analytics plan — Vista CI / Lab 3

Lập ngày 04/11/2026, trước khi thêm tracking. Phạm vi là Flutter Android và Firebase project chính `vista-ci`; project AI riêng không nhận telemetry này. GitHub tiếp tục là phương thức đăng nhập.

## Mục tiêu và thời điểm ghi nhận

Đo chuyển đổi đăng nhập → quản lý project → xem run → phân tích → gửi yêu cầu xử lý. Ghi ở ViewModel sau kết quả nghiệp vụ hoặc khi bắt đầu tác vụ được chấp nhận; không ghi từ `build()` và không coi một HTTP request được nhận là CI đã thành công.

| Event | Trigger | Parameters cho phép |
|---|---|---|
| `login` (recommended) | OAuth GitHub hoàn tất, phiên/profile đã được xác minh | `method=github` |
| `logout` | Đăng xuất do người dùng yêu cầu thành công | không |
| `session_restored` | Phiên có sẵn được xác minh, không có thao tác OAuth | không |
| `project_create` | Tạo project thành công | `repo_count` (số) |
| `project_update` | Sửa project thành công | `repo_count` (số) |
| `project_delete` | Xóa project thành công | không |
| `project_detail_view` | ViewModel chi tiết project được tạo | `repo_count` (số) |
| `workflow_detail_view` | ViewModel chi tiết run được tạo | `attempt` (số) |
| `ci_analysis_start` | Bắt đầu phân tích sau khi người dùng xác nhận preview | không |
| `ci_analysis_complete` | Kết quả phân tích hợp lệ, trước thao tác lưu Firestore | không |
| `workflow_rerun_requested` | GitHub chấp nhận rerun | `failed_only` (0/1); không diễn giải thành run success |
| `pr_comment_sent` | Đã nhận/đối soát được comment | không; không ghi khi kết quả POST chưa rõ |

Bổ sung trước khi code xuất báo cáo (05/11/2026):

| Event | Trigger | Parameters |
|---|---|---|
| `ci_report_export` | PDF từ snapshot phân tích đã được tạo thành công trên thiết bị | không |
| `ci_report_upload` | Cloudinary upload hoàn tất và nhận được secure_url hợp lệ | không |

Không gửi filename, object path, download URL, UID trong event parameters hoặc nội dung báo cáo. Retry lấy URL không ghi lặp event upload sau khi đã thành công trong cùng màn hình.

User ID dùng Firebase UID, chỉ đặt khi profile của UID đó hợp lệ. Khi đổi UID, logout hoặc profile mất quyền thì xóa User ID trước các event tiếp theo. Phiên khôi phục không ghi thêm `login`; reconnect GitHub trong cùng phiên không ghi login lần hai.

## Quyền riêng tư và hợp đồng

Tên custom event là snake_case. Code dùng enum event và allowlist parameter; loại bỏ parameter không thuộc bảng, chỉ nhận số hữu hạn trong miền hợp lệ. `method` là hằng `github`. Không gửi email, tên thật, tên project/repo, URL, SHA, log CI, prompt, phản hồi AI, comment PR, GitHub token, App Check token hoặc nội dung exception.

Crashlytics dùng cùng UID đã xác minh và custom key `build_mode`/`app_area`. Lỗi từ catch và global handlers được chuyển thành tên operation + loại exception; không gửi error.toString(), Flutter error context hoặc dữ liệu nghiệp vụ gốc. Giữ stack trace để xác định vị trí lỗi. Cố ý test crash chỉ xuất hiện trong debug, có xác nhận; non-fatal test không đóng app.

Telemetry là best effort và không làm thất bại thao tác nghiệp vụ. Hàng đợi serialize việc đổi UID và event, tránh event được gửi trước lệnh đặt/xóa UID. Không tự retry event nghiệp vụ để tránh đếm trùng. Local tests thay sink bằng fake/noop, không gửi dữ liệu thật.

## Kiểm chứng

1. Bật Analytics DebugView trên Android bằng ADB theo hướng dẫn tích hợp; login GitHub, tạo/sửa/xóa project, mở project/run, phân tích và thử rerun/comment trên repo thử nghiệm.
2. Đối chiếu tên event/parameters với bảng. Không coi unit test là bằng chứng event đã tới Console.
3. Logout/đổi tài khoản/profile mất quyền: kiểm tra UID được xóa hoặc đổi, không còn event từ ViewModel đã dispose.
4. Crashlytics: tạo non-fatal trong debug, test fatal rồi mở lại app để gửi báo cáo. Thu ảnh Console sau khi báo cáo xuất hiện.
5. Lưu commit, thiết bị, ngày chạy và ảnh DebugView/Crashlytics. Chưa có ảnh Console hoặc nghiệm thu thiết bị tại thời điểm lập plan.

Remote Config dùng `ci_analysis_enabled` (bool, default true) để điều khiển khả năng bắt đầu phân tích mới, cùng `cloudinary_cloud_name` và `cloudinary_upload_preset` (string, default rỗng) cho upload báo cáo. Tổng quan project cố định 5 repo mỗi trang trong app. Không dùng Remote Config làm phân quyền. Giá trị thiếu/sai kiểu, offline hoặc fetch lỗi dùng fallback local.
