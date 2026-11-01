---
version: "1.1"
name: Vista CI
description: Workspace monitoring for GitHub Actions with multi-repository runs, logs, AI-assisted failure analysis, reviewed actions, and audit history.

colors:
  primary: "#2563EB"
  on-primary: "#FFFFFF"
  primary-container: "#DBEAFE"
  on-primary-container: "#1E3A8A"

  secondary: "#0F766E"
  on-secondary: "#FFFFFF"
  secondary-container: "#CCFBF1"
  on-secondary-container: "#134E4A"

  tertiary: "#7C3AED"
  on-tertiary: "#FFFFFF"
  tertiary-container: "#EDE9FE"
  on-tertiary-container: "#4C1D95"

  neutral: "#F8FAFC"
  background: "#F8FAFC"
  surface: "#FFFFFF"
  surface-muted: "#F1F5F9"
  on-surface: "#0F172A"
  on-surface-variant: "#475569"
  outline: "#CBD5E1"
  outline-variant: "#E2E8F0"

  success: "#15803D"
  on-success: "#FFFFFF"
  success-container: "#DCFCE7"
  on-success-container: "#14532D"

  warning: "#B45309"
  on-warning: "#FFFFFF"
  warning-container: "#FEF3C7"
  on-warning-container: "#78350F"

  error: "#B91C1C"
  on-error: "#FFFFFF"
  error-container: "#FEE2E2"
  on-error-container: "#7F1D1D"

typography:
  headline-display:
    fontFamily: Inter
    fontSize: 36px
    fontWeight: 700
    lineHeight: 44px
    letterSpacing: -0.02em

  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: 700
    lineHeight: 36px
    letterSpacing: -0.015em

  headline-md:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: 600
    lineHeight: 28px

  title-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: 600
    lineHeight: 24px

  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: 400
    lineHeight: 28px

  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: 400
    lineHeight: 24px

  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: 400
    lineHeight: 20px

  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: 600
    lineHeight: 20px

  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: 600
    lineHeight: 16px
    letterSpacing: 0.01em

rounded:
  none: 0px
  sm: 4px
  md: 8px
  lg: 12px
  xl: 16px
  full: 9999px

spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  2xl: 48px
  page-gutter: 24px
  card-padding: 20px
  section-gap: 32px
  table-row: 12px

components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label-md}"
    rounded: "{rounded.md}"
    padding: 12px

  button-primary-hover:
    backgroundColor: "{colors.primary-container}"
    textColor: "{colors.on-primary-container}"

  button-secondary:
    backgroundColor: "{colors.secondary}"
    textColor: "{colors.on-secondary}"
    typography: "{typography.label-md}"
    rounded: "{rounded.md}"
    padding: 12px

  button-secondary-hover:
    backgroundColor: "{colors.secondary-container}"
    textColor: "{colors.on-secondary-container}"

  button-danger:
    backgroundColor: "{colors.error}"
    textColor: "{colors.on-error}"
    typography: "{typography.label-md}"
    rounded: "{rounded.md}"
    padding: 12px

  input-field:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body-md}"
    rounded: "{rounded.md}"
    padding: 12px

  input-field-error:
    backgroundColor: "{colors.error-container}"
    textColor: "{colors.on-error-container}"
    rounded: "{rounded.md}"
    padding: 12px

  card-summary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.lg}"
    padding: "{spacing.card-padding}"

  card-analysis:
    backgroundColor: "{colors.primary-container}"
    textColor: "{colors.on-primary-container}"
    rounded: "{rounded.lg}"
    padding: "{spacing.card-padding}"

  card-run-pass:
    backgroundColor: "{colors.success-container}"
    textColor: "{colors.on-success-container}"
    rounded: "{rounded.lg}"
    padding: "{spacing.card-padding}"

  card-run-fail:
    backgroundColor: "{colors.error-container}"
    textColor: "{colors.on-error-container}"
    rounded: "{rounded.lg}"
    padding: "{spacing.card-padding}"

  run-row:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.md}"
    padding: "{spacing.table-row}"

  run-row-hover:
    backgroundColor: "{colors.surface-muted}"

  filter-chip:
    backgroundColor: "{colors.surface-muted}"
    textColor: "{colors.on-surface-variant}"
    rounded: "{rounded.full}"
    padding: 8px

  success-badge:
    backgroundColor: "{colors.success-container}"
    textColor: "{colors.on-success-container}"
    typography: "{typography.label-sm}"
    rounded: "{rounded.full}"
    padding: 8px

  warning-badge:
    backgroundColor: "{colors.warning-container}"
    textColor: "{colors.on-warning-container}"
    typography: "{typography.label-sm}"
    rounded: "{rounded.full}"
    padding: 8px

  error-badge:
    backgroundColor: "{colors.error-container}"
    textColor: "{colors.on-error-container}"
    typography: "{typography.label-sm}"
    rounded: "{rounded.full}"
    padding: 8px

  chart-tooltip:
    backgroundColor: "{colors.on-surface}"
    textColor: "{colors.neutral}"
    rounded: "{rounded.md}"
    padding: 12px

# Vista extensions. Base style values above are preserved from origin/main.
extensions:
  font-mono: "Geist Mono"
  text-disabled: "#64748B"
  outline-strong: "#64748B"
  focus: "#2563EB"
  scrim: "rgba(15,23,42,0.48)"
  touch-min: 48px
  icon-sm: 16px
  icon-md: 20px
  icon-lg: 24px
  filter-visual: 32px
  appbar-mobile-min: 56px
  header-web-min: 64px
  bottom-tab-min: 64px
  content-max: 1200px
  reading-max: 680px
  filter-popover-max: 360px
  dialog-max: 480px
  code-web:
    fontSize: 14px
    lineHeight: 20px
    fontWeight: 400
  code-mobile:
    fontSize: 12px
    lineHeight: 16px
    fontWeight: 400
  motion-curve: "cubic-bezier(0.22,1,0.36,1)"
  motion-fast: 200ms
  motion-base: 300ms
  motion-slow: 500ms
  shadow-menu: "0 4px 16px rgba(15,23,42,0.12)"
  shadow-dialog: "0 8px 24px rgba(15,23,42,0.16)"
---

# Vista CI — Thiết kế sản phẩm

