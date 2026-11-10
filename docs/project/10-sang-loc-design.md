# Vista CI — Thống kê và sàng lọc thiết kế

Ngày 01/11/2026. Đầu vào là `/home/kien/Downloads/DESIGN.md` của agent và overview do người dùng cung cấp. Đầu ra là [DESIGN.md tại gốc repo](../../DESIGN.md), phiên bản 1.0. Giữ nguyên các file đầu vào.

## 1. Đánh giá bản agent

Bản agent có 1.266 dòng, 25 mã yêu cầu `R-01`–`R-25` và 19 quyết định `D-01`–`D-19`. Nó phân biệt khá rõ dữ liệu thật/mẫu, giữ nguyên phạm vi nhiều repo, log, phân tích và hành động. Tuy nhiên agent ghi chưa được đọc repo/overview nên nhiều đề xuất chưa đối chiếu thực tế. Không nên copy nguyên file thành chuẩn triển khai.

## 2. Nội dung giữ và thu gọn

| Phần | Xử lý trong bản chính thức |
| --- | --- |
| Workspace nhiều repo, run/job/step/log | Giữ đầy đủ, có ID màn hình ổn định |
| Bottom tab mobile và header web | Giữ đúng quyết định người dùng; chọn 4 tab, không sidebar web |
| Nút nhỏ mở bộ lọc | Giữ; chốt một giá trị/Tất cả cho mỗi nhóm trong baseline; không bỏ lọc repository/status/branch |
| Agent trong chi tiết run | Giữ; có input provenance, dẫn chứng xác minh và trạng thái quota/thiếu dữ liệu |
| Chạy mới/chạy lại, issue/comment | Giữ cả bốn action, preview và xác nhận đích; không cắt issue khỏi MVP |
| Audit, tách actor/PR author/commit author | Giữ; không xếp hạng chất lượng cá nhân |
| Typography, màu, spacing, icon, motion | Hợp nhất thành baseline sáng; font/icon chưa có asset hoặc kiểm glyph |
| Dark mode, mời tài khoản, reset password | Chuyển thành mở rộng, không tự coi là yêu cầu đã duyệt |
| Multi-select repo/status, tìm log nâng cao, cỡ trang 50 | Chưa bắt buộc baseline; giảm độ sâu để vừa bản đầu |
| Cài app link/universal link, streaming live log | Không hứa khi backend/chưa có cấu hình; giữ route nội bộ và trạng thái chưa có log |

## 3. Các mâu thuẫn/lỗi được sửa

| Vấn đề bản nháp | Sửa thành |
| --- | --- |
| Thiếu hồ sơ sau Auth được đưa vào workspace rỗng | Thiếu profile/inactive phải chặn; chỉ profile hợp lệ chưa có membership mới hiện workspace rỗng |
| Run fail đã phân tích luôn đẩy CTA Chạy lại | CTA theo category; code ưu tiên issue/comment, cấu hình ưu tiên hướng sửa, transient mới nhấn mạnh retry; quyền vẫn do backend |
| Mở rerun cả run success/cancelled/skipped | Baseline chỉ build thất bại theo phạm vi hiện tại; mở rộng cần yêu cầu riêng |
| accepted có lúc là backend nhận, có lúc như GitHub đã tác động | Tách received, accepted nguồn và succeeded của command; conclusion build là dữ liệu khác |
| failed có thể cho retry khi tác động chưa rõ | Outcome chưa rõ là unknown, đối soát trước khi gửi lại |
| Preview nói chắc sẽ tạo attempt n+1 | Chỉ nêu attempt nguồn và yêu cầu; link attempt mới khi GitHub xác nhận |
| Sắp theo startedAt, queued fallback tạo thời điểm khác | Sắp createdAt nguồn và khóa ổn định, tránh run đổi vị trí do bắt đầu chạy |
| neutral và stale đều thành chưa rõ | Hiển thị Trung tính/Kết quả cũ; không lẫn stale nguồn với độ mới đồng bộ |
| Hủy yêu cầu cũ có thể bị hiểu là hủy command GitHub | Chỉ hủy subscription/đọc UI; command đã gửi vẫn tra bằng request ID |
| Log mặc định có global line index/live stream | Locator theo job/segment/version, có fallback khi không có index hoặc live log |
| Cam kết bộ nhớ không tăng theo log dù không quy định cache | Dùng bounded loading/render/cache; không hứa bất khả thi |
| Khóa nhãn bottom tab text scale 1.3 | Không clamp để che lỗi; bố cục thích ứng text scale 100–200% |
| Vùng chạm 44 và line-height ratio không khớp bảng | Chọn min touch 48, giữ bảng line-height cụ thể nhất quán |
| Bảng contrast ghi đã tính/đạt chưa có bằng chứng hiện tại | Bỏ số đo chưa xác minh; giữ tiêu chí cần đo khi implement |
| Provider Gemini, Functions, auto-triage trong overview | Giữ là đề xuất, không cấp quyền mặc nhiên hoặc cam kết chi phí |

## 4. Đối chiếu repo và overview

- Flutter hiện dùng `useMaterial3: true`; chưa tách MVVM và chưa thêm font/icon mục tiêu. Material 3 không cần bị loại chỉ vì đổi họ icon.
- Web hiện dùng sidebar, dropdown filter luôn mở, Inter và blue/navy. Đây là prototype, không phải chuẩn cuối. Bản chính thức quy định header, filter trigger và bộ token sáng trung tính.
- Model mẫu đang gộp status/conclusion, evidence là một string và audit là local preview; cần adapter/model mục tiêu khi tích hợp. Không khẳng định schema live đã được đổi.
- Auth SDK/config có trong dự án không đồng nghĩa flow đăng nhập, Rules và membership đã được xác minh.
- Overview có nền tảng multi-repo, MVVM, backend trung gian, webhook và AI triage; thiếu chi tiết web/issue/comment/audit nên dùng yêu cầu hiện hành để hoàn thiện.
- Admin/Member đã chốt, nhưng phân quyền theo workspace và capability chưa chốt. Thiết kế không giả ma trận quyền đã được backend cung cấp.

## 5. Kết quả và ranh giới

`DESIGN.md` chính thức có 12 màn hình baseline, 7 lớp phủ, 21 component; loại màn reset password khỏi baseline, không loại chức năng CI/CD đã chốt. Các quyết định tích hợp được gom thành 9 nhóm `OPEN-01`–`OPEN-09` thay vì rải 19 câu hỏi giữa các mục.

File chính thức là nguồn thiết kế để người dùng đọc và làm đầu vào cho Codex viết FLUTTER_HANDOVER.md. Nó không phải chứng nhận giao diện đã implement, tài liệu được duyệt toàn bộ, hoặc hệ thống đã đạt accessibility. Không sửa code, cài dependencies, chạy tests/build, đổi Firebase hoặc cập nhật Google Docs/Sheet trong lần này.
