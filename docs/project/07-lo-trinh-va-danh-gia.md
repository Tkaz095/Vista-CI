# 07. Lộ trình và phiếu đánh giá

**v0.3 - Để người dùng chốt trước khi thực hiện - 01/11/2026**

## 1. Những gì đã xác nhận trong trao đổi

- Tên Vista/Vista CI, Flutter mobile, React + Vite + TypeScript web, dùng Firebase.
- Ưu tiên cách làm nhẹ trên máy: build Android bằng GitHub Actions, chạy APK trên Genymotion.
- Câu trả lời mới nhất: đăng nhập và quản lý CI/CD là trọng tâm; dùng 4 gói SAGA làm nguồn tham khảo.
- MVP **bắt buộc có bấm chạy/chạy lại workflow ngay trong Vista**.
- Đã chốt đăng nhập Email/Password, hai vai trò Admin/Member và một repository `Tkaz095/Vista-CI`.
- Đã chốt FCM làm sau khi luồng chính ổn định; ngoài điều kiện nghiệm thu MVP ban đầu.
- Người dùng muốn biết cách làm và tự đánh giá trước. Không tự triển khai tiếp từ bản tài liệu này.

Đề xuất quản lý công việc/ghi chú trong trao đổi không được chọn, không thuộc đặc tả Vista.

## 2. Phiếu quyết định

Các ô “Chưa chốt” không được coi là đã đồng ý vì chưa có phản hồi.

| ID | Câu hỏi | Đề xuất để đánh giá | Trạng thái/ý kiến của bạn |
| --- | --- | --- | --- |
| D01 | Mục tiêu sản phẩm | Đăng nhập + quản lý CI/CD | Đã xác nhận ở mức khái quát |
| D02 | Đăng nhập bằng gì? | Email/Password trong MVP; Google Sign-In chưa thuộc scope đã duyệt | Đã chốt Email/Password |
| D03 | Role và quản trị tài khoản? | Hai vai trò Admin/Member; cấp Auth user/role qua Console vẫn là đề xuất kỹ thuật | Đã chốt hai vai trò; quyền chi tiết cần đánh giá |
| D04 | Chạy/chạy lại workflow trong Vista? | Bắt buộc có backend tin cậy; vai trò, client và allowlist cần chốt. Nút deploy riêng chưa được yêu cầu | Đã xác nhận thuộc MVP; chưa triển khai |
| D05 | Thông báo FCM có bắt buộc MVP không? | Làm sau khi đăng nhập, chạy/chạy lại và xem kết quả thật ổn định | Đã chốt giai đoạn sau; không chặn MVP ban đầu |
| D06 | Số nguồn và phạm vi dữ liệu? | Một repository Vista-CI; đồng bộ completed runs của main là thiết kế đề xuất | Đã chốt một repository; phạm vi event/ref cần đánh giá |
| D07 | Billing/server? | Ưu tiên Spark trong phạm vi hỗ trợ; không tự nâng Blaze | Chưa chốt; backend cho D04 là bắt buộc, không tự nâng billing |
| D08 | Rubric, deadline và màn hình bắt buộc của môn? | Đối chiếu khi có đề bài chính thức; SAGA chỉ là tham khảo | Chưa có nguồn để xác nhận |
| D09 | Web cho ai? | Admin quản lý project, Member có thể dùng giao diện đọc | Chưa chốt |
| D10 | Khi nào tự động thao tác repo/deploy? | Hướng dẫn từng bước; chỉ thực hiện khi bạn yêu cầu rõ hành động | Theo yêu cầu làm việc của người dùng |

Phản hồi mới nhất thay thế trạng thái “chưa chắc chắn”: người dùng đã chốt phương án một repository, Admin/Member, Email/Password và FCM làm sau luồng chính. D02/D03/D05/D06 đã chốt về phạm vi; D04 giữ nguyên bắt buộc. Backend/billing, client được thao tác, quyền chi tiết và phạm vi event/ref chưa được tự coi là đã duyệt.

Có thể ghi mỗi dòng theo mẫu: `D04: Đồng ý / Sửa thành ... / Hoãn`. Duyệt nội dung tài liệu không tự động là lệnh viết code, commit, push hoặc deploy.

### FCM và quyết định D05 đã chốt

**FCM = Firebase Cloud Messaging**, dịch vụ gửi thông báo đẩy. Ví dụ: bạn bấm chạy build trong Vista rồi đóng app; khi build thất bại, điện thoại hiện thông báo “Build thất bại”. Nhấn thông báo có thể mở chi tiết run nếu được triển khai.

- Firebase Authentication: đăng nhập và xác định người dùng.
- Cloud Firestore: lưu dữ liệu project/run để mobile và web đọc.
- FCM: báo cho người dùng biết có sự kiện mới; không chạy build, không thay dữ liệu run.

