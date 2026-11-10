# 06. Kế hoạch kiểm thử và kịch bản demo

**v0.3 - Kế hoạch, chưa phải báo cáo đã chạy - 01/11/2026**

## 1. Bằng chứng hiện có

| Kiểm tra | Bằng chứng | Kết luận giới hạn |
| --- | --- | --- |
| Dart analysis | Thành công trên cloud run 41219589321 | Không chứng minh Auth, Rules hay nghiệp vụ |
| Android debug build | Run success, APK 64.240.731 bytes | Chứng minh tạo được APK |
| Artifact checksum | SHA-256 đã đối chiếu khi tải file | Chứng minh file tải về khớp artifact |
| APK native runtime | Có `lib/x86_64/libflutter.so` | Có runtime Flutter x86_64; SDK khác có thể kèm thư viện ABI khác |
| Cài và mở Genymotion | Chưa có bằng chứng | Chưa kết luận runtime/Firebase init |
| Login, Firestore, phân quyền | Chưa triển khai | Chưa chạy kiểm thử chức năng |
| Web build, Hosting, FCM | Chưa có bằng chứng trong phạm vi kiểm tra này | Không kết luận hoạt động |

Không dùng số lượng tests của SAGA làm số lượng tests của Vista. Review SAGA nhấn mạnh demo có ngữ cảnh và chứng minh luồng dữ liệu; áp dụng bài học này bằng một kịch bản Vista nhỏ và có kết quả nguồn đối chiếu được.

## 2. Ma trận kiểm thử đề xuất

Tất cả TC bên dưới đang ở trạng thái **chưa chạy cho nghiệp vụ Vista**; TC-10 có bằng chứng build nền tảng nhưng phần cài/chạy vẫn chưa kiểm tra.

| TC | Yêu cầu | Tình huống | Kết quả cần thấy |
| --- | --- | --- | --- |
| TC-01 | AUTH-01 | Đúng/sai mật khẩu, mất mạng | Chỉ tài khoản đúng vào app; lỗi rõ, không để lại state đã đăng nhập giả |
| TC-02 | AUTH-02 | Thiếu profile/inactive, Admin và Member | Chặn tài khoản chưa cấp quyền; route và quyền đúng role |
| TC-03 | AUTH-03 | Logout rồi đổi tài khoản | Dữ liệu người trước không còn trên UI; listeners cũ bị hủy |
| TC-04 | PRJ-01 | Member A xem project của Member B | Query/document trái quyền đều bị từ chối tại Firestore |
| TC-05 | PRJ-02 | Admin sửa metadata/member; Member gửi cùng request | Admin chỉ sửa trường cho phép; Member bị chặn kể cả gọi SDK trực tiếp |
| TC-06 | RUN-01/02 | Empty, 1 run, trên 20 run, lọc branch/conclusion | Không bịa số liệu; phân trang và lọc đúng phạm vi; label thể hiện tập dữ liệu |
| TC-07 | RUN-03 | Run không tồn tại, artifact hết hạn hoặc GitHub denied | Có thông báo và link nguồn; không crash/không mở khóa quyền ngoài hệ thống |
| TC-08 | SYNC-01 | Hoàn tất một run GitHub thật | Run ID/attempt/SHA/conclusion giống giữa GitHub, Firestore, mobile và web |
| TC-09 | SYNC-01 | Failure/cancelled, nhận lại event, publish lỗi | Không mất run lỗi; cùng event không nhân bản; có cách retry publish |
| TC-10 | INF-01 | Build đúng ABI, tải và cài APK | Checksum đúng, cài được, app mở được; ghi nhận Firebase init runtime riêng |
| TC-11 | INF-02 | PR web lỗi build; main build đạt | Bản lỗi không deploy live; bản đạt có URL truy cập route trực tiếp được |
| TC-12 | AUTH-04 | Yêu cầu reset mật khẩu | Hành vi phù hợp, không lộ thông tin tài khoản |
| TC-13 | NTF-01 | Cho/từ chối quyền, foreground/background | App vẫn dùng được khi từ chối; push được chứng minh bằng thiết bị thực nhận |
| TC-14 | ACT-01 bắt buộc | Chạy mới/chạy lại hợp lệ; sai quyền/project/ref; bấm lặp và mất mạng | Có run/attempt thật đối chiếu; backend chặn trái quyền, chống gửi lặp; không báo hoàn tất từ việc nhận lệnh |
| TC-15 | AUTH-02/SYNC-01 | Client cố đổi role hoặc conclusion | Rules từ chối; chỉ server đáng tin cậy ghi run |
| TC-16 | NTF-01/AUTH-03 | Logout/chuyển tài khoản trên cùng thiết bị | Token binding không gửi nội dung riêng của người trước cho người sau |

