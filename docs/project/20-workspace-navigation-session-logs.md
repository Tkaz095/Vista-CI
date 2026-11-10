# 20. Workspace → CI/CD → job/log, giữ kết nối qua reload

Ngày 02/11/2026. Phạm vi lượt này: **web trước**; mobile Flutter chưa đổi. Người dùng chốt local Vite trước, deploy Vercel sau; agent để giai đoạn sau.

## Luồng được triển khai

- Workspace có nút Thêm repository ngay cạnh danh sách repo; mở danh sách GitHub trong workspace hiện tại, tìm kiếm và thêm liên kết. CRUD tên/mô tả/xóa workspace và sửa/gỡ liên kết repo giữ nguyên.
- Tên repo và nút CI/CD và log mở tab CI/CD với repo đó đã chọn, không cần tự bấm header rồi tìm lại repo.
- Giữ tab/workspace/repo đang xem trong sessionStorage, tách theo Firebase UID. Khi F5, client xác minh Firebase/profile lại rồi đọc lại history GitHub, không tạo/xóa lịch sử run.
- Chọn Chi tiết / log của một run → jobs của **đúng run attempt** → steps và outcome → chọn job để đọc log gốc. Có cập nhật job, phân trang job, retry log và tùy chọn wrap text.
- Chọn job thất bại đầu tiên nếu có trong trang đã tải; step thất bại được làm nổi. Dòng có marker `##[error]` được trích nguyên văn, không đoán nguyên nhân hay kết luận AI. Agent chưa triển khai, không có nút AI giả.

## Phiên GitHub trên web

- Trước đây chỉ có biến memory, nên F5 mất token dù Firebase vẫn đăng nhập. Hiện credential được lưu trong sessionStorage của cùng origin/tab, có UID và hạn lưu tối đa24h; API401 xóa credential và yêu cầu reconnect.
- Firebase Auth callback khôi phục credential cho đúng UID; logout/đổi tài khoản xóa token không khớp. Không ghi token vào Firestore, mã nguồn, URL hoặc console.
- SessionStorage đọc được bởi JavaScript cùng origin, không phải cookie HttpOnly/server session. Phạm vi này giữ qua F5 và restart Vite **với cùng origin/port/tab**; không cam kết giữ khi đóng tab/trình duyệt, đổi port hoặc GitHub thu hồi/hết hạn token. Browser chặn storage thì chỉ dùng memory.
- Sau khi áp dụng code mới, cần Kết nối GitHub một lần để ghi credential theo cơ chế mới. Token cũ đã mất trong RAM không thể khôi phục từ Firebase.
- Thay đổi này chỉ áp dụng web. Flutter hiện vẫn dùng token memory.

## API log

- `web/api/github-job-log.ts`: Node handler GET, nhận repo/job qua query và GitHub credential qua Authorization header.
- Chỉ gọi endpoint job/log cố định của api.github.com; xác minh job ID và status trước khi tải.
- GitHub trả redirect tới log plaintext. Chỉ chấp nhận HTTPS và hostname lưu trữ GitHub/Azure được allowlist; không forward Authorization sang URL lưu trữ, không cho client truyền URL tùy ý, không tự theo redirect tiếp.
- Timeout20s, giới hạn2MiB đầu, có header/trạng thái truncated và thông báo trong UI; log lớn có thể mất phần lỗi cuối, dùng link GitHub để xem toàn bộ.
- Cache-Control no-store/private; không ghi token/log ra log server hoặc lưu lâu dài. Render log bằng React text, không HTML.
- Quyền truy cập do GitHub kiểm tra theo token người gọi. API này không dùng Firebase Admin; không phải cơ chế đồng bộ hoặc audit của workspace. Chưa có background sync, auto rerun hoặc AI.

GitHub job/log/attempt API: https://docs.github.com/en/rest/actions/workflow-jobs

## Chạy local và Vercel

Local: từ thư mục web, dừng Vite cũ nếu cần và chạy `npm run dev`. `vite.config.ts` đăng ký chính handler này tại `/api/github-job-log`, không có server/lệnh riêng. `vite preview` chỉ phục vụ bundle nên không có API log này.

Vercel khi deploy sau: chọn Root Directory `web`, build `npm run build`, output `dist`; deploy source có thư mục `api` để Vercel tạo Function. Không chỉ upload thư mục dist. Cần người dùng thêm domain deploy vào Firebase Authorized domains theo luồng OAuth hiện có khi đến bước deploy. Chưa thao tác/deploy Vercel trong lượt này.

Node Functions tham chiếu: https://vercel.com/docs/functions/runtimes/node-js

**Firebase hiện tại không cần sửa Rules, index, collection, billing hoặc provider cho bước này.** Không cần PAT/Client Secret mới trong mã nguồn.

## Giới hạn xác minh

Đã kiểm tra TypeScript/Vite build và ESLint. Chưa chạy unit/integration tests, chưa gọi log API bằng token của người dùng hoặc xác minh UI browser/điện thoại, chưa deploy Function Vercel. Chưa commit/push.

Đối chiếu thủ công cần làm: vào workspace thêm repo → bấm repo vào đúng CI/CD → mở run failure → thấy failed step và log demo → F5/restart Vite cùng port/tab → không yêu cầu reconnect trong hạn → logout/đổi tài khoản không dùng credential cũ.
