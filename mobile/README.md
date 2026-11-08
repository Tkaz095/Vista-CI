> Báo cáo CI: [xuất PDF và cấu hình Cloudinary qua Firebase Remote Config](../docs/ci-report-cloudinary.md). Không cần Firebase Storage/billing cho luồng này.

> Analytics/Crashlytics/Remote Config: xem [hướng dẫn cấu hình và demo](../docs/firebase-observability-setup.md) và [analytics plan](../docs/analytics-plan.md). Sau khi cập nhật code phải rebuild APK để thêm native plugins.

> Cập nhật phiên/MVVM 04/11/2026: xem [architecture.md](../architecture.md). App dùng Provider, theo dõi Firebase Auth để khôi phục phiên và bảo vệ toàn bộ stack màn hình. Khi mở lại app, vào Profile → Kết nối lại GitHub để lấy GitHub token trong RAM; không cần đăng xuất phiên Vista. GitHub vẫn là phương thức đăng nhập hiện hành.

# Vista CI Mobile

The Flutter client for Vista CI.

## Recommended: cloud build + Genymotion

Use the **Android APK** GitHub Actions workflow to build the app, then download the APK and drag it into Genymotion. This avoids installing another Android NDK on your workstation. See [the cloud build guide](../docs/android-cloud-build.md) for the first run, architecture selection, and signing limitations.

## Run locally (requires the Android build toolchain)

```bash
flutter pub get
flutter run
```

Firebase Core is configured for Android with project `vista-ci` and package ID `com.vista.vista_mobile`. The Android Google Services Gradle plugin reads `android/app/google-services.json`; `main.dart` initializes Firebase before starting the app.

Enable GitHub sign-in in Firebase Authentication and publish the project Firestore Rules before testing OAuth on a device. iOS Firebase setup is not included yet; use Android for this milestone.

## Theme Material 3

`lib/ui/theme/app_theme.dart` ánh xạ màu, typography, spacing và style Material từ `../docs/DESIGN.md`. `main.dart` áp dụng `AppTheme.light`; màn hình lấy kiểu chữ/màu qua `Theme.of(context)`. Input/button bo góc 8, card 12, dialog/sheet 16; control có vùng chạm tối thiểu 48. Màu chuẩn được ghi đè trên ColorScheme để giữ primary `#2563EB`, secondary `#0F766E`, tertiary `#7C3AED`.

Inter 4.1 Regular/SemiBold/Bold được đóng gói trong `assets/fonts/inter/`, khai báo ở pubspec; không tải font khi app chạy. Nguồn: https://github.com/rsms/inter/releases/tag/v4.1; giấy phép SIL OFL nằm cùng thư mục và được đưa vào assets. Geist Mono cho tên repo và log được đóng gói trong `assets/fonts/geist_mono/`, lấy từ [Google Fonts](https://github.com/google/fonts/tree/main/ofl/geistmono), kèm `OFL.txt`. Hiện dùng Material Icons; không thêm package font hoặc tải font lúc chạy.

### Widget dùng chung

Các widget nằm trong `lib/ui/widgets/` và lấy style từ theme:

- `AppButton`: primary, secondary, danger và text; nhận `icon` hoặc `iconWidget` (ví dụ ảnh GitHub), có thể truyền `style`; khóa bấm khi `isLoading` và hiển thị spinner/`loadingLabel`. Caller đặt `onPressed: null` khi cần vô hiệu hóa vì lý do khác.
- `AppTextField`: nhãn, gợi ý, `helperText`, validator, controller hoặc initialValue, callback tìm kiếm, giới hạn ký tự và nhiều dòng. Màn hình tạo/dispose controller; validator vẫn nằm ở form.
- `AppChip`: nhãn đầy đủ qua tooltip và callback bỏ chọn; không chứa logic repo.
- `AppMessage`: thông báo error (mặc định), warning, success hoặc info; icon + chữ và live region cho trình đọc màn hình. Message rỗng không hiển thị.
- `AppEmptyState`: thông báo chưa có dữ liệu/không tìm thấy; có thể truyền cả `actionLabel` và `onAction` để hiện nút hành động.
- `AppLoading`: spinner kèm skeleton card; `compact` chỉ hiển thị dòng tiến trình. Tôn trọng tùy chọn giảm chuyển động bằng biểu tượng tĩnh, không thêm thư viện animation.
- `WorkflowStatusBadge` và `WorkflowRunSummary`: dùng chung kết quả, workflow, branch, SHA và thời gian ở card repo, lịch sử và chi tiết run. `status` và `conclusion` được đọc riêng; trạng thái chưa rõ không được coi là thành công.
- `WorkflowLogPanel`: terminal nền đen theo GitHub, chữ Geist Mono, luôn ngắt dòng, có số dòng và sao chép log gốc. Job và nhóm `##[group]` thu gọn ngay trong terminal, không có dropdown chọn job hoặc danh sách job/step riêng bên ngoài. Dòng có marker `[ERROR]`, `##[error]` hoặc `[FAIL]` được nhấn màu đỏ, không coi đây là phân tích AI. Theme tối chỉ áp dụng trong terminal.
- `AppHeader`: header chính có logo `assets/logo/logo-on-header.png`, dùng ở Login và các tab Home. `showNotifications: false` ẩn chuông ở Login/màn lỗi khởi tạo. Home hiện chuông disabled với tooltip chưa triển khai; chỉ bật khi có callback thật, không hiển thị dấu unread giả. `actions` nhận các nút bổ sung của màn hình.
- `AppStackHeader`: tiêu đề, nút quay lại và danh sách `actions` cho màn stack. Project Detail dùng menu ba chấm chứa Chỉnh sửa/Xóa; khóa menu và nút Back khi đang xử lý ghi/xóa, cùng với `PopScope` của màn hình.
- `AppBottomTab`: thanh Material 3 với ba tab Projects, Action và Profile; nhận `selectedTab` và `onSelected`. Home giữ tab hiện tại bằng state của View, không thêm ViewModel cho việc đổi tab.