| Thuộc tính | Giá trị |
| --- | --- |
| Phiên bản | 1.1, cập nhật style từ main ngày 01/11/2026 |
| Vai trò | File chuẩn tại docs/DESIGN.md cho web và Flutter |
| Phạm vi | Workspace nhiều repository, CI/CD, log, agent phân tích, hành động và audit |
| Tài liệu tiếp theo | `FLUTTER_HANDOVER.md`, do Codex viết |
| Trạng thái | Đã đối chiếu nguồn; chưa triển khai các thay đổi thiết kế này vào UI |

Các yêu cầu do người dùng chốt được phân biệt với lựa chọn thiết kế ở mục 2 và quyết định tích hợp còn mở ở mục 13. Việc tổng hợp thiết kế không xác nhận dịch vụ, quyền hoặc ngân sách đã được duyệt. Không dùng prototype hiện tại làm chuẩn bố cục cuối.

## 1. Mục đích và nguồn đối chiếu

Vista giúp nhóm xem tình trạng CI/CD của nhiều repository trong một workspace, hiểu lỗi từ log và chọn bước xử lý. Luồng chính: đăng nhập → workspace → run → log/phân tích → xem trước hành động → gửi → theo dõi kết quả/audit.

Nguồn style là `docs/DESIGN.md` tại main, commit `1f738aca4aab3f532ac71d507a4796f2b4818b59` (PR #2), do người dùng yêu cầu tận dụng. Các giá trị màu, typography Inter, spacing, radius và style component nền tảng được giữ trong YAML phía trên. Tên component được ánh xạ sang Vista khi cần; phần extensions ghi rõ các bổ sung mà file gốc chưa có.

Nguồn luồng sản phẩm là thiết kế Vista đã tổng hợp v1.0 và các quyết định trực tiếp của người dùng: workspace nhiều repo, log, agent, quick actions và audit; mobile bottom tab, web header và nút nhỏ mở bộ lọc. Đã đối chiếu overview và prototype trong quá trình soạn v1.0. Không nhập nghiệp vụ tài chính vào Vista.

File này ưu tiên style trên main hơn guideline bên ngoài khi có xung đột, cụ thể giữ **Inter và palette blue/teal/violet**, thay lựa chọn Manrope và nút chính trung tính ở v1.0. Những quy tắc tương tác và dữ liệu của Vista được giữ. Material 3 trên Flutter vẫn được dùng cho cấu trúc và hành vi.

Tài liệu 01–08 và các Google Docs/Sheet v0.3 là snapshot cũ. Yêu cầu mới nhất của người dùng có ưu tiên cao nhất. Tài liệu thiết kế không tự cấp quyền GitHub, chốt provider AI hoặc xác nhận tích hợp đã hoạt động.

## 2. Phạm vi và nguyên tắc

### 2.1 Yêu cầu đã chốt

| Nhóm | Yêu cầu |
| --- | --- |
| Tài khoản | Firebase Email/Password; hồ sơ Admin/Member; đăng xuất và phiên hợp lệ |
| Workspace | Thông tin dự án và nhiều repository, dữ liệu đúng quyền workspace |
| Theo dõi | Trạng thái đang chờ/đang chạy, kết quả, branch, commit, thời gian và lịch sử phân trang |
| Log | Xem jobs/steps và log đúng run/attempt; có liên kết nguồn |
| Agent | Tóm tắt lỗi, dẫn chứng, vị trí nếu xác định được và hướng xử lý; ưu tiên dịch vụ miễn phí, chưa chọn provider |
| Hành động | Chạy workflow mới, chạy lại build lỗi; soạn và gửi issue/comment PR có xem trước |
| Audit | Người thao tác, thời gian, đối tượng, request ID và kết quả; truy vết PR/commit đúng nguồn |
| Đầu ra | Artifact và URL deployment hiển thị riêng |
| Điều hướng | Mobile bottom tab; web header; bộ lọc mở qua một nút nhỏ |

FCM giữ sau MVP. Không thêm điều phối nhiều coding agents, tự sửa source/tạo PR, xếp hạng chất lượng cá nhân hoặc checklist bản demo. AI chỉ khuyến nghị; backend xác thực quyền và điều kiện thực thi. Không coi chủ PR là người gây lỗi hoặc số lần fail là thước đo chất lượng code.

### 2.2 Lựa chọn thiết kế dùng cho bản đầu

- Mobile có 4 tab: **Run · Repo · Hoạt động · Tài khoản**; mặc định Run sau khi chọn workspace.
- Web có header: logo, workspace switcher, **Run · Repo · Hoạt động**, menu tài khoản. Không sidebar chính.
- Theme sáng là baseline. Theme tối, tùy chỉnh giao diện và reset password là mở rộng, chưa bắt buộc MVP.
- Mỗi nhóm bộ lọc chỉ chọn một giá trị hoặc Tất cả; nhiều repository vẫn được xem chung khi không lọc. Chưa thêm multi-select hoặc lọc branch nhiều giá trị.
- Agent phân tích theo nút bấm; retry toàn bộ run thất bại. Chưa thêm auto-triage hoặc chọn chạy riêng job lỗi.
- Issue giữ repository của run; comment chỉ chọn trong các PR liên quan do backend xác minh. Chưa chuyển issue sang repo khác hoặc nhập tay PR bất kỳ.

Đây là lựa chọn thiết kế tổng hợp để làm bản đầu gọn và nhất quán, không phải khả năng đã có của backend. Những thay đổi phạm vi hoặc permission vẫn phải được người dùng chốt.

## 3. Màn hình và điều hướng

### 3.1 Danh mục ổn định

| ID | Màn hình | Điểm vào |
| --- | --- | --- |
| `S-AUTH-LOGIN` | Đăng nhập | Chưa xác thực |
| `S-WS-PICK` | Chọn workspace | Có phiên và hồ sơ active |
| `S-RUN-LIST` | Lịch sử CI/CD | Tab Run / header Run |
| `S-REPO-LIST` | Các repository | Tab Repo / header Repo |
| `S-REPO-DETAIL` | Chi tiết repository và workflows | Chọn repo |
| `S-RUN-DETAIL` | Chi tiết run | Chọn run |
| `S-LOG-VIEW` | Log toàn màn hình | Mở rộng log |
| `S-AUDIT-LIST` | Lịch sử thao tác | Tab Hoạt động / header Hoạt động |
| `S-AUDIT-DETAIL` | Chi tiết thao tác | Chọn mục audit |
| `S-ACCOUNT` | Hồ sơ, workspace, đăng xuất | Tab Tài khoản / menu tài khoản web |
| `S-SYS-NOACCESS` | Thiếu hồ sơ/quyền hoặc inactive | Kiểm tra quyền thất bại |
| `S-SYS-NOTFOUND` | Nội dung không tồn tại | Chỉ sau khi kiểm tra quyền |

`S-RUN-DETAIL` có 4 phần: `SEC-OVERVIEW`, `SEC-LOG`, `SEC-ANALYSIS`, `SEC-OUTPUT`. Chuyển phần tại chỗ; đây không phải bottom tab.

Các lớp phủ: `M-WS-SWITCH`, `M-FILTER-RUN`, `M-ATTEMPT-PICK`, `M-ACT-DISPATCH`, `M-ACT-RERUN`, `M-ACT-ISSUE`, `M-ACT-PRCOMMENT`. Chúng dùng cùng nội dung và state trên hai nền tảng, cách trình bày khác theo không gian.

### 3.2 Mobile

```text
Màn hình gốc                 Chi tiết run
┌────────────────────────┐  ┌────────────────────────┐
│ [Workspace hiện tại ▾] │  │ ← Run / attempt    [⋯] │
│ Run            [Lọc 2] │  │ Workspace · repo       │
│ [Repo ×] [Fail ×]      │  │ Kết quả · branch · SHA │
│ Các run dạng card      │  │ Tổng quan | Log        │
│ ...                    │  │ Phân tích | Đầu ra     │
│ [Tải thêm]             │  │ Nội dung phần đã chọn  │
│ Run Repo Hoạt động Tôi │  │ [Hành động phù hợp]    │
└────────────────────────┘  └────────────────────────┘
```

Bottom tab chỉ hiện ở 4 màn hình gốc; ẩn khi đi sâu vào repo/run/log/audit hoặc mở trình soạn để tránh chồng thanh hành động. Trên màn hình gốc bấm lại tab đang chọn cuộn về đầu. Mỗi tab giữ vị trí và bộ lọc trong cùng workspace; không đặc tả thao tác bấm tab khi tab đang bị ẩn.

App bar màn hình gốc có tên workspace và nút đổi. Chi tiết giữ tên workspace/repo ở tiêu đề phụ và nút Back. Quay lại khôi phục danh sách, bộ lọc, con trỏ và vị trí cuộn. Safe area nằm ngoài chiều cao nội dung các thanh.

### 3.3 Web

```text
┌─────────────────────────────────────────────────────────────┐
│ Vista | [Workspace ▾] | Run  Repo  Hoạt động | [Tài khoản ▾] │
├─────────────────────────────────────────────────────────────┤
│ CI/CD runs                                       [Bộ lọc 2]│
│ [Repo ×] [Fail ×]                                            │
│ Bảng run / nội dung trang                                    │
└─────────────────────────────────────────────────────────────┘
```

Header cố định; padding nội dung bù chiều cao header. Dưới 768 CSS px, header thành 2 hàng, 3 mục vẫn ở phía trên; không chuyển web sang bottom tab. Dưới 1024 dùng run card hoặc bảng rút gọn theo không gian, tránh bảng 8 cột trên điện thoại.

Mục hiện tại có chữ + gạch dưới/shape, không chỉ đổi màu. Menu tài khoản dẫn tới hồ sơ và đăng xuất; không có điều khiển theme tối trong baseline sáng.

### 3.4 Workspace, session và bản nháp

1. Có draft chưa gửi thì hỏi trước khi bỏ để đổi workspace, thoát trình soạn hoặc đăng xuất.
2. Nếu command đã gửi, rời màn hình không hủy tác động phía server. Lưu request ID để tra lại; không cảnh báo sai rằng đổi workspace sẽ hủy workflow.
3. Hủy subscription/đọc dữ liệu cũ ở client, bỏ response muộn không khớp workspace/query/run/attempt.
4. Xóa state hiển thị, lựa chọn repo/run/attempt, bộ lọc, con trỏ và draft cũ; mở Run của workspace mới.
5. Đăng xuất hoặc mất quyền phải chặn dữ liệu cũ ngay. Không giữ dữ liệu nhạy cảm chỉ để hiển thị banner stale.
6. Workspace gần nhất chỉ được nhớ theo tài khoản và phải kiểm tra membership lại trước khi mở.

## 4. Hợp đồng hiển thị và trạng thái dữ liệu

### 4.1 Định danh và thời gian

Định danh run/analysis/log phải gồm workspace, repository ID ổn định, run ID và attempt; log/dẫn chứng thêm job ID và locator/version nguồn nếu có. Tên `owner/repo` chỉ phục vụ hiển thị, không thay định danh.

Mô hình mục tiêu tách `status` và `conclusion`. Prototype đang gộp `success/failure` vào `RunStatus` nên cần migration khi implement, không ép UI mới theo model mẫu này. Quy ước mapping được chuyển vào `FLUTTER_HANDOVER.md`, chưa đổi schema live.

Sắp lịch sử theo `createdAt` nguồn giảm dần và khóa ổn định làm tie-break; queued có thể chưa có `startedAt`. Không đổi thứ tự bằng `syncedAt` hoặc thời lượng. Hiển thị bắt đầu/thời lượng khi nguồn có, không tạo timestamp giả. Ngày giờ theo múi giờ thiết bị, đầy đủ ngày/giờ/offset khi mở chi tiết; không đổi raw timestamp nguồn.

### 4.2 Trạng thái chung

| Trạng thái | Hiển thị |
| --- | --- |
| Loading | Skeleton đúng vùng đang tải, không khóa toàn bộ màn hình |
| Empty | Phân biệt chưa có repo/run, chưa đồng bộ và không khớp bộ lọc |
| Error | Lỗi cụ thể, hành động Thử lại; có thể giữ dữ liệu cũ nếu vẫn còn quyền |
| No permission | Thay nội dung bị chặn; hướng dẫn liên hệ quản trị, không lộ dữ liệu |
| Stale/offline | Nêu thời điểm đồng bộ; không tự gọi là build lỗi hoặc mất quyền |
| Sample | Banner “Dữ liệu mẫu”; phân tích soạn sẵn ghi “Phân tích mẫu, không phải kết quả agent” |

Mỗi đăng ký thuộc khóa workspace/query. Trang đầu có thể realtime, trang sau dùng cursor. Run mới không tự chèn làm dịch dòng đang đọc: hiện “Có run mới — Tải”. Không hiện tổng số hoặc số trang nếu backend không trả tổng đáng tin cậy. Lỗi log/agent không làm mất tổng quan run.

## 5. Đặc tả màn hình

| Screen | Nội dung và thao tác chính | Trạng thái riêng cần có |
| --- | --- | --- |
| `S-AUTH-LOGIN` | Email, mật khẩu, hiện/ẩn mật khẩu, Đăng nhập; nhãn luôn thấy | Trường rỗng/sai định dạng, đang gửi, sai thông tin chung, mạng/rate limit |
| `S-WS-PICK` | Card tên dự án, mô tả, số repo khi có; chọn workspace | Không có workspace: liên hệ Admin, Đăng xuất; không giả lỗi đăng nhập |
| `S-RUN-LIST` | Run card/bảng, Lọc, filter chips, tải thêm/Trước–Sau | Có dữ liệu mới, lỗi tải trang sau, đang chờ/đang chạy, không có kết quả |
| `S-REPO-LIST` | Tên repo, mô tả, trạng thái tích hợp, run gần nhất | Chưa có run; chưa kết nối khác với đã kết nối nhưng chưa có run |
| `S-REPO-DETAIL` | Metadata, liên kết GitHub, workflow allowlist, run gần đây; Chạy workflow | Không có workflow chạy tay, thiếu quyền, tích hợp ngắt |
| `S-RUN-DETAIL` | Header định danh, attempt picker, 4 phần và thanh hành động | Lỗi/phân quyền độc lập theo từng phần; đổi attempt không giữ analysis/log cũ |
| `S-LOG-VIEW` | Run/attempt/job/step, log, tải đoạn, sao chép, quay lại | Log chưa có/hết hạn/thiếu quyền/bị giới hạn, lỗi tải từng đoạn |
| `S-AUDIT-LIST` | Thời gian giảm dần, actor, action, target, kết quả; phân trang | Trống, scope theo run khi đi từ chi tiết; lỗi không biến thành audit thành công |
| `S-AUDIT-DETAIL` | Request ID, actor, nguồn PR/commit liên quan, mốc thời gian, outcome và link | Đang xử lý/unknown có Kiểm tra kết quả; không có link thì không tạo link giả |
| `S-ACCOUNT` | Tên/email, profile role, workspace và membership khi có; Đăng xuất | Không tự dùng role để kết luận mọi quyền; profile lỗi/inactive |
| `S-SYS-NOACCESS` | Thông báo thiếu quyền/hồ sơ/inactive phù hợp; liên hệ quản trị, Đăng xuất/Đổi workspace khi hợp lệ | Không tiết lộ dữ liệu ngoài quyền |
| `S-SYS-NOTFOUND` | Không tìm thấy; quay về nơi hợp lệ | Chỉ dùng sau khi đã kiểm tra quyền |

Auth thành công → kiểm tra `users/{uid}` → active/profile hợp lệ → lấy workspace. Thiếu profile/inactive vào No access, không coi là tài khoản chưa có workspace. Một workspace có thể mở thẳng; nhiều workspace mở picker hoặc workspace gần nhất đã được xác minh. Không thêm self-signup/mời thành viên khi chưa có quyết định.

Danh sách run mobile hiển thị badge, workflow, attempt, repo, branch/SHA, thời gian và người kích hoạt khi có. Web ưu tiên các cột tương ứng; tác giả PR/commit nằm ở chi tiết để tránh nhầm với người kích hoạt. Trang đầu mặc định 20; mobile Tải thêm, web Trước/Sau theo cursor, không nhảy tùy ý tới trang N.

### 5.1 Bộ lọc

Nút `C-FILTER-TRIGGER` có icon 20 trong hình 32, vùng tương tác ít nhất 48; nhãn truy cập “Bộ lọc, n đang áp dụng”. Badge n đếm nhóm lọc có giá trị, từ 0–3; 0 thì không hiện badge.

- `repositoryId`: Tất cả hoặc một repo trong workspace.
- `displayState`: Tất cả hoặc một trạng thái ở mục 6.
- `branch`: Tất cả hoặc một branch chính xác, gợi ý theo repo đã chọn. Đổi repo thì xóa branch nếu không còn hợp lệ.
- Mobile mở bottom sheet; web từ 768 mở popover/dialog neo nút, dưới 768 mở sheet. Có Apply/Hủy/Xóa lọc.
- Sửa trên bản tạm. Apply cập nhật và về trang đầu. Hủy/Esc/back/chạm ngoài/kéo sheet đóng bỏ bản tạm. Xóa lọc trong sheet chỉ sửa bản tạm; Xóa tất cả ở danh sách áp dụng ngay.
- Filter chips gỡ được; không biến thành các dropdown luôn mở trên trang. Nếu query không được hỗ trợ, báo rõ trước khi áp dụng, không lọc cục bộ một trang rồi gọi là kết quả toàn lịch sử.

### 5.2 Các phần chi tiết run

`SEC-OVERVIEW`: định danh nguồn, attempt, status/conclusion, jobs/steps, thời gian; người kích hoạt, tác giả PR và tác giả commit riêng biệt. Không có dữ liệu ghi đúng là chưa có. Mở step lỗi để xem log; nhiều job lỗi phải chọn job phân tích, không ngụ ý đã phân tích cả run.

`SEC-LOG`: log của job/step đang chọn, điều khiển mở toàn màn hình, sao chép và tải theo đoạn. Giữ vị trí đọc khi có dữ liệu mới.

`SEC-ANALYSIS`: cùng run/attempt/job; kết quả và CTA theo mục 7. Không có tab agent toàn app riêng.

`SEC-OUTPUT`: Artifact và Deployment thành hai nhóm. Artifact có tên, kích thước/hạn khi nguồn trả, Mở artifact/Tải nếu có khả năng thật; expired/missing/forbidden phân biệt rõ. Deployment có môi trường/trạng thái/URL, chỉ có nút Mở website khi nguồn có URL. Không coi địa chỉ metadata là link tải lâu dài hoặc build success là website đã deploy.

## 6. Trạng thái run, job và step

Giữ raw status/conclusion để đối chiếu. Bảng dưới là mapping hiển thị; adapter nguồn xử lý enum phát sinh, không giả dữ liệu.

| Điều kiện | Nhãn | Token trạng thái |
| --- | --- | --- |
| queued / waiting / pending / requested | Đang chờ | neutral |
| in_progress | Đang chạy | running |
| completed + success | Pass | pass |
| completed + failure | Fail | fail |
| completed + timed_out / startup_failure | Hết thời gian / Không khởi động được | fail |
| completed + cancelled | Đã hủy | neutral |
| completed + skipped | Bỏ qua | neutral |
| completed + action_required | Cần xử lý | warn |
| completed + neutral | Trung tính | neutral |
| completed + stale | Kết quả cũ | warn |
| Thiếu/giá trị lạ hoặc cặp không hợp lệ | Chưa rõ | unknown |

Không gộp cancelled/skipped/neutral thành Pass/Fail. “Kết quả cũ” của nguồn khác với cảnh báo dữ liệu Vista lâu chưa đồng bộ. Mỗi attempt có trạng thái độc lập. Thời lượng không đếm nếu chưa có start; không bắt bộ đếm cập nhật mỗi giây.

## 7. Agent và gợi ý hành động

| State | Trình bày |
| --- | --- |
| none | Chưa phân tích; nút Phân tích lỗi nếu có quyền và đủ log |
| processing | Đang phân tích; có thể đọc log hoặc rời màn hình, không gửi trùng |
| ready | Nhận định, category, dẫn chứng, vị trí nếu xác minh, đề xuất, thời gian và nguồn |
| failed | Không phân tích được, Thử lại có giới hạn hoặc Xem log |
| quota | Hết hạn mức; chỉ nêu thời điểm phục hồi nếu biết, không tự retry |
| insufficient-data | Nói thiếu log/job/đoạn nào, không bịa nguyên nhân |
| stale | Bản phân tích cũ hoặc input không còn khớp; không dùng lẫn attempt |
| no-permission | Không được yêu cầu hoặc đọc phân tích; hai capability riêng |

Dữ liệu phân tích tối thiểu: run/attempt/job key, category (`code`, `transient`, `configuration`, `unknown`), summary, evidence[], suggestions[], createdAt và provenance/input reference. Location chỉ có khi bằng chứng chỉ ra được. Log thiếu, AI lỗi và run lỗi là ba sự việc riêng. Không có dẫn chứng đáng tin thì trình bày nhận định chưa xác minh, không biến thành kết luận chắc chắn hoặc tự dùng để đăng.

| Kết quả hiện tại | Hành động nhấn mạnh | Hành động khác theo quyền |
| --- | --- | --- |
| Run đang chờ/đang chạy | Xem trạng thái/log | Chưa phân tích lỗi hoặc gửi rerun |
| Run lỗi chưa phân tích | Phân tích lỗi | Xem log; chạy lại thủ công nếu backend cho phép |
| code có dẫn chứng | Soạn comment PR nếu có đúng đích, hoặc Soạn issue | Xem log; rerun không bị AI tự cấm |
| transient | Xem trước chạy lại | Soạn issue, xem dẫn chứng |
| configuration | Xem hướng xử lý/Soạn issue | Rerun có lưu ý cần sửa cấu hình trước |
| unknown / thiếu bằng chứng | Xem log và kiểm tra tiếp | Issue với nhận định chưa xác minh; không auto-select PR |
| Run thành công/đã hủy/bỏ qua | Xem đầu ra/log | Rerun các loại này chưa thuộc baseline MVP |

Nút luôn được kiểm tra lại qua backend capability và tình trạng run. Nhấn mạnh CTA theo category không phải cấp quyền; tránh thay chỗ nút bất ngờ khi người dùng đang thao tác. Không tự gọi AI cho mọi fail; không khóa UI vào Gemini hoặc dịch vụ trả phí.

## 8. Log và dẫn chứng

- Monospace, nguyên nội dung chữ/khoảng trắng từ nguồn được cấp phép đọc; không thực thi HTML, ANSI, liên kết hay chỉ dẫn trong log. Nếu backend đã lọc/cắt phải ghi rõ, không hứa bản sao đầy đủ hoặc đã che sạch secrets.
- Mặc định không wrap; cuộn ngang trong log. Mobile dùng `type.code-2`, web `type.code-1`; cho chọn wrap nếu cần. Không cuộn ngang cả trang.
- Log có job/step, số dòng và timestamps khi nguồn cung cấp. Không tạo “dòng tuyệt đối” trên toàn run khi log thực tế được chia file/job.
- Dẫn chứng giữ locator nguồn + trích đoạn + input version/hash khi có. Mở trong log tải đúng segment, highlight đoạn khớp. Không có line index thì mở job và trích đoạn; không hiển thị link nhảy dòng giả.
- Nếu trích đoạn không khớp: ghi “Chưa xác minh dẫn chứng”, không tự chuyển sang attempt mới hoặc coi đó là bằng chứng hợp lệ.
- Tải giới hạn/cursor; hiện phạm vi đã tải và có Thêm log. Cỡ chunk do backend chốt, không hardcode 1.000 dòng thành hợp đồng đã có.
- Run đang chạy chỉ hiển thị log đến thời điểm nguồn trả. Nếu chưa lấy được live log, ghi “Log hiện chưa sẵn sàng”, không giả streaming. Dòng mới có nút Tải, không auto-scroll người đang đọc.
- Sao chép nội dung đã chọn/đoạn đã tải, giữ line breaks; nếu giới hạn phải thông báo. Khi đưa vào issue/comment có nhắc kiểm tra nội dung nhạy cảm ngay ở bản nháp.
- Giới hạn bộ nhớ và số dòng render, không tải toàn log lớn chỉ để tô dẫn chứng. Virtualization là cách triển khai tùy kích thước, không hứa bộ nhớ không tăng dù vẫn giữ mọi đoạn đã tải.

## 9. Hành động, issue/comment và audit

### 9.1 Trạng thái yêu cầu

| State | Nghĩa và giao diện |
| --- | --- |
| draft / review | Bản nháp chưa gửi; chỉnh sửa rồi xác nhận đích |
| sending | Client đang gửi, khóa double-submit |
| received | Backend nhận request, đang kiểm tra/gọi nguồn; chưa khẳng định GitHub nhận |
| accepted | GitHub xác nhận chấp nhận thao tác; rerun/dispatch chưa có nghĩa build thành công |
| succeeded | Thao tác đã hoàn tất có bằng chứng, ví dụ issue/comment được tạo; không dùng thay conclusion của run |
| rejected | Quyền/allowlist/input bị từ chối trước tác động, giữ draft |
| failed | Backend xác định thất bại và kết quả tác động đã rõ; giải thích khả năng thử lại |
| unknown | Không xác định đã tác động hay chưa; giữ request ID, khóa gửi lặp, cho Kiểm tra kết quả |

Request ID ổn định cho cùng ý định. Retry transport giữ ID; sửa đích/nội dung tạo ý định mới sau khi xử lý yêu cầu cũ chưa rõ. Chỉ retry khi backend cho phép sau đối soát; timeout không mặc định là failed. Kết quả hiển thị bền trong màn hình/audit, không chỉ toast tự mất. Không hứa gọi GitHub đúng một lần tuyệt đối.

### 9.2 Chạy mới và chạy lại

`M-ACT-DISPATCH`: repo → workflow trong allowlist → branch/ref hợp lệ → inputs được hỗ trợ → xem trước → Gửi. Không tự thêm branch/inputs tùy ý hoặc workflow không hỗ trợ dispatch. Credential không xuất hiện trong form.

`M-ACT-RERUN`: repo, workflow, run ID, attempt nguồn và “Yêu cầu chạy lại toàn bộ run”. Không hứa chắc “sẽ tạo attempt n+1” hoặc run đã chạy trước phản hồi nguồn; khi có attempt mới, liên kết đúng attempt. Không tự bật retry chỉ vì AI nói được.

### 9.3 Issue/comment

Giữ cả hai luồng. Issue có repo của run, tiêu đề, nội dung. Comment có PR target được backend xác minh và nội dung. Draft nêu run/attempt/SHA/job, nhận định có mức chắc chắn, dẫn chứng và hướng xử lý; có nhãn nguồn AI hoặc người dùng. Link log có thể cần quyền Vista; người đọc GitHub không mặc nhiên truy cập được link nội bộ.

Một PR liên quan được hiển thị rõ để người dùng xác nhận; nhiều PR bắt buộc chọn; không có PR thì vô hiệu comment với lý do và đề xuất issue. Không suy PR chỉ từ người tạo hoặc tên branch trùng. Không tự gửi hoặc tự sửa repo đích.

Draft → Chỉnh sửa → Xem trước với đích cạnh nút → Gửi → Outcome/link. Lỗi giữ nội dung. Kiểm tra action đã tồn tại cho run/attempt/đích bằng server; hiện link cũ thay vì tạo trùng ngầm. Markdown nếu render phải an toàn, không thực thi nội dung log/AI.

### 9.4 Audit

Actor UID/tên tại thời điểm thao tác, action, workspace/repo, run/attempt/job/PR/commit nếu có, request ID, timestamps và outcome. Trigger actor, PR author và commit author là trường nguồn riêng, không ghi như cùng một người.

Server tạo audit tin cậy và ghi thay đổi kết quả; client không tự báo lệnh thành công. Preview cục bộ không phải audit đã gửi. Lịch sử có link run/issue/comment khi xác định được; không có thì nói đang chờ/chưa xác định. Không lưu credential hoặc toàn log vào audit. Phạm vi ai được xem audit của ai là quyết định quyền còn mở.

## 10. Style và ánh xạ token

### 10.1 Nguồn duy nhất của giá trị

YAML đầu file là nguồn style chuẩn. Giữ tên và giá trị `colors`, `typography`, `spacing`, `rounded` và các component gốc từ main. Component tài chính chỉ được đổi tên cho phù hợp Vista: `card-budget` → `card-analysis`, `card-income` → `card-run-pass`, `card-expense` → `card-run-fail`, `transaction-row` → `run-row`, `category-chip` → `filter-chip`. Các giá trị style của chúng không đổi.

`extensions` là bổ sung Vista cho log, accessibility, kích thước, motion và overlay. Chúng không phải giá trị có sẵn trên main. CSS px và Flutter logical px dùng chung giá trị nominal khi ánh xạ, không cam kết kích thước vật lý/font metric giống nhau. Không bắt Flutter dùng CSS hoặc Tailwind.

### 10.2 Màu và vai trò

| Vai trò Vista | Token chuẩn | Giá trị / quy tắc |
| --- | --- | --- |
| Hành động chính, tab/nav được chọn, focus | `colors.primary` | `#2563EB`; chữ `on-primary` trắng |
| Hover hành động chính | `colors.primary-container`, `colors.on-primary-container` | `#DBEAFE` / `#1E3A8A`, theo main |
| Hành động phụ | `colors.secondary`, `colors.on-secondary` | `#0F766E` / trắng, theo main |
| Phân tích agent | `colors.tertiary`, `colors.tertiary-container` | `#7C3AED` / `#EDE9FE`; là phân tích, không phải kết quả build |
| Nền trang / card | `colors.background`, `colors.surface` | `#F8FAFC` / `#FFFFFF` |
| Nền hover hoặc khối log | `colors.surface-muted` | `#F1F5F9` |
| Chữ chính / chữ phụ | `colors.on-surface`, `colors.on-surface-variant` | `#0F172A` / `#475569` |
| Phân cách trang trí | `colors.outline`, `colors.outline-variant` | `#CBD5E1` / `#E2E8F0`; không mặc định đủ cho viền điều khiển thiết yếu |
| Pass | `success-container`, `on-success-container`, `success` | `#DCFCE7` / `#14532D` / `#15803D` |
| Fail | `error-container`, `on-error-container`, `error` | `#FEE2E2` / `#7F1D1D` / `#B91C1C` |
| Đang chạy | `primary-container`, `on-primary-container`, `primary` | `#DBEAFE` / `#1E3A8A` / `#2563EB` |
| Cảnh báo / cần xử lý | `warning-container`, `on-warning-container`, `warning` | `#FEF3C7` / `#78350F` / `#B45309` |
| Queued/cancelled/skipped/neutral | `surface-muted`, `on-surface-variant`, `outline` | Phân biệt icon và chữ, không dùng màu Pass/Fail |
| Chưa rõ | `surface`, `on-surface-variant`, `extensions.outline-strong` | Icon dấu hỏi và viền đứt nét |

Hậu tố `-container` là nền nhẹ và `on-…-container` là chữ tương ứng; tất cả token hàng trạng thái thuộc nhóm `colors`. Không dùng tertiary để làm lỗi agent giống Fail của build. Lỗi phân tích có banner warning trong vùng phân tích riêng. `card-analysis` giữ style primary-container được kế thừa, tertiary dùng icon/nhãn/insight bổ sung, không tự viết lại component gốc.

Các tên semantic dùng ở các phần khác là alias, không tạo bộ màu thứ hai: `color.surface` → `colors.surface`, `color.action` → `colors.primary`, `color.text` → `colors.on-surface`, `color.focus` → `extensions.focus`. `color.log-bg/text/lineno` lần lượt → `surface-muted/on-surface/on-surface-variant`; `color.log-highlight-bg/ring` → `warning-container/warning`.

### 10.3 Typography

Inter dùng cho mọi nội dung giao diện, đúng file main. Giữ nguyên size/weight/line-height/letterSpacing trong YAML, không thay thành Manrope. Geist Mono là đề xuất bổ sung riêng cho log, SHA và identifier; phải kiểm assets, glyph tiếng Việt và license trước khi đưa vào app. Không tự tải font động. Việc baseline dùng Inter không phải tuyên bố đã đóng gói font vào Flutter.

| Ngữ cảnh | Token chuẩn | Cỡ / dòng / weight |
| --- | --- | --- |
| Số tổng quan nổi bật, chỉ khi thật sự có dữ liệu | `headline-display` | 36 / 44 / 700 |
| Tiêu đề trang / đăng nhập | `headline-lg` | 28 / 36 / 700 |
| Tiêu đề phần | `headline-md` | 22 / 28 / 600 |
| App bar / card lớn | `title-lg` | 18 / 24 / 600 |
| Đoạn dài cần đọc | `body-lg` hoặc `body-md` | 18 / 28 / 400 hoặc 16 / 24 / 400 |
| Nội dung dày, metadata | `body-sm` | 14 / 20 / 400 |
| Nút, navigation, nhãn form | `label-md` | 14 / 20 / 600 |
| Badge / chú thích ngắn | `label-sm` | 12 / 16 / 600 |
| Log web | `extensions.code-web` | 14 / 20 / 400, mono |
| Log mobile | `extensions.code-mobile` | 12 / 16 / 400, mono |

Alias của đặc tả screen: `type.code-1`/`type.code-2` dùng hai token code trên. Không dùng headline-display cho mọi card chỉ để làm nổi số. Font số có thể bật tabular numerals nếu hỗ trợ. Không ép branch/log/identifier đổi dấu gạch hoặc kiểu chữ hoa/thường; dữ liệu nguồn phải giữ nguyên. Chữ không nhỏ hơn 12, không weight 900 hoặc italic cho trạng thái/log.

### 10.4 Spacing, shape và depth

| Vai trò | Token / giá trị |
| --- | --- |
| Gutter mobile | `spacing.page-gutter` = 24 |
| Padding card | `spacing.card-padding` = 20 |
| Khoảng cách section | `spacing.section-gap` = 32 |
| Padding row | `spacing.table-row` = 12 |
| Thang chính | xs=4, sm=8, md=16, lg=24, xl=32, 2xl=48 |
| Button/input mặc định | Padding 12 theo YAML; min target 48 theo extensions |
| Bo góc | sm=4, md=8, lg=12, xl=16, full=9999 |
| Card / row / dialog | Card lg=12; row/input/button md=8; dialog/sheet xl=16; badge full |
| Bóng | Card phẳng; menu/dialog dùng shadow extension, không bóng nặng |

Tôn trọng spacing 20 của card trên main, không ép về 16. Bố cục nhỏ hoặc text scale lớn có thể giảm khoảng trắng bằng token gần nhất để giữ nội dung/thao tác, nhưng không thu nhỏ chữ/vùng chạm để nhét. Gap dùng nhịp 4/8, không tạo token tùy ý ở từng screen.

Header web tối thiểu 64, app bar mobile 56, bottom tab 64; các giá trị chưa gồm safe area và được tăng khi text scaling hoặc header 2 hàng. Content max 1200, reading max 680, filter popover tối đa 360, dialog max 480; luôn clamp theo viewport.

### 10.5 Icon, motion và mapping nền tảng

Phosphor là họ icon mục tiêu được bổ sung cho Vista: regular mặc định, fill cho bottom tab chọn. Không đổi icon chỉ để bắt chước component tài chính. Material 3 vẫn dùng cho cấu trúc, focus, semantics và hành vi; icon hiện có không mặc định là asset cuối.

`motion.curve`, `motion.fast/base/slow` là alias đến extensions tương ứng (200/300/500ms). Animate transform/opacity, không scroll reveal cho dashboard, không gradient nền/glass effect. Reduced motion hiển thị ngay hoặc fade ngắn, skeleton tĩnh.

Web dùng CSS custom properties từ YAML; Flutter map `colors` sang ColorScheme/ThemeExtension, `typography` sang TextTheme và spacing/radius sang constants dùng chung. Alias trong tài liệu này phải trỏ về giá trị YAML, không tạo nguồn giá trị mới. `FLUTTER_HANDOVER.md` sẽ ghi mapping cụ thể mà không bắt Flutter dùng HTML/CSS.

## 11. Component dùng chung

| ID | Variants và trách nhiệm |
| --- | --- |
| `C-WS-SWITCHER` | header/appbar/account; tên hiện tại, mở picker, kiểm membership |
| `C-REPO-CARD` | default; metadata, tích hợp, run gần nhất hoặc chưa có |
| `C-RUN-ROW` | card/table-row/compact; định danh attempt, badge, thời gian, actor |
| `C-STATUS-BADGE` | icon + chữ; mapping mục 6, không chỉ màu |
| `C-FILTER-TRIGGER` | hình nhỏ/vùng chạm 48; badge số nhóm |
| `C-FILTER-PANEL` | sheet/popover; draft/apply/cancel/reset |
| `C-FILTER-CHIPS` | giá trị đã áp dụng, gỡ và xóa tất cả |
| `C-PAGINATION` | load-more/prev-next; loading/end/error theo cursor |
| `C-LOG-VIEWER` | inline/fullscreen; segment, selection, nguồn và giới hạn |
| `C-ANALYSIS-CARD` | các state mục 7; category và hành động theo quyền |
| `C-EVIDENCE-BLOCK` | verified/unverified/unavailable; locator và mở log |
| `C-ACTION-DRAFT` | issue/pr-comment; target, nguồn, nội dung chỉnh được |
| `C-ACTION-CONFIRM` | dispatch/rerun/issue/pr-comment; review và command state |
| `C-AUDIT-ENTRY` | row/detail; action/outcome có nguồn server |
| `C-FEEDBACK` | inline/banner/toast; command outcome không chỉ dùng toast |
| `C-SYNC-INDICATOR` | updated/stale/offline; thời gian nguồn và đồng bộ |
| `C-PERMISSION-NOTICE` | vùng dữ liệu bị chặn hoặc lý do action vô hiệu |
| `C-OUTPUT-ITEM` | artifact/deployment; quyền, tồn tại và link hợp lệ |
| `C-JOB-STEP-TREE` | các job/step với state riêng, chọn log đúng nguồn |
| `C-ATTEMPT-SWITCHER` | chip/picker; reset nội dung theo attempt |
| `C-SAMPLE-BANNER` | data/analysis; chỉ xuất hiện trên dữ liệu mẫu |

Mọi control có focus, pressed/hover nếu phù hợp, disabled có lý do bằng chữ, trạng thái đang gửi/tải. Không nút bấm không có tác dụng, link `#` hoặc CTA tạo thành công giả. Tránh lặp cảnh báo AI/mẫu ở mọi đoạn; một nhãn rõ trong đúng vùng là đủ.

## 12. Responsive và tiêu chí nghiệm thu thiết kế

- Mobile kiểm 360/390/430 logical px; web 360/768/1024/1440 CSS px. Ngoài log/bảng trong khung riêng, trang không tràn ngang. Không khóa orientation chỉ để tránh lỗi bố cục.
- Touch target tối thiểu 48 × 48 nominal px; icon lọc nhỏ nhưng vùng chạm không nhỏ. Không coi giá trị này là chứng nhận accessibility.
- Nội dung dùng được từ 100–200% text scale/zoom. Không clamp bottom-tab label ở 1.3 để che lỗi: cho thanh tăng chiều cao hoặc bố trí nhãn ngắn; không mất chức năng/nhãn. Log có điều khiển hiển thị riêng nhưng vẫn đọc được khi tăng chữ.
- Contrast mục tiêu: chữ thường 4.5:1; icon/focus/ranh giới thiết yếu 3:1. Chưa ghi “đạt WCAG” hoặc sao chép bảng tỷ lệ contrast của bản agent như kết quả đã kiểm.
- Dữ liệu dài được wrap/cắt có cách xem đầy đủ; draft editable không ellipsis; SHA/path/log giữ ký tự gốc. Không cắt dấu tiếng Việt.
- Web có skip link, main/nav, focus order, Enter/Space, Esc và focus return cho dialog, aria-current và thông báo async phù hợp. Mobile có semantics và TalkBack/VoiceOver labels.
- Safe area và bàn phím không che nội dung/nút xác nhận. Thanh hành động fixed cần vùng đệm cuộn và tăng chiều cao khi cần.
- Đổi workspace/attempt không hiển thị response cũ. Permission bị thu hồi không giữ nội dung nhạy cảm ở state stale. Log lỗi không chặn tổng quan.
- Filter cancel giữ nguyên query; apply/reset về trang đầu; page sau lỗi giữ phần đã đọc; không lọc giả chỉ trên trang hiện tại.
- Dẫn chứng mở đúng nguồn hoặc báo chưa xác minh. AI lỗi/quota không đổi kết quả build. Request unknown không tự cho gửi lại.
- Issue/comment luôn review đúng đích. Audit preview khác audit server; accepted khác build pass. Không xếp hạng người gây fail.

Đây là tiêu chí cần kiểm khi implement, không phải báo cáo test/build đã chạy. Không thay toàn bộ app để giả đạt các tiêu chí bằng dữ liệu mẫu.

## 13. Quyết định tích hợp còn mở

| ID | Cần chốt | UI vẫn có thể thiết kế trước |
| --- | --- | --- |
| OPEN-01 | Agent provider/API, quota, input gửi đi và chi phí; ưu tiên miễn phí | Adapter trung lập và state none/processing/quota/error |
| OPEN-02 | Backend runtime/billing, GitHub App/credential và webhook/publisher | Command state và permission notice, chưa hứa kết nối |
| OPEN-03 | Capability Admin/Member theo workspace: xem run/log/analysis, phân tích, outputs, actions, audit | Không suy quyền từ tên role, server kiểm từng request |
| OPEN-04 | Membership, cấp tài khoản, tạo/kết nối workspace/repo | Tài khoản seed/Console có thể dùng khi được chốt; chưa thêm invite/onboarding quản trị |
| OPEN-05 | Query/index/cursor và cập nhật queued/running/attempt | Ba bộ lọc một giá trị, realtime trang đầu theo khả năng nguồn |
| OPEN-06 | Log access, segment/version/locator, live-log availability, redaction | Thiếu dữ liệu/không xác minh/không có live log có UI riêng |
| OPEN-07 | Workflow/ref/inputs allowlist, PR mapping, idempotency/reconcile | Form/review và unknown state, không tự tạo ID nguồn |
| OPEN-08 | Artifact/deployment URLs và quyền truy cập | Hai nhóm, unavailable/expired và external-link |
| OPEN-09 | Font/icon assets, giấy phép và glyph tiếng Việt | Token được chọn, chưa coi assets đã có |

Theme tối, reset password, multi-select, tìm kiếm log nâng cao, OS app links, auto-analysis và FCM nằm ở giai đoạn sau hoặc cần yêu cầu bổ sung. Route web và phục hồi nội bộ vẫn cần triển khai cho MVP, không phụ thuộc universal link của hệ điều hành.

## 14. Bàn giao và thay đổi so với prototype

Codex viết `FLUTTER_HANDOVER.md` từ phiên bản này sau khi người dùng duyệt thiết kế; agent ngoài chỉ phụ trách bản thiết kế tham khảo. Handover phải map đúng screen/component/token IDs, MVVM, router/back, repository/service contract, lifecycle subscription, log limits và từng trạng thái. Không tự chọn dịch vụ hoặc tự nối GitHub/AI khi các OPEN tương ứng chưa được chốt.

Danh sách thay đổi UI cần triển khai sau, chưa làm trong lượt tổng hợp:

1. Web sidebar → header; filter dropdown mở sẵn → một nút mở panel.
2. Mobile scaffold → shell bottom tabs và các màn hình có ID ở mục 3.
3. Prototype model gộp trạng thái → adapter status/conclusion tách biệt, có attempt/job/evidence/command outcome.
4. Chuẩn hóa prototype theo palette blue/teal/violet, Inter, spacing và shape của main; thêm monospace cho log sau khi kiểm assets.
5. Phân tích mẫu và audit phiên → giữ nhãn mẫu cho tới khi có tích hợp thật, không bỏ nhãn chỉ vì đã có giao diện.

Cập nhật này chỉ thay tài liệu thiết kế; không sửa ứng dụng, đổi Firebase, gửi dữ liệu cho AI hoặc deploy. File chuẩn là docs/DESIGN.md; DESIGN.md ở gốc chỉ dẫn tới file chuẩn.
