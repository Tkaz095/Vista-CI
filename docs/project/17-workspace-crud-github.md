# Bước 17 — Workspace cá nhân và danh sách GitHub repo

Ngày 02/11/2026. Phạm vi được người dùng cho phép triển khai: tài khoản role user tự tạo/quản lý workspace, tải repo GitHub ở Tài khoản, chọn và quản lý liên kết repo trong workspace. Flutter mobile và React/Vite web dùng cùng schema/Rules. Không thay đổi Console, không commit/push/deploy trong bước này.

## Phần đã có code

- Tài khoản tự tạo workspace: tên, mô tả, có thể chọn repo ngay hoặc tạo trống để thêm sau.
- Đọc toàn bộ workspace của chính mình bằng query ownerUid; chuyển/chọn workspace; sửa tên/mô tả; xóa có xác nhận.
- Repository GitHub: lấy GET /user/repos với OAuth token của người đang đăng nhập; trang đầu tự tải khi có token, có tìm kiếm trong các trang đã tải, Tải lại, Tải thêm từng trang 100 repo.
- Nếu khôi phục phiên Firebase mà không còn token GitHub, yêu cầu Kết nối GitHub. Token GitHub chỉ ở bộ nhớ phiên, không phải Firebase ID token và không được Firebase tự refresh cho mục đích gọi API.
- Kết nối lại dùng reauthentication trên tài khoản hiện tại; tài khoản Email/Password chưa link dùng link provider. Không đổi tài khoản Vista ngầm. Cấp thêm quyền private chỉ sau thao tác chọn + bấm Kết nối GitHub.
- Trong workspace: thêm repo từ danh sách GitHub, xem link, đổi nhãn/ghi chú, gỡ liên kết có xác nhận. ID nguồn làm document ID để tránh thêm trùng; thêm lại repo đã có giữ nhãn/ghi chú cũ.
- Một repo có thể có mặt trong nhiều workspace. CRUD này chỉ thay dữ liệu Vista, không gọi API tạo/sửa/xóa repository trên GitHub.
- Header navigation trên web; bottom tabs Workspace / Repo / Tài khoản trên mobile.

## Bạn thao tác trên Firebase

1. Mở đúng project **vista-ci → Firestore Database → database (default) → Rules**.
2. Đối chiếu và publish **toàn bộ file `firebase/firestore.rules` mới nhất**. Nếu nhóm có thêm rule khác trên Console, giữ và đối chiếu các rule đó trước khi thay. Không ghép block ownerUid vào bộ memberUids cũ rồi mở quyền song song.
3. Giữ nguyên Authentication/GitHub provider, client ID/secret, database và hồ sơ user hiện tại.
4. Không cần tạo collection, document, ownerUid hoặc nhập danh sách repo thủ công. Bấm Tạo workspace trong app để tạo dữ liệu.
5. Sau khi publish, tải lại app và bấm Tải lại workspace nếu listener đang ở trạng thái lỗi. Listener đã bị từ chối không được coi là tự nối lại chỉ nhờ publish Rules.

Rules mới giữ self-get/self-create/migration user profile ở bước 15; đổi quyền workspace từ memberUids sang ownerUid. Chỉ người tạo có quyền truy cập; ownerUid/createdAt không đổi được qua client. Validate field allowlist, type, độ dài và timestamp. Repo metadata có khóa/định dạng hợp lệ; client chỉ sửa displayName/note/updatedAt.

**Rules chỉ kiểm tra quyền Firestore và cấu trúc dữ liệu, không chứng minh repo có quyền GitHub thật.** Metadata do client cung cấp không được dùng làm bằng chứng cấp quyền cho các hành động CI/GitHub tương lai; backend phải kiểm tra lại khi triển khai giai đoạn đó.

## Workspace mẫu cũ

Document cũ chỉ có memberUids không thuộc query ownerUid mới, nên sẽ không hiện. Bước này không xóa hay tự nhận quyền sở hữu các workspace đó. Có thể tạo workspace cá nhân mới từ app; nếu cần giữ dữ liệu cũ, đối chiếu chủ sở hữu và schema đầy đủ trước khi chuyển dữ liệu có chủ đích. Không sửa toàn bộ ownerUid theo tài khoản đang đăng nhập để thử.

## Bạn thao tác GitHub trong app

1. Mở **Tài khoản → Repository GitHub**.
2. Nếu phiên còn token, danh sách trang đầu tự tải. Nếu chưa có hoặc hết hạn, bấm **Kết nối GitHub**, hoàn tất Authorize trong popup/trình duyệt thiết bị.
3. Muốn có repo private: chọn ô xin quyền private trước khi kết nối. OAuth scope `repo` có quyền đọc và ghi rộng; Vista hiện chỉ gọi API đọc danh sách. Không cần tạo PAT hoặc đưa token/secret vào Firestore/chat.
4. Quyền organization/SSO và chính sách tổ chức vẫn áp dụng; danh sách chỉ gồm repo GitHub thực tế cấp phép truy cập. Bỏ chọn private không thu hồi scope đã được GitHub cấp trước đó; quản lý/thu hồi tại GitHub → Settings → Applications khi cần.
5. Tải thêm để xem các trang tiếp theo; tìm kiếm chỉ áp dụng trên repo đã tải. Chọn repo khi tạo workspace hoặc chọn workspace hiện có rồi bấm Thêm vào workspace đã chọn.