Ví dụ trong màn hình:

```dart
AppButton(
  label: 'Lưu project',
  loadingLabel: 'Đang lưu…',
  isLoading: model.saving,
  icon: Icons.save_outlined,
  onPressed: _saveProject,
)
```

Đã dùng các widget này ở Login, Home, danh sách/chi tiết/form project, dialog xác nhận xóa và màn lỗi khởi tạo Firebase. Widget chỉ nhận dữ liệu/callback; ViewModel vẫn quản lý trạng thái và gọi repository. `CheckboxListTile`, `ListTile`, `AlertDialog` và progress indicator của vùng dữ liệu vẫn dùng Material trực tiếp. Không thêm package mới.

Home dùng `IndexedStack` để giữ danh sách, từ khóa tìm kiếm và vị trí cuộn khi đổi tab. Projects giữ nguyên CRUD hiện tại; `ActionView` chỉ hiển thị thông báo tính năng workflow sẽ được bổ sung sau. `ProfileView` nhận hồ sơ thật và callback đăng xuất từ Home; trạng thái đăng xuất vẫn thuộc `AuthViewModel`. Header và bottom tab nằm chung ở Home, không lặp lại trong từng tab. Nút Back hệ thống từ Action/Profile trở về Projects. Màn chi tiết/form được push bằng `Navigator` lên stack, dùng `AppStackHeader` và không hiện bottom tab; quay lại vẫn giữ tab Projects.

### Mẫu màn hình

Giao diện tham khảo `figma/screens/` và tiếp tục dùng token từ DESIGN:

- Login: logo Vista, nội dung căn giữa, nút GitHub màu tối; nội dung cuộn được khi màn hình thấp hoặc chữ lớn.
- Dashboard: tìm theo tên/mô tả project, số kết quả, nút thêm và card project. Repo mặc định thu gọn; bấm mũi tên để xem/ẩn toàn bộ repo trong project. Bấm tên/card vẫn mở chi tiết. Trạng thái xổ xuống gắn với ID project để không bị chuyển sang project khác khi danh sách đổi thứ tự.
- Form tạo/sửa: logo, tên/mô tả, chip repo đã chọn và nút mở `SelectRepositoriesView`. Màn chọn repo dùng hàng checkbox bên phải, nền xanh cho repo được chọn và nút xác nhận cố định theo mẫu. Quay lại mà chưa xác nhận sẽ khôi phục lựa chọn trước đó. Nút Lưu của form tránh bàn phím; giữ lựa chọn và nội dung khi lỗi.
- Chi tiết: tên project và menu ba chấm trên stack header; bỏ card tổng quan đếm repo ở đầu màn. Mô tả giữ dưới header nếu có; số repo chỉ xuất hiện trong tiêu đề “Repository đang theo dõi”. Card repo theo bố cục tên/branch/trạng thái, tiêu đề run, workflow/attempt và SHA/thời gian. Sửa/xóa nằm trong menu, xóa vẫn có xác nhận. Màu, Inter, gutter 24, padding card 20 và bo góc 12 dùng token DESIGN.
- Profile: avatar chữ cái, tên/email từ hồ sơ đang đăng nhập, phương thức GitHub và nút đăng xuất. Chưa thêm chỉnh sửa hồ sơ hoặc kết nối backend.

`select-repositories.png` và `workflow-run-detail.png` hiện là mẫu cho màn chọn repository và terminal trong chi tiết run. Dữ liệu repo, run và log đều lấy từ nguồn thật; phần AI/phân tích/comment/rerun trong ảnh chưa có dịch vụ nên chưa thêm vào luồng.


## Luồng auth đang chạy

Phạm vi hiện tại: đăng nhập GitHub, tạo hồ sơ Firestore nếu chưa có và mở Home với danh sách dự án GitHub. `lib/features/` được giữ nguyên, chưa nối vào luồng này.

```text
AuthView → AuthViewModel → AuthRepository
                              ├── FirebaseAuthService
                              └── FirestoreProfileService
```

Đọc code theo thứ tự:

1. `lib/main.dart`: khởi tạo Firebase và tạo ViewModel.
2. `lib/ui/auth/auth_view.dart`: hiển thị Login khi chưa có profile, Home khi đã có profile.
3. `lib/ui/auth/auth_view_model.dart`: quản lý `profile`, `busy` và thông báo lỗi bằng `ChangeNotifier`.
4. `lib/data/repositories/auth_repository.dart`: chạy đăng nhập GitHub, tạo dữ liệu hồ sơ ban đầu, lấy hoặc tạo hồ sơ và trả `UserProfile`.
5. `lib/data/services/firebase_auth_service.dart`: gọi SDK đăng nhập GitHub, giữ GitHub access token trong bộ nhớ và xóa token khi logout thành công.
6. `lib/data/services/firestore_profile_service.dart`: dùng transaction để trả hồ sơ đã có hoặc tạo `users/{uid}`. Hồ sơ hiện có được giữ nguyên.
7. `lib/data/models/`: identity, profile và dữ liệu tạo profile; role được lưu dưới dạng chuỗi.
8. `lib/ui/home/home_view.dart`: tạo và hủy ProjectsViewModel theo phiên Home, hiển thị user và nút logout.

### Quy trình đăng nhập

```text
Bấm GitHub → busy = true → Firebase xác thực
  → đọc users/{uid}
  → chưa có: tạo displayName, role user, isActive true
  → trả UserProfile → busy = false → mở Home
```

