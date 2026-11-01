# Hướng dẫn nội bộ cho Codex tạo FLUTTER_HANDOVER.md

Codex phụ trách viết FLUTTER_HANDOVER.md sau khi người dùng gửi và duyệt DESIGN.md do agent ngoài thiết kế. Không giao tài liệu này cho agent ngoài. Nội dung bên dưới là hướng dẫn công việc tiếp theo của Codex, chưa phải file bàn giao đã hoàn thành. Nếu sửa quyết định điều hướng hoặc phạm vi trong DESIGN.md, chốt lại trước khi viết handover.

```text
Bạn là kỹ sư Flutter phụ trách chuyển đặc tả thiết kế Vista CI thành tài liệu bàn giao triển khai. Đọc DESIGN.md đã được chủ dự án duyệt, docs/project/09-pham-vi-workspace-agents.md, mobile/pubspec.yaml, mobile/lib/main.dart và model/prototype trong web/src/features/workspaces/.

Nếu chưa có DESIGN.md hoặc chưa biết bản nào được duyệt, chỉ báo thiếu đầu vào; không tự thiết kế lại hoặc khẳng định đã bàn giao xong.

Tạo FLUTTER_HANDOVER.md ở thư mục gốc repo. Không viết code ứng dụng, không cài package, không thay Firebase, không gọi GitHub/AI, không deploy. Viết bằng tiếng Việt. Ghi phiên bản/ngày hoặc commit của DESIGN.md được dùng.

RÀNG BUỘC
- Mobile dùng bottom tab. Web dùng header và chỉ được tham khảo nội dung, không sao chép bảng/sidebar thành màn hình mobile.
- Bộ lọc mở qua nút nhỏ với vùng chạm phù hợp; mobile dùng cơ chế được duyệt trong DESIGN.md.
- Flutter theo MVVM: View hiển thị, ViewModel quản lý state/lệnh, Repository điều phối dữ liệu, Service giao tiếp SDK/backend. Không để GitHub/AI private credential trong app.
- Tận dụng dependency hiện có và framework Flutter khi đủ. Package/state library mới chỉ được đề xuất cùng lý do, chưa tự cài.
- Agent API chưa chốt, ưu tiên miễn phí; client chỉ gọi hợp đồng backend, không gọi provider trực tiếp.
- Giữ phạm vi nhiều repo/workspace, log, phân tích, chạy mới/chạy lại, cả tạo issue và comment PR, audit. FCM sau MVP.
- AI không cấp quyền hoặc tự quyết định đăng nội dung. Lỗi chưa rõ không bịa vị trí, không tự retry.

NỘI DUNG BÀN GIAO
1. Mục tiêu, phạm vi, nguồn thiết kế và thực trạng Flutter còn scaffold.
2. Mapping screen ID trong DESIGN.md → tên route/screen → ViewModel → Repository. Không làm mất màn hình hoặc trạng thái.
3. Bottom tabs và nested navigation: stack riêng nếu thiết kế yêu cầu, đổi workspace, giữ/khôi phục bộ lọc, back/deep link, session hết hạn. Xác định rõ khi nào giữ bottom bar.
4. Mapping token sang ThemeData/ColorScheme/TextTheme và hằng spacing/radius/motion. Cỡ chữ, weight, line height và font tiếng Việt phải truy vết được token. Không lấy hero font web áp nguyên lên màn hình điện thoại.
5. Danh mục widget tái sử dụng với props, variants, semantics và trạng thái. Tránh component chỉ có happy path.
6. Từng screen: layout từ trên xuống, SafeArea, scroll, CTA, filter, điều kiện enable/disable, loading/empty/error/no-permission/stale, feedback, keyboard và text scaling.
7. Model và enum: workspace/membership/repository, run+attempt+job+step, log segment/cursor, diagnosis+evidence, command request/result, audit. Phân biệt status và conclusion, actor và PR/commit author. Giá trị lạ phải có unknown.
8. Repository/service contract ở mức chữ ký và mô tả. Cursor pagination, subscription lifecycle, retry lỗi đọc, hủy listener khi dispose/logout/đổi workspace. Chống response cũ ghi đè workspace/run mới và chống gửi lặp.
9. Chi tiết log/agent: bảo toàn khoảng trắng/code, cuộn ngang, sao chép; trạng thái phân tích/quota/lỗi; dẫn chứng quay lại đúng log. Không lưu toàn bộ log lớn vào ViewModel hoặc Firestore mà không có giới hạn được mô tả.
10. Issue/comment và quick actions: bản nháp, review, gửi có request ID, unknown outcome, reconcile và audit phía server. Không xem local state là bằng chứng audit tin cậy hoặc GitHub đã nhận.
11. Cấu trúc thư mục Flutter đề xuất và thứ tự triển khai theo dependency. Tách demo fixtures khỏi adapter thật; chỉ rõ phần nào chưa có API.
12. Checklist nghiệm thu theo từng màn hình và luồng end-to-end. Đây là kế hoạch; không ghi tests/build passed khi chưa chạy. Không tạo hoặc chạy tests trong nhiệm vụ chỉ viết tài liệu này.
13. Các điểm còn chờ backend/permission/provider, không tự quyết định thay chủ dự án. Ghi rõ dữ liệu nào là input bắt buộc để implement.

YÊU CẦU ĐẦU RA
- Chỉ tạo FLUTTER_HANDOVER.md.
- Mọi screen/token/component tham chiếu đúng ID của DESIGN.md. Nếu thiếu thì ghi gap và đề xuất bổ sung, không tự tạo chuẩn mâu thuẫn.
- Có một ví dụ bàn giao đầy đủ cho Run Details: log → phân tích → xem trước comment/issue/chạy lại → kết quả/audit.
- Báo ngắn file đã tạo, nguồn thiết kế và các gap còn mở. Không sửa code hay gọi dịch vụ.
```
