# 22. Triển khai code mục2–5: kết nối, workspace, CI/CD/log và Flutter

Ngày 02/11/2026. Scope: repo public thuộc account GitHub đã đăng nhập, role user. Agent, private repo, quick actions workflow, PR/issue/audit/FCM vẫn để sau.

## Trạng thái thực hiện

| Mục | Code | Xác minh thực tế |
|---|---|---|
| 2. Backend quản lý token | Vault AES-256-GCM, xác minh Firebase + GitHub ID, refresh rotation/lease; màn trạng thái và ngắt kết nối trên web/app | Còn cần env/IAM/OAuth callback bước21 và luồng thật |
| 3. Workspace | CRUD workspace + repo link trên cả web/Flutter, thêm repo tại workspace, tên/nút repo mở đúng CI; giữ lựa chọn theo UID | Người dùng đã xác nhận tạo workspace trước đây; luồng mới cần đối chiếu |
| 4. CI/CD/log | Run status/conclusion, filter/phân trang, job/step đúng attempt, log gốc và error marker; empty/error/expired/truncated | Chưa xác minh API log bằng account thật |
| 5. Flutter | Dùng chung backend; không giữ GitHub token; browser OAuth, quản lý kết nối, job/log, cấu hình URL và navigation metadata | Analyze/build APK được ghi theo kết quả cuối lượt. Chưa chạy máy thật vì ADB hiện chưa có thiết bị |

Không coi bảng code là chứng nhận hoàn tất nghiệm thu. Không push/deploy hoặc tự sửa Console trong lượt này.

## 1. Quản lý kết nối và quyền

Web Tài khoản và mobile Tài khoản có trạng thái connection, account GitHub, thời điểm access/refresh token đến hạn; bấm Cập nhật để gọi backend refresh khi cần. Nhãn Đã lưu kết nối không khẳng định GitHub đã kiểm tra token ở mọi thời điểm; API sẽ xử lý401/revocation khi gọi.

Ngắt kết nối có xác nhận rõ phạm vi mọi thiết bị Vista, giữ phiên Firebase. Backend xóa ciphertext ngay và đổi connectionId trước khi gọi GitHub để thu hồi grant. Giữ tombstone không chứa token để refresh/callback cũ không phục hồi kết nối. OAuth start/callback được kiểm tra version; không bắt đầu kết nối mới trong thời gian ngắt đang chạy.

Backend yêu cầu GitHub thu hồi grant của OAuth App/user; điều này có thể ảnh hưởng các token khác của cùng ứng dụng và yêu cầu cấp quyền lại sau này. Nếu không xác nhận được thu hồi (ví dụ token cũ đã hết hạn hoặc lỗi mạng), UI báo rõ: token Vista đã xóa, người dùng có thể vào GitHub Authorized OAuth Apps để thu hồi từ GitHub. Không báo thu hồi thành công giả.

Vault và trạng thái OAuth mobile đều deny client read/write trong firebase/firestore.rules; Admin SDK dùng IAM. Không có role admin trong nghiệp vụ được thêm.

## 2. Kết nối GitHub trên điện thoại

Native app không tự giữ access/refresh token và không cần nhúng Client Secret/service account. Luồng:

1. Firebase đăng nhập và hồ sơ user đã active.
2. App gửi Firebase ID token tới backend `mobile-start`.
3. Backend cấp ticket random256bit một lần, requestID là SHA-256, thời hạn10 phút. State/PKCE mã hóa trong Firestore collection `githubOAuthRequests`.
4. App mở `mobile-open` trong trình duyệt. Backend tiêu thụ ticket, xóa encryptedState trong doc, đặt cookie HttpOnly và chuyển tới GitHub.
5. Callback chung bước21 xác minh đúng GitHub ID/Firebase UID, ghi vault và cập nhật trạng thái request. Không truyền token GitHub cho app/browser.
6. App hỏi kết quả mỗi3 giây trong thao tác kết nối, tối đa10 phút; trở lại app sau khi cấp quyền. Có Hủy chờ, logout/account change/dispose bỏ callback cũ.
7. Request hoàn tất được xóa sau khi đọc kết quả. Record hết hạn không còn dùng được; các record cũ của chính UID được dọn tối đa20 mỗi lần bắt đầu kết nối mới. Không cần cấu hình TTL/billing cho luồng này.

Không dùng deep link tùy ý, không yêu cầu bật GitHub Device Flow. Browser và app phải truy cập được cùng origin backend. Khi app nghỉ nền, hệ điều hành có thể tạm ngưng polling; quay lại app để tiếp tục nhận trạng thái.

## 3. Cấu hình và chạy điện thoại local

Backend cấu hình theo bước21, chạy từ web:

```bash
npm run dev
```

Vite chỉ dùng port5173. Với điện thoại debug, sau khi kết nối ADB (USB **hoặc wireless debugging**) và thấy device:

```bash
adb reverse tcp:5173 tcp:5173
```

Lệnh này chuyển localhost:5173 trên điện thoại về Vite trên máy tính. Không bắt buộc USB nếu ADB Wi-Fi đã pair/connect.

Trong app → Tài khoản → Backend và kết nối GitHub → URL:

```text
http://localhost:5173
```

