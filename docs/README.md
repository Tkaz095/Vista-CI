# Vista CI - Bộ tài liệu dự án

**Phiên bản hiện hành:** 0.4 | **Ngày:** 01/11/2026 | **Trạng thái:** Đang triển khai theo phạm vi workspace nhiều repo và agent đọc log.

**Đọc trước: [09. Phạm vi hiện hành — Workspace, CI/CD và agent đọc log](project/09-pham-vi-workspace-agents.md).** Vista theo luồng workspace nhiều repo → theo dõi trạng thái/kết quả/log → agent phân tích có dẫn chứng → người dùng chạy lại hoặc tạo issue/comment PR → audit. Agent chưa chốt API, ưu tiên miễn phí. Email/Password và Admin/Member được giữ; quyền chi tiết và backend/chi phí còn cần chốt. FCM làm sau MVP.

Các tài liệu 01–08 và bộ Google Docs/Sheet v0.3 là snapshot trước thay đổi phạm vi. Khi có mâu thuẫn, dùng tài liệu 09 và yêu cầu mới nhất; không áp dụng lại giả định một repo hoặc completed-only cho thiết kế mới.

Bộ tài liệu này kế thừa có chọn lọc 4 gói SAGA đã cung cấp. SAGA là hệ thống đánh giá hoạt động sinh viên, không phải sản phẩm quản lý CI/CD. Đặc biệt, “Task-Commit Pipeline” trong slide SAGA là luồng truy xuất task/commit; các yêu cầu GitHub Actions của Vista là thiết kế mới.

## Đọc theo thứ tự

**Phạm vi mới nhất theo người dùng: [16. Workspace cá nhân và repository](project/16-workspace-ca-nhan-repositories.md).** Tài khoản tự tạo workspace, xem repo GitHub trong Tài khoản, chọn và CRUD liên kết repo trong workspace. Chưa triển khai CI/CD/agent/Admin/chia sẻ ở mốc này. Model ownerUid đang là phương án triển khai, chưa thay đổi runtime.

**Quyết định mới nhất: [15. Một vai trò user và lỗi đọc hồ sơ](project/15-user-only.md).** Role mặc định/duy nhất hiện tại là `user`; Admin để giai đoạn sau. Dùng file `firebase/firestore.rules` mới nhất khi publish.

Cập nhật mới nhất: [14. Tự tạo hồ sơ khi đăng nhập lần đầu](project/14-tu-tao-ho-so.md). Người dùng không cần nhập UID hoặc tạo hồ sơ thủ công. Cần publish Rules self-create mới.

Bước tiếp theo sau khi Save GitHub provider: [13. Đăng nhập GitHub và liên kết tài khoản](project/13-github-sign-in.md). Cần liên kết từ tài khoản hiện có để giữ UID trước khi thử đăng nhập GitHub độc lập.

Bước workspace: [12. Mobile Auth và workspace dùng chung Web](project/12-mobile-auth-workspaces.md). Web Auth đã được người dùng xác nhận; mobile đã nối Auth/profile, hai client đã có code chọn workspace và đọc repository. Người dùng cần publish Rules và tạo dữ liệu theo hướng dẫn bước 12. Chưa nối GitHub/AI.

[Flutter handover](FLUTTER_HANDOVER.md) ghi ánh xạ màn hình, MVVM và giới hạn triển khai.

Đã có [DESIGN.md chính thức phiên bản 1.0](../DESIGN.md), tổng hợp từ bản agent và đối chiếu repo/overview. [Báo cáo sàng lọc](project/10-sang-loc-design.md) ghi thống kê, phần giữ/thu gọn và mâu thuẫn đã sửa. Codex đã viết handover ở link trên; [hướng dẫn nội bộ](prompts/02-flutter-handover-after-design.md) là checklist tham chiếu. Mobile dùng bottom tab, web dùng header và bộ lọc mở qua một nút nhỏ.

| Tài liệu | Câu hỏi được giải đáp |
| --- | --- |
| [01. Tổng quan và phạm vi](project/01-tong-quan-va-pham-vi.md) | Vista giải quyết việc gì? MVP gồm những gì? |
| [02. Yêu cầu và luồng sử dụng](project/02-yeu-cau-va-luong-su-dung.md) | Ai làm gì trên mobile/web? Thế nào là đạt? |
| [03. Kiến trúc và MVVM](project/03-kien-truc-va-mvvm.md) | UI, Firebase và GitHub phối hợp ra sao? |
| [04. Dữ liệu và phân quyền](project/04-du-lieu-va-phan-quyen.md) | Lưu gì, ai đọc/ghi, trạng thái nào hợp lệ? |
| [05. CI/CD và môi trường](project/05-ci-cd-va-moi-truong.md) | Viết code, build APK, chạy Genymotion, deploy web thế nào? |
| [06. Kiểm thử và demo](project/06-kiem-thu-va-demo.md) | Chứng minh đăng nhập, dữ liệu, quyền và pipeline bằng cách nào? |
| [07. Lộ trình và phiếu đánh giá](project/07-lo-trinh-va-danh-gia.md) | Cần chốt điều gì trước khi code tiếp? |
| [08. Hiện trạng và đối chiếu 4 nguồn](project/08-hien-trang-va-doi-chieu-nguon.md) | Phần nào đã có, nguồn nào chứng minh, phần nào mới đề xuất? |

Hướng dẫn thao tác đã có: [Build Android trên GitHub và chạy Genymotion](android-cloud-build.md).

## Quyết định lịch sử v0.3 — đã được tài liệu 09 cập nhật

1. **Đã xác nhận:** MVP bao gồm bấm chạy/chạy lại workflow ngay trong Vista. Còn cần chốt ai được bấm, hỗ trợ trên client nào và backend tin cậy sẽ dùng.
2. **Đã xác nhận:** một repository `Tkaz095/Vista-CI`, hai vai trò Admin/Member và đăng nhập Email/Password.
3. **Đã xác nhận:** FCM làm ở giai đoạn sau, khi đăng nhập, chạy/chạy lại và xem kết quả thật đã ổn định. FCM không chặn nghiệm thu MVP ban đầu; xem giải thích ở tài liệu 07.

Điền nhận xét tại [phiếu đánh giá](project/07-lo-trinh-va-danh-gia.md). Các tài liệu 01–08 là mốc soạn tài liệu ban đầu; trạng thái triển khai mới nhất xem bước 12. Các thao tác Firebase/GitHub do người dùng thực hiện.

## Quy ước trạng thái

- **Đã kiểm chứng:** có bằng chứng chạy hoặc kiểm tra tương ứng; nêu rõ phạm vi bằng chứng.
- **Đã có cấu hình/code:** nhìn thấy trong repo, chưa đồng nghĩa chạy đúng trên thiết bị.
- **Đã chốt yêu cầu:** người dùng đã duyệt phạm vi; chưa đồng nghĩa tính năng đã triển khai.
- **Đề xuất:** thiết kế để bạn duyệt, chưa được triển khai.
- **Cần quyết định:** không được tự xem là đã đồng ý.

Chi tiết hiện trạng nằm ở tài liệu 08. Việc build thành công không chứng minh đăng nhập, dữ liệu, FCM hoặc toàn bộ nghiệp vụ hoạt động.
