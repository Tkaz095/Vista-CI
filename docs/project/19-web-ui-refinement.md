# 19. Chỉnh giao diện web

Ngày 02/11/2026. Người dùng xác nhận xem được run demo pass/fail và yêu cầu cải thiện độ rõ của UI web.

## Hướng áp dụng skill

Đã đọc SKILL.md và references của https://github.com/xiaopu-ai/web-design. Áp dụng spec-first, semantic tokens, state styling, responsive, checklist; dùng DESIGN.md hiện có và bổ sung mục15. Chọn L1 theo quy tắc dashboard của Vista. Giữ font fallback hiện tại; không tải Google Fonts, không thêm animation dependency, không đưa hiệu ứng landing page vào màn quản lý.

## Thay đổi

- Header: brand mark, icon cho navigation, underline tab hiện tại, tên/initial tài khoản, skip link.
- Dải ngữ cảnh: workspace selector và chú thích theo trang; field/form/card đồng bộ.
- CI/CD: bỏ card bao toàn bộ màn; heading, repo selector và filter panel tách riêng.
- Bốn ô tóm tắt: số run đã tải, success, failure/timed_out, in_progress. Chưa có dữ liệu dùng dấu —; số không phải tổng toàn bộ lịch sử hay chỉ số hiệu suất dự án.
- Hàng lịch sử: icon + nhãn + màu + đường nhấn trạng thái; phân nhóm title/attempt, repo/workflow, branch/SHA/actor, thời gian và link log.
- Lỗi từng repo được gom trong banner có chi tiết; empty state và loading skeleton riêng.
- Form lọc tự đóng khi Apply và trả focus về trigger; giữ nguyên server query/phân trang.
- CSS biến theo docs/DESIGN, reduced motion, responsive ở1000/760/600px.

Không đổi mobile, Firebase Rules/schema, cách giữ token hay API trong lượt chỉnh UI. Job/log vẫn mở trên GitHub.

## Đối chiếu với bản cũ

Giữ palette sáng/xanh, header navigation, workspace scope, dữ liệu thật và bộ lọc nhỏ. Thay khối card lớn và các card run rời bằng dashboard có summary và hàng lịch sử để đọc nhanh. Không coi repo skill là mẫu giao diện cần clone.

## Bằng chứng và giới hạn

Web build/lint thành công; Vite còn cảnh báo bundle >500kB. Không chạy unit/integration tests. Đã rà cấu trúc JSX, styles và breakpoints; phiên browser được kết nối hiện không có tab Vista nên chưa kiểm tra hình ảnh desktop/narrow trên phiên đăng nhập thật. Người dùng xem UI bằng Vite đang chạy; nếu reload làm mất token GitHub thì vào Tài khoản kết nối lại theo luồng hiện có. Không tự khởi động server, không push/deploy trong lượt này.