Đây là phương án OAuth nhẹ cho phạm vi hiện tại, dùng OAuth App đã cấu hình Firebase. Chưa có GitHub App/backend lưu credential. Không lưu token qua lần khởi động app; sau reload/restart có thể cần kết nối lại. Không tự xin scope repo ngay ở lần đăng nhập cơ bản.

## Cơ chế lưu và xóa

- Tạo workspace + tối đa 100 repo chọn ban đầu bằng một write batch; lỗi commit không báo tạo thành công. Có thể thêm tiếp repo sau khi tạo.
- Không giới hạn tổng repo/workspace ở 100; giới hạn 100 là số repo chọn ban đầu trong một lần tạo, không phải số repo GitHub có thể tải.
- Sửa dữ liệu kiểm tra độ dài, trim; chờ Firestore xác nhận rồi báo hoàn tất. Chờ hơn 15 giây vẫn giữ pending và báo đang đợi máy chủ, tránh kết luận write thất bại khi có thể đang đợi mạng.
- Xóa workspace: transaction chuyển status sang deleting → Rules chặn thêm/sửa repo → đọc danh sách con từ server theo nhóm 100 và xóa → xóa parent cuối cùng. Không dựa vào cache để kết luận đã xóa hết.
- Lỗi giữa chừng giữ workspace deleting và nút Tiếp tục xóa; không cho sửa hoặc thêm repo trong trạng thái đó. Người dùng chỉ xác nhận xóa workspace của chính mình; repository GitHub được giữ nguyên.
- Chặn bấm mutation lặp trong lúc pending, hủy subscription/abort fetch khi unmount, kiểm tra identity và bỏ callback khi đổi account. Không hứa hủy được request ghi đã gửi lên server.
- Timeout đọc GitHub 20 giây; 401 yêu cầu kết nối lại; 403/429 báo quyền/rate limit; lỗi Firestore phân biệt với danh sách trống.

## Chạy bản mới

Web:

```sh
cd /home/kien/FPTU/Semester-8/PRM393/Lab3-Assignment/Vista-CI/web
npm run dev
```

Mobile có plugin url_launcher mới, cần cold restart:

```sh
cd /home/kien/FPTU/Semester-8/PRM393/Lab3-Assignment/Vista-CI/mobile
flutter pub get
flutter run
```

Điện thoại thật có thể kết nối Wi-Fi bằng ADB như hướng dẫn trước. GitHub OAuth Android vẫn cần đúng SHA-1 của chứng thư ký trên Firebase; không cần đăng ký một Firebase app mới cho từng điện thoại. APK build kiểm tra ở bước này là **android-arm64**, không phải x64 của Genymotion.

## Danh sách kiểm tra thủ công sau publish

- Login GitHub mới: tự có hồ sơ user, vào màn Workspace, tự tạo workspace trống.
- Tải danh sách public/private đúng quyền, cancel kết nối và kết nối lại đúng tài khoản, tải thêm không trùng.
- Tạo workspace có chọn repo: workspace và liên kết cùng xuất hiện; không đòi UID thủ công.
- Đổi tên/mô tả workspace; thêm lại repo không xóa nhãn/ghi chú cũ; đổi nhãn/ghi chú repo; mở GitHub; gỡ repo.
- Tài khoản khác không nhìn thấy workspace hoặc truy cập trực tiếp repo của tài khoản đầu.
- Xóa workspace chứa repo; ngắt mạng giữa chừng rồi tiếp tục xóa khi có mạng; không còn liên kết con khi hoàn tất.
- Đổi account/đăng xuất trong khi tải GitHub không đưa dữ liệu của phiên cũ vào tài khoản mới.

Chưa chạy các bước Firebase/GitHub thật này trong phiên của Codex. Chưa chạy Rules Emulator/unit/integration tests vì người dùng chưa yêu cầu test trong bước này. Build/analyze không xác nhận quyền cloud đã được publish và vận hành đúng.

## File chính

- Web: features/github/githubService.ts, useGitHubRepos.ts; features/workspaces/workspaceService.ts, LiveWorkspace.tsx.
- Flutter: features/github/ (repository/viewmodel/panel); features/workspaces/ (repository/viewmodel/screen/repository_card).
- Auth hai client ghi nhận GitHub credential trong bộ nhớ khi sign-in/link; clear token khi logout; không lưu thêm field credential trong hồ sơ.
- Firebase: firestore.rules là file review/publish thủ công, không có deploy tự động.

## Ngoài phạm vi

CI/CD run/log, agent, rerun, issue/comment PR, audit, push notifications, Admin, chia sẻ/mời thành viên. Chưa triển khai backend hoặc token refresh nền.

## Kết quả local

- `flutter pub get`: thành công, dependencies/lockfile đã cập nhật.
- `flutter analyze`: không có issue.
- `flutter build apk --debug --target-platform android-arm64`: thành công. APK ở `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- Web `npm run build` và `npm run lint`: thành công với Node hệ thống 26.13.0.
- `git diff --check`: sạch whitespace.
- Cảnh báo hiện có: bundle web >500kB; FlutterFire còn cảnh báo tương thích Kotlin cho phiên bản Flutter tương lai, và SDK XML tooling lệch phiên bản. Build hiện tại vẫn thành công.
- Chưa xác nhận UI/runtime trên điện thoại hoặc luồng GitHub/Firebase thật; chưa chạy bộ test hay Rules Emulator. Đây không phải bằng chứng Rules đã publish hoặc cloud đã hoạt động đúng.