Bấm Lưu URL backend. Dùng đúng localhost như VISTA_APP_ORIGIN/callback của bước21. Không dùng localhost nếu chưa adb reverse; điện thoại sẽ tìm server trên chính điện thoại.

Android debug chỉ mở HTTP cho localhost/127.0.0.1 bằng network security config riêng. Release không dùng cấu hình debug; dùng HTTPS Vercel. Không mở HTTP toàn mạng LAN để gửi Firebase ID token.

URL backend lưu bằng SharedPreferences, không phải secret. App báo rõ Firebase ID token sẽ gửi tới URL đó; chỉ nhập server Vista do bạn quản lý. Có thể đặt VISTA_BACKEND_URL bằng dart-define lúc build nếu muốn, nhưng không bắt buộc vì đã có ô cấu hình trong app. Thêm plugin SharedPreferences nên cần cold restart/cài lại APK, không chỉ hot reload.

APK arm64 sau build: `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

## 4. Dùng Vercel sau này

Giữ Root Directory web, deploy cả api/server với các secret server bước21. Đổi VISTA_APP_ORIGIN sang origin HTTPS Vercel ổn định, thêm callback tương ứng trong GitHub và domain trong Firebase Auth. Trong app lưu chính origin HTTPS đó. Không cần adb reverse khi dùng server HTTPS public.

Không chỉ upload dist vì API không nằm trong static bundle. Không đặt server secrets vào VITE_ hoặc dart-define.

## 5. Workspace và điều hướng

- Thêm repo tại workspace; chỉnh nhãn/note/gỡ link không đổi source GitHub.
- Bấm tên/nút CI/CD và log mở tab CI đã chọn repo; chọn workspace mới bỏ ngữ cảnh run cũ.
- Web giữ tab/workspace/repo qua sessionStorage metadata; Flutter giữ metadata theo Firebase UID trong SharedPreferences. GitHub token không ở các nơi này.
- Startup/reload vẫn xác minh Auth/profile và lấy nguồn GitHub thật; không lưu log nhạy cảm vào preferences hoặc Firestore để giả tạo history.
- Đổi UID xóa model cũ, request response kiểm tra UID/generation. Repo bị gỡ hoặc workspace lỗi/xóa không tiếp tục hiển thị detail run cũ trên Flutter.

## 6. Đọc lỗi và log

Run → Chi tiết/log → chọn job → xem các step. Failure/timed_out được phân biệt, attempts không trộn. Log gốc đọc qua backend; có nguồn GitHub, retry, wrap và dấu error GitHub, chưa có AI phân tích.

Backend timeout20s cho tải log, giới hạn2MiB đầu. HTTP404/410 ở nguồn log báo chưa có/hết thời gian lưu/xóa/không còn quyền. Job chưa hoàn tất có thông báo chờ và nút cập nhật, không gọi là log rỗng/thành công.

Flutter giới hạn render100.000 ký tự mỗi lần để tránh layout log quá lớn, cho đổi đầu/cuối phần đã tải. Ghi rõ nếu server đã cắt2MiB đầu, phần cuối thực sự có thể chưa có; link mở đúng GitHub run/attempt để xem toàn bộ. Render log dạng text, không thực thi HTML/command từ log.

## 7. Checklist nghiệm thu sau cấu hình

- Account A chỉ đọc vault/request của A; callback tài khoản GitHub khác bị từ chối.
- Kết nối từ web → app cùng UID dùng được, và ngược lại.
- F5/restart/cold start không bắt cấp token lại khi refresh còn hợp lệ.
- Ngắt kết nối: token vault trống, callback/refresh cũ không ghi lại; phân biệt remote revocation đã/chưa xác nhận.
- Tạo/sửa/xóa workspace, thêm/sửa/gỡ repo, không ảnh hưởng repo GitHub.
- Bấm repo chuyển đúng CI, lọc branch/fail, tải thêm, mở đúng attempt/job.
- Log demo failure hiển thị marker và step bị lỗi; success không có lỗi giả.
- Sai backend URL/mất mạng/backend chưa setup không tự yêu cầu đăng nhập GitHub lại liên tục.
- App thật: cuộn, bàn phím URL/form, chuyển tab, trở lại từ browser, hủy chờ, restart app và dùng ADB Wi-Fi nếu muốn.

Nguồn: GitHub OAuth authorization API https://docs.github.com/en/rest/apps/oauth-applications và workflow jobs https://docs.github.com/en/rest/actions/workflow-jobs

## 8. Kết quả kiểm tra trong lượt triển khai

- Web build và lint thành công; vẫn có cảnh báo bundle >500kB.
- Flutter analyze không có lỗi; APK debug arm64 biên dịch thành công. Còn cảnh báo FlutterFire KGP và SDK tools; không báo chúng là lỗi build.
- ADB hai lần kiểm tra đều không có thiết bị, nên kiểm tra trên điện thoại thật đang chờ. Đã hỏi người dùng kết nối ADB; không tự coi im lặng là đã kiểm tra.
- Không có credential thật được nhập/đọc qua chat/tool; chưa xác minh callback, refresh và revoke với GitHub/Firebase production. Không chạy test tự động hoặc deploy trong lượt này.