Không cần FCM để đăng nhập, bấm chạy/chạy lại hoặc xem kết quả. Đã chốt làm phần này sau luồng chính, ngoài điều kiện nghiệm thu MVP ban đầu; nhận push còn phụ thuộc thiết bị, quyền thông báo và sender tin cậy. Xem [FCM chính thức](https://firebase.google.com/docs/cloud-messaging).

## 3. Các mốc đề xuất

| Mốc | Công việc | Điều kiện kết thúc |
| --- | --- | --- |
| M0 - Duyệt thiết kế | Giữ các phạm vi đã chốt; đánh giá backend/chi phí, quyền chi tiết, client, event/ref, D08/D09 và tiêu chí demo | Không còn mâu thuẫn giữa scope, màn hình, data và backend |
| M1 - Runtime nền tảng | Người dùng cài APK và xác nhận app/Firebase Core mở được | Có bằng chứng thiết bị và ABI; không chỉ build xanh |
| M2 - Auth + MVVM | Tách Auth theo View/ViewModel/Repository; tích hợp hai client, cấp profile/role | TC-01/02/03/15 phần Auth đạt |
| M3 - Firestore + quyền | Seed một project, thiết kế/deploy rules/indexes, UI list/detail và quản lý metadata | Query đúng quyền, sửa metadata đúng trường, không ghi run từ client |
| M4 - Kết quả CI thật | Thêm publisher tin cậy, mapping run/artifact, retry/idempotency | TC-08/09 đạt, cùng dữ liệu trên mobile/web |
| M5 - Điều khiển bắt buộc | Backend môi giới, GitHub quyền tối thiểu, allowlist, audit và UI request state | TC-14 đạt cho cả chạy mới và chạy lại; có kết quả nguồn đối chiếu |
| M6 - Web CD | Web build/lint, Hosting config, credential deploy được quản lý đúng | Có URL live, PR lỗi không deploy, branch deploy được kiểm soát |
| M7 - Nghiệm thu MVP | Demo xuyên suốt, cập nhật docs và báo cáo bằng chứng | Các yêu cầu MVP được xác minh; ghi rõ lỗi còn mở, không phụ thuộc FCM |
| M8 - FCM sau MVP, đã chốt | Device token, permission, sender, xử lý notification | TC-13/16 đạt trên thiết bị đáp ứng điều kiện |

ACT-01 là yêu cầu MVP bắt buộc: thiết kế backend/billing của M5 phải chốt ngay ở M0 và hoàn thành trước nghiệm thu. FCM đã chốt ở giai đoạn sau MVP. Nghiệm thu MVP ban đầu tại M7 theo các yêu cầu cốt lõi; M8 bổ sung thông báo sau khi luồng chính ổn định.

Chưa ước lượng thời gian hoặc phân công thành viên vì chưa có deadline/nhân lực chính thức.

## 4. Backlog theo phụ thuộc

1. Duyệt sản phẩm và vai trò -> Auth/profile -> Firestore access model.
2. Contract project/run -> Rules/query/index -> màn hình dữ liệu thật.
3. Quyền publisher và source allowlist -> ingest -> đối soát kết quả.
4. Web Firebase config -> CI web -> Hosting CD.
5. Sau nghiệm thu luồng chính: FCM đã chốt -> kiểm tra GMS/permission -> token lifecycle -> test send -> notification theo event.
6. Chốt quyền và runtime điều khiển bắt buộc -> backend/GitHub credential -> kiểm tra quyền -> UI trigger/rerun.

Không bắt đầu bằng trang dashboard có nhiều biểu đồ trước khi biết dữ liệu thật được tạo ra như thế nào. Một luồng login -> project -> run -> nguồn GitHub đủ rõ sẽ có giá trị demo hơn nhiều màn hình chưa nối dữ liệu.

## 5. Rủi ro cụ thể và cách đánh giá

| Điểm cần xem | Tác động | Cách xử lý đề xuất |
| --- | --- | --- |
| Nhầm SAGA Continuous Assessment với CI/CD | Làm sai sản phẩm | Giữ bảng đối chiếu nguồn ở tài liệu 08 |
| Bỏ chức năng chạy/chạy lại đã được xác nhận | MVP không đạt yêu cầu | Giữ ACT-01 bắt buộc, chốt backend và quyền trước code |
| Chỉ gửi dữ liệu ở cuối job success | Không thấy failure/cancelled | Publisher dựa trên workflow hoàn tất, kiểm tra event |
| Dùng token quản trị trong client | Mất kiểm soát dự án/nguồn | Credential ở môi trường tin cậy, rules và IAM rõ |
| Genymotion thiếu Google Play services | FCM không nhận | Kiểm tra điều kiện, dùng thiết bị phù hợp để xác minh |
| Artifact/signing cache hết hạn | Không tải/cập nhật APK như kỳ vọng | Giữ metadata, build lại; release signing là bước riêng |
| Máy thiếu dung lượng | Không build local được | Dùng cloud build, không coi Genymotion là compiler |

## 6. Checklist để bạn đánh giá bộ tài liệu

- [ ] Tôi đồng ý cách diễn giải “đăng nhập và quản lý CI/CD”.
- [x] MVP bao gồm bấm chạy/chạy lại workflow trong Vista (D04).
- [ ] Tôi đã chốt ai được thao tác, client hỗ trợ và backend/chi phí.
- [ ] Tôi hiểu phần nào kế thừa SAGA và phần nào do Vista thiết kế mới.
- [ ] Tôi đồng ý hoặc sửa danh sách màn hình và hai vai trò.
- [x] FCM làm sau luồng chính, không chặn MVP ban đầu.
- [x] MVP dùng một repository, hai vai trò Admin/Member và Email/Password.
- [ ] Tôi đã kiểm tra điều kiện thiết bị trước giai đoạn FCM.
- [ ] Tôi chấp nhận mô hình dữ liệu và phạm vi quyền từng vai trò.
- [ ] Tôi biết bằng chứng hiện có mới xác nhận build APK, chưa xác nhận nghiệp vụ.
- [ ] Tôi đã đối chiếu hoặc sẽ bổ sung rubric môn học.
- [ ] Tôi đã ghi các chỉnh sửa trước khi yêu cầu làm bước tiếp theo.
