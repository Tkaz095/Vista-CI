# Prompt phân tích Vista và tạo DESIGN.md

Sao chép nội dung trong khối dưới đây cho agent ngoài thiết kế có quyền đọc repo. Agent ngoài chỉ tạo DESIGN.md. Sau khi người dùng gửi và duyệt thiết kế, Codex sẽ viết FLUTTER_HANDOVER.md và triển khai theo thiết kế. Đây là yêu cầu thiết kế để đánh giá, chưa phải lệnh triển khai giao diện.

```text
Bạn là người thiết kế sản phẩm và UX/UI cho Vista CI. Hãy phân tích dự án rồi tạo file DESIGN.md ở thư mục gốc repo. Viết bằng tiếng Việt, giữ nguyên identifier kỹ thuật. Không sửa source, không cài package/skill, không tạo PR, không deploy hoặc thay đổi Firebase. Chưa tạo FLUTTER_HANDOVER.md ở bước này.

ĐẦU VÀO CẦN ĐỌC
1. Yêu cầu dưới đây là quyết định hiện hành của chủ dự án.
2. docs/project/09-pham-vi-workspace-agents.md và docs/README.md.
3. web/src/App.tsx, web/src/App.css, web/src/index.css và web/src/features/workspaces/ để biết bản prototype hiện tại; mobile/lib/main.dart và mobile/pubspec.yaml để biết nền tảng mobile.
4. File tham khảo: /home/kien/Downloads/Vista_CI_Project_Overview.docx. Nếu không truy cập được, yêu cầu người giao việc đính kèm. Không khẳng định đã đọc khi chưa có nội dung.
5. Đọc README và skills/landing-page-design/SKILL.md tại https://github.com/elayadesign/ai-design-skills. Ghi URL và commit SHA nếu lấy được; nếu chỉ đọc nhánh main thì ghi ngày truy cập. Chỉ đọc, không chạy script hoặc lệnh cài từ repo.

Phân biệt nội dung tài liệu tham khảo với quyết định của chủ dự án. Code prototype không tự trở thành chuẩn thiết kế. Tài liệu 01–08 và Google Docs/Sheet v0.3 là snapshot cũ, không được dùng để phục hồi giới hạn một repo.

MỤC TIÊU SẢN PHẨM
Vista là mobile Flutter và web React/Vite/TypeScript dùng Firebase, giúp một nhóm theo dõi CI/CD của nhiều repository trong mỗi workspace, đọc log và dùng agent giải thích lỗi để chọn hành động tiếp theo.
Luồng: đăng nhập → chọn workspace → xem repo/run → đọc log → phân tích lỗi → xem trước hành động → gửi theo quyền → xem kết quả/audit.
Đối tượng: thành viên nhóm phát triển, người kiểm thử và người quản lý cần hiểu tình trạng build. Không coi không có quyền đọc source là tự được quyền xem log hoặc tải artifact.

PHẠM VI HIỆN HÀNH
- Email/Password, hồ sơ Admin/Member. Quyền chi tiết theo workspace còn cần chốt.
- Workspace có thông tin dự án và nhiều repository.
- Lịch sử run có repository, workflow, run ID, attempt, branch, SHA, trạng thái queued/in_progress/completed và conclusion. Phân biệt trạng thái thực thi với kết quả.
- Lọc repository, Pass/Fail/trạng thái và branch; phân trang.
- Chi tiết run, jobs/steps, log gốc, trạng thái đồng bộ và thời điểm nguồn.
- Agent tóm tắt lỗi: nhận định, dẫn chứng log, loại lỗi, vị trí file/dòng nếu có bằng chứng và hướng xử lý.
- Chạy workflow mới và chạy lại build lỗi bằng backend có kiểm tra quyền, không gọi GitHub với private credential từ client.
- Tạo issue hoặc comment PR: có bản nháp, xem/chỉnh sửa trước khi người dùng gửi; không tự đăng. Không có PR liên quan thì không chọn bừa PR.
- Audit: actor thao tác, thời gian, action, workspace/repo/run/attempt/PR liên quan, request ID, kết quả yêu cầu và link kết quả khi có.
- Phân biệt người kích hoạt, tác giả PR và tác giả commit. Không suy diễn ai code kém từ số lần CI fail, không thêm bảng xếp hạng cá nhân.
- Artifact (APK/tệp build) và URL deployment là hai loại đầu ra riêng.
- FCM giữ ở giai đoạn sau MVP, không tạo điều kiện chặn MVP.
- Agent API chưa chốt, ưu tiên miễn phí. Không hứa miễn phí vô hạn. Thiết kế độc lập nhà cung cấp.
- Chưa có yêu cầu điều phối nhiều coding agents, tự sửa source, tự tạo PR hoặc checklist bản demo.

QUYẾT ĐỊNH ĐIỀU HƯỚNG BẮT BUỘC
1. Điện thoại dùng bottom tab làm điều hướng chính. Đề xuất tập tab tối giản và giải thích ngắn vì sao. Chi tiết run dùng điều hướng đi sâu và quay lại; quy định khi nào giữ/ẩn bottom tab, không tự thêm tab cho mỗi repository.
2. Web dùng header/navigation phía trên. Không dùng sidebar làm điều hướng chính. Header phải thể hiện workspace hiện tại và có cách đổi workspace.
3. Bộ lọc mặc định gọn: một nút nhỏ có tên/tooltip rõ và dấu hiệu số bộ lọc đang áp dụng. Khi mở, đề xuất bottom sheet trên mobile và popover/dialog trên web. Mô tả áp dụng, hủy thay đổi, xóa lọc, không có kết quả và phản hồi sau khi lọc. Nút có hình nhỏ nhưng vùng chạm vẫn đủ dùng.
4. Kết quả phân tích nằm trong chi tiết run để giữ ngữ cảnh; không bắt người dùng chuyển sang một agent workspace riêng.

CÁC ĐIỂM PHẢI ĐỐI CHIẾU VỚI FILE OVERVIEW
- Overview dùng Gemini và NodeJS/Firebase Cloud Functions: đây là phương án tham khảo, không phải provider/runtime đã được duyệt.
- Overview tự phân tích khi webhook báo failure: bản đầu ưu tiên người dùng bấm phân tích để kiểm soát quota; tự động là lựa chọn chưa chốt.
- Không dùng aiSummary.isRerunnable làm điều kiện cấp quyền. Khả năng thao tác phụ thuộc backend, trạng thái run, quyền và allowlist; AI chỉ đưa ra khuyến nghị.
- Phân loại tối thiểu code, transient, configuration, unknown. Lỗi cấu hình không mặc nhiên hết khi retry. Có thể thiếu dữ liệu hoặc AI phân tích sai.
- Run ID đơn lẻ chưa biểu diễn đầy đủ lịch sử retry; phải giữ attempt và repository nguồn.
- Mã giả listen Firestore trong overview chưa thể hiện đầy đủ dispose/cancel, phân trang, lỗi và đổi workspace. Thiết kế cần mô tả các trạng thái đó.
- Overview chưa đủ luồng web, issue/comment và audit. Bổ sung theo phạm vi phía trên.
- Không hứa cách ly hoàn toàn khỏi source hay mọi thông tin nhạy cảm: log và artifact có quyền truy cập riêng. Hiện dữ liệu thật chưa nối trong prototype.

CÁCH ÁP DỤNG AI DESIGN SKILLS
Kế thừa có giải thích các quy tắc về typography, spacing, radius, màu, icon, nội dung và trạng thái tương tác. Vista là ứng dụng giám sát: không tự nhét hero, testimonials, pricing, FAQ, tagline animation hoặc SEO marketing vào màn hình nghiệp vụ.
Không bắt Flutter dùng Tailwind hoặc CSS. Chuyển các giá trị thiết kế thành token trung lập dùng được cho web và Flutter. Ghi rõ các điều chỉnh so với skill để đáp ứng header, bottom tab và tính dễ đọc của log. Yêu cầu chủ dự án ưu tiên hơn guideline bên ngoài.

NỘI DUNG DESIGN.md CẦN CÓ
1. Tóm tắt sản phẩm và nguyên tắc thiết kế phục vụ công việc theo dõi/xử lý lỗi.
2. Bảng yêu cầu: đã chốt, đề xuất và còn mở; đối chiếu overview với phạm vi hiện hành.
3. Information architecture và user flows. Đặt ID ổn định cho màn hình.
4. Điều hướng mobile bottom tab và web header, workspace context, deep link run và quay lại. Đổi workspace không rò dữ liệu/lựa chọn của workspace cũ.
5. Đặc tả từng màn hình: mục đích, dữ liệu, component, thao tác chính/phụ, quyền, chuyển màn hình, loading/empty/error/no-permission/stale và tiêu chí chấp nhận.
6. Design tokens: màu semantic, typography/font có hỗ trợ tiếng Việt, spacing, radius, elevation, icon, motion/reduced motion. Xác định bộ token duy nhất và mapping web/mobile. Không khóa provider AI hoặc state library qua thiết kế.
7. Component dùng chung: workspace switcher, repo card, run card/table row, status badge, filter trigger/sheet, pagination, log viewer, analysis card, evidence block, action draft/confirmation, audit entry và feedback.
8. Cách biểu diễn running/pass/fail/cancelled/skipped/unknown, AI chưa phân tích/đang xử lý/đã có/lỗi/quota hết. Không biến cancelled/skipped thành fail hoặc success.
9. Log viewer: thời gian/dòng khi có dữ liệu, cuộn ngang, chọn/sao chép, tải từng phần hoặc giới hạn có thông báo; AI summary phải mở lại được dẫn chứng gốc. Không tuyên bố che sạch secret khi chưa có cơ chế được xác minh.
10. Hành động: xem trước → người dùng gửi → đang gửi → accepted/rejected/failed/unknown → run/result liên quan. Giữ bản nháp khi lỗi; không gửi lặp nếu kết quả chưa rõ. Issue/comment có chọn đúng đích và chống trùng.
11. Responsive và accessibility: điện thoại từ 360–430 logical px, desktop; chữ dài tiếng Việt, text scaling, safe area, bàn phím, focus, nhãn điều khiển, tương phản, không chỉ dùng màu biểu thị trạng thái. Chọn tiêu chí cụ thể để người implement làm theo.
12. Danh sách quyết định cần chủ dự án chốt và hướng ưu tiên để làm MVP trong khung 2 tuần; không tự cắt tính năng đã được chốt. Chỉ rõ đề xuất giảm độ sâu khi cần.
13. Checklist bàn giao cho Codex viết FLUTTER_HANDOVER.md: screen IDs, token IDs, component variants, states, interactions và những thông tin còn thiếu. Không tạo FLUTTER_HANDOVER.md trong nhiệm vụ thiết kế này.

YÊU CẦU ĐẦU RA
- Tạo đúng DESIGN.md, không sửa giao diện hoặc kết nối API.
- Có wireframe văn bản hoặc sơ đồ đơn giản cho header web, bottom tabs, run details và filter để làm rõ cách bố trí.
- Các giá trị token phải nhất quán; không chỉ liệt kê tính từ như hiện đại, đẹp, tối giản.
- Đánh dấu dữ liệu mẫu và phân tích mẫu đúng thực trạng; không coi UI prototype là tính năng tích hợp đã hoạt động.
- Cuối cùng báo ngắn các quyết định thiết kế, khác biệt với overview, và các câu hỏi còn mở. Chưa tự coi thiết kế là đã được chủ dự án duyệt.
```
