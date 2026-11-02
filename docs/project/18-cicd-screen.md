# 18. Màn hình CI/CD riêng

Ngày 02/11/2026. Thay thế tab Repo bằng CI/CD theo yêu cầu mới nhất. Áp dụng cho web React/Vite và mobile Flutter.

## Luồng hiện tại

1. Đăng nhập GitHub, chọn workspace đã có repo.
2. Mở CI/CD trong header web hoặc bottom navigation mobile.
3. Chọn tất cả repo hoặc một repo trong workspace.
4. Mở nút Bộ lọc: nhập tên branch chính xác, chọn trạng thái/kết quả, bấm Áp dụng. Bộ lọc được gửi lên GitHub, có nút xóa bộ lọc.
5. Xem tên workflow/lần chạy, repo, branch, commit SHA rút gọn, actor, thời điểm tạo, lần thử, trạng thái và kết quả.
6. Làm mới để tải trang đầu; tải thêm để xem lịch sử cũ. Link mỗi lần chạy mở job và log trên GitHub bằng trình duyệt.

Danh sách repo để thêm vào workspace nằm tại Tài khoản; workspace vẫn giữ thao tác sửa/gỡ liên kết repo. Gỡ repo trong Vista không xóa repo GitHub.

## Dữ liệu và giới hạn

- Đọc trực tiếp `GET /repos/{owner}/{repo}/actions/runs`, dùng GitHub OAuth token có trong phiên. Chỉ gọi API GET.
- `status` tách khỏi `conclusion`: completed không đồng nghĩa thành công.
- Mỗi lượt tải tối đa 20 run/repo, tối đa 3 request đồng thời. Phân trang riêng từng repo qua Link header; không đi theo URL tùy ý mang token.
- Gộp và sắp xếp **các kết quả đã tải** theo thời điểm tạo. Đây không phải phân trang toàn cục chính xác giữa nhiều repo có tần suất chạy khác nhau.
- Không polling nền, không tự động đồng bộ khi đóng app. Mở màn hoặc đổi bộ lọc sẽ tải lại; có nút Làm mới.
- Có trạng thái loading, empty, timeout 20 giây/request, lỗi quyền, token hết hạn, rate limit, lỗi riêng từng repo. Repo lỗi không chặn repo khác; làm mới lỗi giữ dữ liệu cũ kèm thông báo.
- Web hủy request khi rời màn. Mobile bỏ callback cũ theo generation khi đổi bộ lọc/dispose, không tiếp tục xếp thêm request cũ; request HTTP đang chạy kết thúc/timeout và kết quả bị bỏ.
- Token chỉ ở memory, gắn Firebase UID; không lưu token/log/run vào Firestore hay disk. Nếu mở lại app không có token, vào Tài khoản → Kết nối GitHub.
- Chưa có chi tiết job/step/log trong Vista, PR, agent, chạy/chạy lại workflow, audit hay FCM trong mốc này.

API tham chiếu: https://docs.github.com/en/rest/actions/workflow-runs#list-workflow-runs-for-a-repository

## Firebase và quyền GitHub

**Không cần sửa Firebase Console, Rules, index hoặc thêm collection cho bước 18.** Dùng lại Auth/profile/workspace/repositories và Rules đã publish ở bước 17. Người dùng đã xác nhận tạo workspace thành công.

GitHub OAuth có thể đọc lịch sử public repo với quyền hiện có. Private repo cần scope `repo`, quyền của tài khoản trên repo và phê duyệt organization/SSO nếu tổ chức yêu cầu. Trong Tài khoản, chọn xin quyền private rồi Kết nối GitHub nếu cần. Scope `repo` là quyền rộng trên GitHub dù code của mốc này chỉ đọc.

Không triển khai webhook, backend, service account hoặc billing cho màn đọc này. Các bước cấu hình dịch vụ bên ngoài về sau do người dùng thực hiện.

## Code chính

- Web: `web/src/features/cicd/CicdScreen.tsx`, `features/github/githubService.ts`, tích hợp vào `features/workspaces/LiveWorkspace.tsx`.
- Flutter: `mobile/lib/features/cicd/cicd_screen.dart`, `cicd_view_model.dart`, API trong `features/github/github_repository.dart`, tích hợp vào WorkspaceScreen.

## Xác nhận thủ công cần làm trên tài khoản/thiết bị

- Chạy lại web/mobile đang dùng, mở CI/CD, chọn workspace có GitHub Actions.
- Đối chiếu một run với GitHub: repo, SHA, branch, status/conclusion và lần thử.
- Đổi workspace/repo/filter khi đang tải: kết quả cũ không được chen vào lựa chọn mới.
- Thử nhiều repo, không có workflow, không có kết quả lọc, private repo thiếu quyền, reconnect và tải thêm.
- Kiểm tra cuộn trên điện thoại thật, đổi tab, mở link log trên trình duyệt.

Chưa xác minh OAuth/Actions với dữ liệu thật hoặc UI trên điện thoại trong lượt triển khai này. Không chạy unit/integration/Rules emulator tests.

## Kết quả kiểm tra biên dịch

- Web: `npm run build` và `npm run lint` thành công. Vite vẫn cảnh báo bundle lớn hơn 500 kB.
- Mobile: `flutter analyze` không có lỗi; build APK debug android-arm64 thành công. FlutterFire vẫn có cảnh báo chuyển đổi Kotlin Gradle Plugin trong các bản Flutter tương lai.
- APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- Chưa commit/push/deploy các thay đổi của bước này.