Nếu login hoặc ghi Firestore thất bại, màn hình Login hiển thị lỗi và cho phép bấm lại. Đăng xuất thành công đặt `profile = null` để trở về Login.

Repo và service khởi tạo dependency trực tiếp. App bắt đầu ở Login mỗi lần mở; phần tự khôi phục giao diện theo phiên, theo dõi profile realtime và chính sách quyền sẽ triển khai sau. Luồng này giữ nguyên role/isActive của hồ sơ đã có.

### Kiểm tra

```bash
flutter analyze
flutter test
flutter build apk --debug
```

Test model và giao diện dùng repository giả trong thư mục test; production service không có constructor hoặc nhánh dành riêng cho test. OAuth và Firestore thực tế cần được kiểm tra trên thiết bị với Firebase project hiện tại.

## Quản lý project

Home hiển thị project của tài khoản Firebase hiện tại. User có thể tạo project rỗng hoặc chọn repo GitHub, xem chi tiết, sửa tên/mô tả/danh sách repo và xóa project. Một repo có thể nằm trong nhiều project; mỗi project không chứa ID repo trùng nhau. Xóa project chỉ xóa nhóm quản lý trong Vista.

```text
ProjectsView / ProjectFormView → ProjectsViewModel → ProjectRepository
                                                      ├── FirestoreProjectService
                                                      └── GitHubService
```

`data/models/project.dart` chứa Project và ProjectRepo; `FirestoreProjectService` lưu cấu hình project; `ProjectFormView` giữ controller của form. ViewModel quản lý hành vi/trạng thái; View điều hướng và xác nhận xóa. Repository kiểm tra dữ liệu trước khi ghi. Các service khởi tạo trực tiếp, không có constructor dành riêng cho test.

### Dữ liệu Firestore

```text
users/{Firebase uid}/projects/{Firestore-generated projectId}
  name: string (1–100 ký tự sau trim)
  description: string (0–1000 ký tự sau trim)
  repositories: [{ id: GitHub integer ID, fullName: owner/repo }, ...]
  createdAt: server timestamp
  updatedAt: server timestamp
```

Giới hạn 50 repo/project để document gọn. `ProjectRepo` chỉ lưu ID và tên để hiển thị; không lưu OAuth token, log hoặc dữ liệu CI. Tên repo là ảnh chụp tại lúc chọn, không phải bằng chứng quyền GitHub. Khi đọc dữ liệu GitHub/CI, quyền truy cập vẫn do GitHub kiểm tra. Sửa danh sách repo ghi lại mảng trong một document; với đồ án này, lần lưu sau cùng sẽ có hiệu lực nếu cùng project được sửa trên hai thiết bị.

`ProjectPreferencesService` được tạm ngắt hoàn toàn khỏi repository và ViewModel. File và dữ liệu SharedPreferences cũ vẫn giữ nguyên, không tự di chuyển vào project.

### Luồng thao tác

1. Home tải project từ Firestore theo UID, độc lập với token/kết nối GitHub.
2. Mở **Chọn repository** mới tải repo GitHub. Kéo xuống trong màn chọn để cập nhật, tìm kiếm và xác nhận lựa chọn. Repo đã lưu vẫn giữ trong bản nháp nếu GitHub lỗi hoặc không trả lại repo đó; user có thể bỏ chọn bằng chip trong form. Làm mới không xóa tên/mô tả hoặc lựa chọn đang chỉnh sửa.
3. Bấm Lưu: kiểm tra tên, mô tả, số lượng/ID/tên repo, sau đó tạo hoặc cập nhật Firestore. UI chặn bấm lưu trùng.
4. Lưu lỗi: form, tên và lựa chọn được giữ để thử lại. Lưu thành công: tải lại danh sách và đóng form. Nếu chỉ bước tải lại lỗi, danh sách báo lỗi; không yêu cầu user tạo lại project đã lưu.
5. Xóa cần xác nhận. Xóa lỗi giữ project; thành công bỏ project khỏi danh sách.

### Rules cần được publish

File `../firebase/firestore.rules` đã bổ sung quyền tại `users/{uid}/projects/{projectId}`. Rules chỉ cho chính user có profile `role=user`, `isActive=true` truy cập; kiểm tra danh sách field, độ dài tên/mô tả, kiểu list/tối đa 50 repo và server timestamps. Kiểu/ID từng phần tử repo được kiểm tra tại repository; dữ liệu này chỉ là lựa chọn cá nhân, không cấp quyền GitHub. Rules profile/workspace trước đó được giữ nguyên.

**Publish toàn bộ file Rules qua Firebase Console → Firestore Database → Rules trước khi thử trên tài khoản thật.** Sửa file local không cập nhật Rules đã triển khai. App sẽ báo lỗi quyền nếu project đang dùng Rules cũ. Chưa deploy Rules lên Firebase trong lần sửa này.

### Quyền GitHub

Luồng auth vẫn xin scope OAuth `repo`, lấy token từ `result.credential?.accessToken` và chỉ giữ token trong bộ nhớ. Scope này gồm quyền đọc và ghi; tính năng hiện chỉ đọc danh sách repo và GitHub Actions. GitHubService tải đủ các trang repo với `visibility=all`, `affiliation=owner,collaborator,organization_member`. Dữ liệu thực tế còn phụ thuộc scope đã cấp và chính sách organization/SSO.

Test tự động kiểm tra model, input không hợp lệ, CRUD/ViewModel/UI, lỗi GitHub/Firestore, thao tác trùng, hủy ViewModel và màn hình nhỏ. Luồng OAuth và SDK Firestore trên Android vẫn cần thử với project Firebase hiện tại sau khi publish Rules.