TC-14 là điều kiện nghiệm thu bắt buộc vì chạy/chạy lại đã được xác nhận thuộc MVP. TC-13/16 dành cho giai đoạn FCM sau MVP đã chốt, không chặn nghiệm thu MVP ban đầu. Khi làm giai đoạn FCM, hai TC này trở thành điều kiện nghiệm thu phần thông báo.

## 3. Kiểm tra theo tầng

- ViewModel/repository: trạng thái đăng nhập, loading/error, mapping conclusion lạ, hủy subscription, paging.
- Rules: request trái quyền thực tế, tự nâng role, ghi run giả và query sai phạm vi. Dùng Firebase Emulator/rules tests trên cloud nếu không muốn cài emulator trên máy.
- UI: test các chuyển trạng thái quan trọng; không tạo tests chỉ kiểm tra lại literal/boilerplate.
- Tích hợp: tài khoản thật, một run thật, một APK chạy được, một URL Hosting.
- FCM/điều khiển GitHub: kiểm tra riêng sau khi nền tảng và quyền đã ổn định.

Đây là kế hoạch thêm kiểm tra, không có test files hay lệnh build mới được chạy trong lần chỉ soạn tài liệu.

## 4. Điều kiện kiểm tra FCM trên Genymotion

FCM Android cần Google Play services tương thích. Genymotion không có sẵn thành phần này trên mọi thiết bị mặc định; phải kiểm tra thiết bị cụ thể. Android 13+ còn cần xin quyền thông báo. Nếu môi trường không đáp ứng, dùng điện thoại Android phù hợp để kiểm tra FCM; không kết luận logic app hỏng chỉ từ một emulator thiếu thành phần.

Nguồn: [Firebase FCM Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started?hl=en), [quyền thông báo](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages), [Genymotion Open GApps](https://docs.genymotion.com/features/opengapps/).

Tách ba bằng chứng: sender được FCM chấp nhận; thiết bị nhận; nhấn thông báo mở đúng run. Ba việc đó không tương đương nhau. Không cần thêm thông tin backend/GMS vào mọi màn hình sản phẩm; đây là điều kiện trong tài liệu kỹ thuật và kiểm thử.

## 5. Kịch bản demo MVP đề xuất

1. Mở web và mobile, đăng nhập hai tài khoản đã cấp quyền. Thử sai mật khẩu một lần.
2. Admin sửa tên dự án hoặc thêm Member. Member chỉ thấy project được cấp quyền; thử truy cập một project không thuộc quyền để chứng minh bị chặn.
3. Từ Vista, bấm chạy mới workflow được phép; đối chiếu run ID/commit trên GitHub. Thử yêu cầu trái quyền và xác nhận backend từ chối.
4. Sau khi run hoàn tất và publisher cập nhật, mở cùng run trên Firestore/mobile/web để đối chiếu conclusion và SHA.
5. Mở artifact; cài APK đúng ABI trên Genymotion. Giải thích artifact là bản debug và lịch sử đã hết hạn vẫn có metadata.
6. Logout và đổi tài khoản, xác nhận không còn dữ liệu state của phiên trước.
7. Từ Vista, bấm chạy lại run ở bước 3; đối chiếu attempt mới và kết quả đồng bộ.
8. Ở giai đoạn FCM sau MVP: chạy kịch bản riêng chứng minh thiết bị nhận thông báo và mở đúng run. Bước này không chặn demo MVP ban đầu.

Mỗi bước ghi rõ dữ liệu nào là demo seed và dữ liệu nào do GitHub thật tạo ra. Không dùng số liệu tĩnh để diễn rằng event đã được đồng bộ.

## 6. Hồ sơ kết quả về sau

Báo cáo kiểm thử cần có: ngày, commit, môi trường/thiết bị/ABI, TC, expected/actual, trạng thái passed/failed/skipped/not-run và link bằng chứng. Lỗi phải giữ lại, không ghi tất cả passed chỉ vì pipeline xanh. Trạng thái mẫu trong tài liệu hiện tại là kế hoạch, chưa phải biên bản nghiệm thu.
