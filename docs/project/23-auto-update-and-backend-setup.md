# 23. Tự cập nhật CI/CD và lỗi thiếu cấu hình backend

Ngày 02/11/2026. Thay đổi lần này áp dụng cho web; Flutter không được đổi chu kỳ cập nhật trong lượt này.

## Nguyên nhân lỗi đang gặp

Người dùng đã cung cấp lỗi cụ thể: `Backend chưa cấu hình FIREBASE_PROJECT_ID`.

Firebase SDK trong trình duyệt và Firebase Admin SDK trong backend có cấu hình riêng. Đăng nhập Vista thành công chỉ chứng minh phía trình duyệt đã đăng nhập được. Backend chưa có biến môi trường nên không xác minh được Firebase ID token và chưa gọi tới GitHub. Logout/login không bổ sung cấu hình server.

Kiểm tra local cho thấy chưa có `.env`, `.env.local`, `.env.development` hoặc `.env.development.local` trong thư mục web. Không đọc/in credential. Cấu hình ngoài repo hoặc process env có thể tồn tại, nhưng lỗi API xác nhận FIREBASE_PROJECT_ID chưa được cung cấp cho process đang phục vụ request.

## Cấu hình local — người dùng thực hiện

### 1. Tạo file cấu hình backend

Trong terminal:

```bash
cd /home/kien/FPTU/Semester-8/PRM393/Lab3-Assignment/Vista-CI/web
cp -n .env.example .env.local
```

File này đã được gitignore. Mở `.env.local` trong editor và điền:

| Biến | Điền gì / lấy từ đâu |
| --- | --- |
| `VISTA_APP_ORIGIN` | `http://localhost:5173` |
| `FIREBASE_PROJECT_ID` | `vista-ci` |
| `GITHUB_CLIENT_ID` | Client ID của OAuth App Vista trong GitHub Developer settings |
| `GITHUB_CLIENT_SECRET` | Client Secret của cùng OAuth App đang dùng cho Firebase GitHub provider |
| `GITHUB_TOKEN_ENCRYPTION_KEY` | Chuỗi base64 từ lệnh tạo khóa bên dưới; giữ ổn định qua restart |
| `GOOGLE_APPLICATION_CREDENTIALS` | Đường dẫn tuyệt đối tới file service account Firebase, đặt ngoài repo |

Hai biến origin/project đã có trong mẫu; cần giữ nguyên hoặc sửa đúng môi trường. Không chỉ điền project ID rồi coi như toàn bộ backend đã cấu hình xong.

Tạo khóa trong terminal riêng, tự copy kết quả vào `.env.local`, không gửi lên chat:

```bash
node -e "process.stdout.write(require('node:crypto').randomBytes(32).toString('base64'))"
```

### 2. Firebase Admin credential

Firebase Console → project Vista CI → Project settings → Service accounts → Firebase Admin SDK → Generate new private key. Đây là thao tác Console do người dùng thực hiện. Nếu đã có credential đúng project/quyền, dùng credential đó; không cần tạo lại mỗi lần chạy.

Giữ JSON ngoài repo và điền đường dẫn vào GOOGLE_APPLICATION_CREDENTIALS. Đây là credential backend, không phải google-services.json của Android hoặc firebaseConfig của web. Không copy JSON vào source/chat. Nếu dùng cặp FIREBASE_CLIENT_EMAIL/FIREBASE_PRIVATE_KEY thay thế, phải điền đủ cả hai; xem bước21 về IAM/quyền đọc Firebase Auth và đọc/ghi Firestore.

### 3. GitHub callback và Rules

GitHub → Settings → Developer settings → OAuth Apps → Vista: giữ callback Firebase và thêm redirect URI backend:

```text
http://localhost:5173/api/github-session?action=callback
```

Giữ Expire user access tokens theo luồng hiện có. Publish Rules hiện tại từ firebase/firestore.rules nếu chưa publish bản có deny client cho githubConnections/githubOAuthRequests. Không mở Rules để sửa lỗi credential backend; Admin SDK dùng IAM.

### 4. Nạp lại cấu hình

Tại terminal Vite đang chạy, Ctrl+C rồi:

```bash
npm run dev
```

Mở đúng http://localhost:5173. Vào Tài khoản → Kết nối GitHub nếu backend chưa có connection. Đăng nhập Firebase và cấp quyền kết nối backend là hai bước khác nhau; sau lần kết nối backend thành công sẽ dùng vault/refresh, không yêu cầu cấp lại mỗi F5.

Nếu còn lỗi, gửi mã/nội dung lỗi trên UI; không gửi secret hoặc JSON credential.

## Tự cập nhật đã triển khai

- Danh sách runs tự đọc lại các trang đã tải: 15 giây khi có run chưa hoàn tất, 60 giây khi tất cả đã hoàn tất/chưa có run.
- Chi tiết đọc đúng run/attempt và job/step: 10 giây khi đang chạy, 60 giây sau hoàn tất. Giữ job đang chọn và số trang đã tải. Khi job chuyển completed, phần log tự tải.
- Không yêu cầu reload web. Đây là polling gần thời gian thực; chu kỳ tính sau khi request xong, không bảo đảm quan sát được mọi trạng thái rất ngắn giữa hai lần đọc. Chưa có webhook/SSE hoặc stream log đang chạy.
- Tab ẩn hoặc offline không tiếp tục polling. Khi quay lại/online, cập nhật lại; hủy request khi đổi feed/unmount, không chồng nhiều chu kỳ trên cùng màn hình.
- Dữ liệu cũ được giữ khi tải lỗi; thời gian cập nhật chỉ đổi khi có dữ liệu thành công. Các bộ lọc được gọi lại từ GitHub nên run có thể rời danh sách Đang chạy khi hoàn tất.
- Hiện nguyên nhân và code ngay trong khung lỗi. Lỗi setup/auth/quyền cần người dùng xử lý sẽ tạm dừng repo đó. Repo còn hợp lệ trong cùng workspace vẫn cập nhật. Bấm Làm mới để thử lại sau khi xử lý; không tự logout hoặc popup kết nối liên tục.
- Lỗi tạm thời tăng thời gian chờ theo cấp số nhân, tối đa hệ số32. Tôn trọng thời điểm thử lại GitHub; backend cũng chặn request trong cooldown của user tại process hiện tại.
- Conditional GET với ETag cho JSON GitHub. Cache trong RAM của backend tối đa100 entry, mỗi entry tối đa512KiB, hết hạn5 phút, theo UID/GitHub ID/path. Token không nằm trong cache; log gốc không được cache. Auth và quyền owner/public vẫn kiểm tra mỗi request; cache không thay vault và mất khi restart/serverless đổi instance.

## Kiểm tra và giới hạn

Web TypeScript/Vite build và ESLint thành công. Vite còn cảnh báo bundle >500kB. Không chạy unit/integration test; chưa xác minh luồng OAuth/CI bằng account thật vì backend hiện thiếu cấu hình. Không tự thay đổi Firebase/GitHub/Vercel, không restart tiến trình Vite của người dùng, không push/deploy.

Tham chiếu: [GitHub workflow runs](https://docs.github.com/en/rest/actions/workflow-runs), [GitHub REST best practices](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api), [Firebase Admin setup](https://firebase.google.com/docs/admin/setup).