## GitHub Actions theo project

```text
Projects → ProjectDetailView → RepositoryRunsView → WorkflowRunDetailView
                  ↓                    ↓                    ↓
         ProjectDetailViewModel  RepositoryRunsViewModel  WorkflowRunViewModel
                  └────────────────────┼────────────────────┘
                            GitHubActionsRepository
                                      ↓
                                 GitHubService
```

- Project Detail đọc lần chạy gần nhất của 5 repo mỗi nhóm; bấm **Xem thêm repository** để tải nhóm tiếp theo. Một repo lỗi không chặn repo khác. Kết quả là của lần chạy gần nhất, không phải kết luận chung của toàn bộ CI trong repo.
- Repository Runs hiển thị thông tin repo/project, bộ lọc Tất cả/Thành công/Thất bại/Đang chạy và lịch sử chia theo ngày địa phương. Bộ lọc gửi `status` lên GitHub, tải 20 run/trang; **Xem thêm lần chạy** giữ bộ lọc theo tín hiệu phân trang. Đổi bộ lọc bắt đầu từ trang 1 và bỏ qua phản hồi của bộ lọc cũ. Lỗi làm mới/tải thêm giữ dữ liệu cùng bộ lọc; mất quyền xóa dữ liệu. Bấm tên project để quay lại; icon trên header mở repo GitHub. Không lấy `updated_at` làm thời điểm hoàn tất để tính thời lượng giả.
- Run Detail đọc đúng `runId` + `attempt` đã chọn. Các job nằm trong terminal dạng mục thu gọn; ban đầu mở/tải job lỗi đầu tiên hoặc job đầu nếu không có lỗi. Mở job khác mới tải log của job đó. Log, lỗi và tiến trình được giữ riêng theo ID job; thu gọn rồi mở lại không tải lại dữ liệu đã có.
- Log luôn ngắt dòng, có spinner riêng, số dòng, chọn chữ và sao chép. Nhóm `##[group]`/`##[endgroup]` được lấy từ nội dung GitHub, giữ thứ tự và số dòng nguồn; nhóm lỗi mở sẵn. Không tự suy luận ranh giới step bằng timestamp hoặc ghép tên step vào log. Nhóm lồng nhau hiển thị đường dẫn tên nhóm và giữ đúng thứ tự nội dung.
- **Mở log** mở terminal lớn hơn, dùng cùng ViewModel. Kéo xuống làm mới metadata và các log đã tải, theo nhóm tối đa ba yêu cầu; giữ log cũ trong lúc cập nhật. **Mở run trên GitHub** mở nguồn đầy đủ. Không có tùy chọn tắt ngắt dòng hoặc cuộn ngang.
- Preview log giới hạn tải 256 KiB và hiển thị tối đa 1.000 dòng đầu, có thông báo khi bị giới hạn. ANSI/control characters được loại bỏ để đọc dễ; HTML và command trong log chỉ là văn bản, không thực thi. Log chưa tạo/đã hết hạn, mất quyền, lỗi tải link tạm và timeout có thông báo riêng.
- Lần tải đầu có spinner và skeleton. Dữ liệu từng nhóm/trang chỉ hiện sau khi phần tải tương ứng hoàn tất; làm mới giữ dữ liệu cũ kèm tiến trình. Không có nút tải lại/đồng bộ: kéo xuống ở danh sách project, chi tiết project, form/chọn repo, lịch sử, chi tiết run và terminal mở rộng. Các nút **Tải thêm** vẫn giữ để phân trang. Chưa có polling hoặc webhook.
- `ProjectDetailView` được tách khỏi `projects_view.dart`; mỗi màn mới sở hữu và dispose ViewModel riêng. Khi sửa repo trong project, kết quả CI cũ của lựa chọn trước không được áp vào lựa chọn mới. Request về sau khi rời màn hình được bỏ qua.

Endpoint đọc từ GitHub REST API:

```text
GET /repos/{owner}/{repo}/actions/runs
GET /repos/{owner}/{repo}/actions/runs/{run_id}/attempts/{attempt_number}
GET /repos/{owner}/{repo}/actions/runs/{run_id}/attempts/{attempt_number}/jobs
GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs
```

Nguồn contract: [workflow runs](https://docs.github.com/en/rest/actions/workflow-runs), [workflow jobs và log](https://docs.github.com/en/rest/actions/workflow-jobs). API version giữ `2026-03-10` theo service hiện tại. Request API luôn tạo từ host `api.github.com`. Endpoint log trả URL HTTPS tạm qua 302; app tải URL đó bằng request mới không có token/cookie, không tự theo redirect tiếp. Không gửi token theo URL phân trang. HTTP 401 yêu cầu đăng nhập GitHub lại; lỗi quyền/không tìm thấy được phân biệt với lịch sử rỗng. Giới hạn API tôn trọng `Retry-After`/`X-RateLimit-Reset` và chặn yêu cầu tiếp theo trong cùng phiên xem tới khi hết thời gian chờ.

Firestore tiếp tục chỉ lưu cấu hình project/repo, không thêm collection run/job hoặc lưu token. GitHub Actions không cần thay Rules. ViewModel giữ dữ liệu trong phiên xem, không thêm cache đĩa hoặc backend.

`test/github_actions_test.dart` kiểm tra endpoint/header, pagination, attempt, lỗi quyền/giới hạn mạng, batch loading, refresh, dispose và điều hướng Project → Repo → Run. `test/workflow_logs_test.dart` kiểm tra redirect không kèm token, log lớn/hết hạn, cache riêng theo job, phân nhóm log, sao chép, terminal tối với chữ lớn, thu gọn/mở lại job, kéo làm mới và xác nhận/hủy chọn repo. Test project kiểm tra xổ/thu repo rồi mở chi tiết. Đây là kiểm tra với response mô phỏng; OAuth, quyền repo/organization và log thật cần thử trên thiết bị đã đăng nhập GitHub.

## Các tính năng tiếp theo

Chạy lại/hủy workflow, phân tích AI, lưu báo cáo và các dịch vụ Firebase tiếp theo sẽ được bổ sung sau. Tab Action tổng hợp vẫn là màn tạm; luồng xem CI hiện bắt đầu từ từng project. Code hiện có trong `lib/features/` được giữ nguyên để tham khảo ở giai đoạn đó.

Tài liệu backend chung với web: `../docs/project/22-complete-workspace-cicd-mobile.md`.

## Phân tích lỗi CI và thao tác GitHub

Trong chi tiết một run đã hoàn tất và có job lỗi, bấm **Phân tích lỗi với Gemini**. App lấy lại đúng run/attempt và log, che các mẫu thông tin nhạy cảm phổ biến, rồi hiện trích đoạn để user xem trước. Chỉ sau khi bấm **Gửi để phân tích** mới gọi Gemini qua Firebase AI Logic. Không có agent tự chạy lệnh hoặc tự ghi lên GitHub.

```text
WorkflowRunDetailView / CiCommentView
  → WorkflowRunViewModel
      → GitHubActionsRepository → GitHubService
      → CiAnalysisRepository
          → GeminiAnalysisService → Firebase AI Logic → Gemini
          → FirestoreCiAnalysisService → Firestore
```

Các file mới:

- `data/models/ci_analysis.dart`: input đã che thông tin nhạy cảm, kết quả AI, bằng chứng và mẫu comment. Giữ số dòng nguồn khi che nội dung.
- `data/services/gemini_analysis_service.dart`: khởi tạo FirebaseApp AI riêng và App Check khi cần, gọi Gemini 3.5 Flash-Lite với system instruction và JSON schema. Cấu hình nằm trong `lib/firebase_ai_options.dart`. Log là dữ liệu, không phải chỉ dẫn/tool; không gửi GitHub token cho model.
- `data/services/firestore_ci_analysis_service.dart`: đọc/ghi phân tích theo Firebase UID của phiên hiện tại, không chuyển dữ liệu sang UID khác khi tài khoản đổi.
- `data/repositories/ci_analysis_repository.dart`: chọn log job lỗi, kiểm tra cấu trúc kết quả và đối chiếu job/dòng/trích dẫn trước khi dùng.
- `ui/projects/ci_comment_view.dart`: chọn PR liên quan, sửa bản nháp và xem kết quả gửi. Tái sử dụng ViewModel của run, không gọi Gemini lần nữa.

### Giới hạn và dữ liệu lưu

- Chọn tối đa 5 job lỗi (`failure`/`timed_out`). Mỗi log tải tối đa 4 MiB trong 20 giây, độc lập với preview terminal 256 KiB/1.000 dòng. Nếu vượt giới hạn tải thì dữ liệu chưa bao gồm phần cuối thật của file; app đánh dấu thiếu dữ liệu, không coi đó là log đầy đủ.
- Mỗi job gửi tối đa 80 dòng/12.000 ký tự, ưu tiên phần cuối và ngữ cảnh quanh thông báo lỗi; mỗi dòng tối đa 300 ký tự. Metadata cho biết có log/job bị bỏ bớt. Model không đọc source code và không thể khẳng định nguyên nhân chỉ từ mọi loại log.
- Che token GitHub, Bearer, một số API/access key, key riêng, URL có credentials và các biến token/password/secret phổ biến. Đây là lọc theo mẫu, không bảo đảm loại hết mọi thông tin nhạy cảm; user cần kiểm tra preview. Log gốc không lưu vào Firestore.
- Kết quả gồm tóm tắt, nguyên nhân có khả năng, hướng xử lý, bằng chứng, thông tin còn thiếu; gắn repo ID/run ID/attempt/SHA bằng code app. Bằng chứng AI không khớp dòng đã gửi sẽ bị từ chối.
- Lưu tại `users/{uid}/ciAnalyses/{repoId_runId_attempt}`. Có `repoId`, `runId`, `attempt`, `sha`, `summary`, `probableCause`, `suggestions`, `evidence`, `missingContext`, `incomplete`, `model`, `promptVersion`, `createdAt` (UTC ISO string) và `savedAt` (server timestamp).
- Chỉ đọc kết quả sau khi GitHub đã cho đọc metadata của run/attempt. Đọc Firestore từ server để kiểm tra quyền; lỗi đọc không tự dùng cache đĩa. Bản đã có trên màn hình vẫn giữ khi lỗi mạng tạm thời. Lưu thất bại không làm mất kết quả vừa phân tích, app báo chưa lưu.
- Đây là ghi chú AI do client tạo trong không gian của user, không phải dữ liệu audit do backend xác nhận. Kết quả gắn attempt cũ không được chuyển sang attempt mới. Bản đã lưu giữ model/prompt version gốc; các yêu cầu mới mặc định dùng Gemini 3.5 Flash-Lite.

### Rerun và comment PR

Menu **Thao tác CI** trên header chứa:

- **Chạy lại các job lỗi**: gọi `POST /repos/{owner}/{repo}/actions/runs/{runId}/rerun-failed-jobs`.
- **Chạy lại toàn bộ workflow**: gọi `POST /repos/{owner}/{repo}/actions/runs/{runId}/rerun`.
- **Xem attempt mới nhất**: đọc lại metadata mới và chuyển attempt nếu đã thay đổi.
- **Soạn comment PR**: xuất hiện khi có phân tích; dùng kết quả đã có để tạo bản nháp chỉnh sửa được.
- **Mở run trên GitHub**: mở đúng attempt đang xem.

Rerun cần xác nhận và kiểm tra lại attempt/SHA/trạng thái trước khi gửi. GitHub dùng commit cũ, không lấy commit mới vừa push; job phụ thuộc có thể chạy lại. App chỉ thông báo yêu cầu được chấp nhận, không coi CI đã thành công. Sau POST, kiểm tra attempt một lần; nếu chưa có, kéo xuống để kiểm tra tiếp. Khi chuyển attempt, xóa log/phân tích trên màn hình và tải dữ liệu đúng attempt mới, bản cũ vẫn giữ trong Firestore. Không có polling nền.

PR được tìm từ quan hệ của run, hoặc PR liên quan đến commit khi dữ liệu đó trống; không đoán bằng tên branch. Chỉ liệt kê PR đang mở. Trước khi gửi comment, kiểm tra PR vẫn liên quan/đang mở và head SHA chưa đổi so với lúc chọn. Run dùng merge SHA có thể khác head SHA của PR; UI hiển thị lời nhắc đối chiếu. Gửi comment hội thoại bằng Issues Comments API, không tạo review comment theo dòng source.

Comment đăng bằng tài khoản GitHub hiện tại; model không đăng dưới danh nghĩa bot riêng. App kiểm tra marker theo repo/run/attempt trong comment cũ (tối đa 500 comment, không đủ thì dừng), giữ ID/URL nhận được và chặn gửi trùng trên màn hình. Đây là kiểm tra best effort, không phải bảo đảm exactly-once giữa nhiều thiết bị vì GitHub không cung cấp transaction chung với app. Timeout/mất kết nối/5xx khi POST được coi là kết quả chưa rõ: không tự gửi lại; với comment chỉ cho kiểm tra bản đã gửi, với rerun chờ kiểm tra attempt/GitHub. Scope OAuth `repo` hiện có không thay thế quyền repository/organization/SSO; GitHub quyết định thao tác được phép.

### Cấu hình Firebase trước khi thử thật

1. Project AI thực tế là **`vista-ai-28543` (Vista-AI)**, app Android `com.vista.vista_mobile`. Trong project này, mở **AI Logic → Get started → Gemini Developer API**. Giữ gói **Spark**, không liên kết billing để dùng free tier; việc code trỏ sang project này không tự đổi gói/quota. Không đặt Gemini API key trong Dart, `.env` hoặc Firestore.
2. Mặc định model **`gemini-3.5-flash-lite`**. Có thể đổi khi build: `flutter run --dart-define=CI_GEMINI_MODEL=<model-supported-by-your-project>`. Model/quota/billing phụ thuộc project AI. Đối chiếu [danh sách model hỗ trợ](https://firebase.google.com/docs/ai-logic/models) và quota của project trong AI Studio.
3. Chạy `flutter run`, mở CI lỗi và bấm phân tích. Lần đầu, `GeminiAnalysisService` tạo FirebaseApp tên **`vista-ai`** từ **`lib/firebase_ai_options.dart`**, kích hoạt App Check cho chính app này rồi gọi Gemini với limited-use token. Debug dùng debug provider; đăng ký token được in trong log tại **project `vista-ai-28543` → App Check → app Android → Manage debug tokens**. Token đã đăng ký ở project chính chưa cấp quyền cho project AI. Đảm bảo AI Logic Enforced. Release Android dùng Play Integrity. Không commit debug token hoặc tắt enforcement để sửa lỗi cấu hình. Xem [App Check Flutter](https://firebase.google.com/docs/app-check/flutter/default-providers).
4. Cấu hình AI hiện hỗ trợ **Android**; nền tảng khác báo chưa có cấu hình AI, các luồng còn lại tiếp tục dùng cấu hình riêng của project chính. Lỗi khởi tạo AI có thể thử lại khi bấm phân tích, không chặn màn Login/Home. Các yêu cầu đồng thời dùng chung một lần khởi tạo FirebaseApp và App Check.
5. **Project chính `vista-ci`** vẫn là FirebaseApp mặc định: Authentication, Firestore và dữ liệu phân tích sử dụng UID/project này. `lib/firebase_options.dart`, `android/app/google-services.json` và `firebase.json` giữ cấu hình chính; không thay chúng bằng file của project AI. File `firebase_ai_options.dart` chỉ chứa Firebase app configuration, không chứa Gemini API key hay App Check token.
6. Publish rule dưới đây trong **project chính `vista-ci`**, bên trong `match /users/{userId}`, ngang hàng với `match /projects/{projectId}`. Nó dùng hàm `activeUser()` đã có. Giữ các rule khác. Không cần tạo Firestore/Authentication ở project AI chỉ để gọi Gemini. Chưa publish hoặc thay đổi file Rules ngoài mobile trong lần triển khai này.

```rules
match /ciAnalyses/{analysisId} {
  function isOwner() {
    return activeUser() && request.auth.uid == userId;
  }
  function validAnalysis() {
    let d = request.resource.data;
    return d.keys().hasAll([
        'repoId', 'runId', 'attempt', 'sha', 'summary', 'probableCause',
        'suggestions', 'evidence', 'missingContext', 'incomplete',
        'model', 'promptVersion', 'createdAt', 'savedAt'
      ])
      && d.keys().hasOnly([
        'repoId', 'runId', 'attempt', 'sha', 'summary', 'probableCause',
        'suggestions', 'evidence', 'missingContext', 'incomplete',
        'model', 'promptVersion', 'createdAt', 'savedAt'
      ])
      && analysisId.matches('^[1-9][0-9]*_[1-9][0-9]*_[1-9][0-9]*$')
      && d.repoId is int && d.repoId > 0
      && d.runId is int && d.runId > 0
      && d.attempt is int && d.attempt > 0
      && d.sha is string && d.sha.matches('^[a-fA-F0-9]{7,64}$')
      && d.summary is string && d.summary.size() > 0 && d.summary.size() <= 4000
      && d.probableCause is string && d.probableCause.size() > 0 && d.probableCause.size() <= 4000
      && d.suggestions is list && d.suggestions.size() <= 10
      && d.evidence is list && d.evidence.size() <= 10
      && d.missingContext is list && d.missingContext.size() <= 10
      && d.incomplete is bool
      && d.model is string && d.model.size() > 0 && d.model.size() <= 100
      && d.promptVersion is int && d.promptVersion > 0
      && d.createdAt is string && d.createdAt.size() <= 40
      && d.savedAt == request.time;
  }
  allow read, delete: if isOwner();
  allow create, update: if isOwner() && validAnalysis();
}
```

Kiểm tra sau cấu hình: đăng nhập GitHub, mở CI lỗi, xem preview, phân tích, quay lại mở cùng attempt để kiểm tra Firestore, thử rerun với repo có quyền ghi và thử gửi comment lên PR thử nghiệm. Các test tự động dùng HTTP giả/repository giả để kiểm tra dữ liệu, metadata, side effect, lỗi và UI; không tiêu quota Gemini, không chạy CI thật và không đăng comment thật.


### Khi phân tích CI báo lỗi

Cảnh báo đọc/lưu phân tích là lỗi Firestore riêng với lỗi gọi Gemini. Đăng ký App Check debug token không cấp quyền đọc/ghi Firestore; phải Publish Rules `ciAnalyses` ở trên.

| Thông báo/mã | Bước kiểm tra |
| --- | --- |
| `permission-denied`, Publish Rules `ciAnalyses` | Kiểm tra Rules đã publish và role/isActive của hồ sơ Firebase. |
| `AI_APP_CHECK` | Debug token đúng app/thiết bị, AI Logic Enforced; bản app này dùng limited-use token để hỗ trợ replay protection. |
| `AI_SETUP` | Hoàn tất Get started với Gemini Developer API cho đúng project; cấu hình mới có thể cần vài phút. |
| `AI_API_RESTRICTION` | API restrictions của Firebase API key phải cho phép `firebasevertexai.googleapis.com`; không thêm Gemini API key vào Dart. |
| `AI_MODEL` | Model không có hoặc project chưa được quyền dùng. Đối chiếu danh sách model và `CI_GEMINI_MODEL`. |
| `AI_QUOTA` / `AI_BILLING` | Kiểm tra quota/billing của model/project. Với Blaze, import project vào Google AI Studio → Projects để kiểm tra bước billing còn thiếu và số dư prepaid nếu được yêu cầu; app giữ lý do billing gốc đã che credentials. |
| `AI_SERVER` | Lý do dịch vụ được rút gọn và che mẫu credentials, dùng để xác định lỗi chưa có loại riêng. |

Không in GitHub token, App Check token, prompt hoặc phản hồi AI đầy đủ vào log để chẩn đoán. Chưa xác minh dịch vụ thật chỉ từ các test tự động; khi gặp lỗi cần giữ đúng mã/thông báo của lần gọi thực tế.

### FCM và Notification Center

Phạm vi code nằm hoàn toàn trong mobile/: nhận FCM, quyền Android 13+, đăng ký FID theo UID, Notification Center/đã đọc, notification hệ thống cả foreground và nhấn mở đúng workflow run/attempt. Nguồn gửi tự động nằm trong `mobile/functions/`: Firebase Cloud Functions nhận GitHub `workflow_run`, lọc người nhận/tùy chọn, lưu lịch sử rồi gửi FCM. Xem [cấu hình, deploy và kiểm thử](functions/README.md). Không dùng backend web, không đưa service-account private key vào Flutter; không cần Python.

Luồng MVVM: View → NotificationViewModel → MessagingSource / NotificationHistory / NotificationCache / SystemNotifications. Service bọc SDK Firebase và MethodChannel Android; View không gọi Firebase SDK. Phiên đăng nhập xác minh profile trước khi bind UID. Đổi tài khoản/mất quyền dọn state, route và khay thông báo. GitHub token chỉ ở RAM: sau cold start có thể phải kết nối lại rồi app tiếp tục đúng run/attempt.

Trong Repository → Lịch sử chạy → Thông báo CI có failures (mặc định), results, all, off. Tùy chọn được lưu vào Firestore và được Cloud Function áp dụng sau khi deploy và cấu hình webhook. Flutter không tự polling GitHub hoặc gửi FCM khi app đã đóng. Không thêm Remote Config key mới.

#### Cấu hình và thử nhận push

1. Dừng app, chạy lại flutter run để cập nhật Android native.
2. Project Firebase chính vista-ci, package com.vista.vista_mobile; giữ cấu hình Firebase và App Check như hiện tại. Không dùng project AI.
3. Đăng nhập → chuông → Bật thông báo, cấp quyền Android 13+. Thiết bị/emulator cần Google Play services. Nếu Android không hỏi lại, bật tại Settings → Apps → Vista CI → Notifications.
4. Publish các Rules notifications/devices/ciSubscriptions bên dưới trên Firebase Console, giữ nguyên Rules khác. File firebase/firestore.rules ở ngoài mobile không được sửa trong phạm vi này.
5. Trong Notification Center của bản debug, sao chép FCM Installation ID. SDK firebase_messaging 17 dùng register/onRegistered/unregister; không trộn với API token deprecated.
6. Dùng công cụ gửi thử của Firebase Console có hỗ trợ FID. Nếu giao diện chỉ nhận legacy registration token, nguồn gửi bên ngoài cần dùng FCM/Admin SDK hỗ trợ FID; không thêm private key vào app. Khi soạn notification, thêm custom data như mẫu bên dưới, dùng UID và repo/run/attempt thật.
7. Thử app foreground, background và gạt khỏi recent apps, rồi nhấn thông báo để đối chiếu run/attempt. Không dùng Android Settings Force stop. Khóa màn hình có thể nhận, tắt nguồn không nhận ngay.

```json
{
  "notification_id": "run_123456_987654321_1_started",
  "uid": "FIREBASE_UID",
  "type": "workflow_run",
  "repo_id": "123456",
  "repo_full_name": "owner/repository",
  "run_id": "987654321",
  "attempt": "1",
  "phase": "started"
}
```

Notification payload cần title/body để Android hiển thị ở nền. Tin thiếu UID bị bỏ qua; target sai không được dùng để mở URL tùy ý. Gửi completed với ID riêng có hậu tố _completed và phase completed để giữ hai mốc lịch sử. Foreground dùng tag ci_{repoId}_{runId}_{attempt}, ID 0; để thay cùng một thẻ khi background, phía gửi cũng phải đặt Android notification tag tương ứng. Chỉ đặt custom data trong Console không tự cấu hình Android tag.

App lưu những tin callback nhận được theo UID: cache SharedPreferencesAsync và Firestore notifications. Có thể giữ tối đa 200 mục trong cache; Firestore tải 100 mục mới nhất. **Lịch sử đầy đủ cho tin bị gạt đi khi app đã đóng cần phía gửi ghi inbox trước khi push**; chỉ phía mobile không bảo đảm bắt được mọi tin hệ điều hành đã hiển thị. Cloud Function ghi inbox trước khi push và chỉ gửi tới các UID được quản trị viên cho phép trong `ciNotificationRepositories`, đồng thời kiểm tra repo còn nằm trong project của user. Luồng tự động chỉ hoạt động sau khi deploy/cấu hình theo `functions/README.md`.

#### Rules cần Publish thủ công

Chèn các match sau vào bên trong match /users/{userId}, cùng cấp với projects. Dùng các helper activeUser() và text() hiện có. Giữ rule ciAnalyses và các rule đã publish khác. Chưa publish Console trong lần chỉnh code này.

```rules
      // Per-user notification inbox. Publishers use Admin SDK; a device may
      // also persist a directly received FCM message into its own inbox.
      match /notifications/{notificationId} {
        function isOwner() {
          return activeUser() && request.auth.uid == userId;
        }
        function validNotification() {
          let d = request.resource.data;
          return d.keys().hasAll(['notification_id', 'uid', 'title', 'body', 'received_at', 'read'])
            && d.keys().hasOnly(['notification_id', 'uid', 'title', 'body', 'received_at', 'read',
              'type', 'repo_id', 'repo_full_name', 'run_id', 'attempt', 'phase'])
            && notificationId.matches('^[A-Za-z0-9_-]{1,128}$')
            && d.notification_id == notificationId && d.uid == userId
            && (!('phase' in d) || d.phase in ['started', 'completed'])
            && text(d.title, 1, 200) && text(d.body, 0, 1000)
            && text(d.received_at, 1, 40) && d.read == false
            && (!('type' in d) || (d.type == 'workflow_run'
              && d.repo_id is string && d.repo_id.matches('^[1-9][0-9]{0,15}$')
              && d.run_id is string && d.run_id.matches('^[1-9][0-9]{0,15}$')
              && d.attempt is string && d.attempt.matches('^[1-9][0-9]{0,15}$')
              && text(d.repo_full_name, 3, 201)
              && d.repo_full_name.matches('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')));
        }
        allow read: if isOwner();
        allow create: if isOwner() && validNotification();
        allow update: if isOwner()
          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['read'])
          && request.resource.data.read == true;
        allow delete: if false;
      }
      // A preference alone does not authorize delivery. The trusted publisher
      // also checks that this repo is still saved in one of the user's projects.
      match /ciSubscriptions/{repoId} {
        function isOwner() {
          return activeUser() && request.auth.uid == userId;
        }
        allow read, delete: if isOwner();
        allow create, update: if isOwner()
          && repoId.matches('^[1-9][0-9]{0,15}$')
          && request.resource.data.keys().hasAll(['repoId', 'repoFullName', 'mode', 'updatedAt'])
          && request.resource.data.keys().hasOnly(['repoId', 'repoFullName', 'mode', 'updatedAt'])
          && request.resource.data.repoId == repoId
          && text(request.resource.data.repoFullName, 3, 201)
          && request.resource.data.repoFullName.matches('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')
          && request.resource.data.mode in ['failures', 'results', 'all', 'off']
          && request.resource.data.updatedAt == request.time;
      }
      match /devices/{installationId} {
        function isOwner() {
          return activeUser() && request.auth.uid == userId;
        }
        allow read, delete: if isOwner();
        allow create, update: if isOwner()
          && installationId.matches('^[a-f0-9]{48}$')
          && request.resource.data.keys().hasAll(['fid', 'platform', 'updatedAt'])
          && request.resource.data.keys().hasOnly(['fid', 'platform', 'updatedAt'])
          && text(request.resource.data.fid, 1, 128)
          && request.resource.data.platform == 'android'
          && request.resource.data.updatedAt == request.time;
      }
```

Test trong mobile/: flutter analyze --no-pub và flutter test --no-pub. Các test Dart dùng fake messaging/history/preferences, MethodChannel mock và HTTP GitHub mock; không cần Python hoặc Node sender. Test/build không chứng minh push thật đã hiển thị trên điện thoại.
