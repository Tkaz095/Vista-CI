# Vista CI v0.4 — Workspace, CI/CD và agent đọc log

Ngày 01/11/2026. Phạm vi nghiệp vụ hiện hành theo yêu cầu mới nhất. Phạm vi này thay thế giả định một repository và các hạn chế tương ứng trong tài liệu v0.3.

## 1. Luồng sản phẩm

Workspace chứa thông tin dự án và nhiều repository. Người dùng xem lịch sử CI/CD, trạng thái, kết quả và logs; yêu cầu agent phân tích lỗi; xem dẫn chứng và hướng xử lý; chọn chạy lại, tạo issue hoặc bình luận vào PR. Mọi thao tác tích hợp phải có audit.

Agent ở bản đầu là thành phần phân tích log. Không bao gồm hệ thống điều phối nhiều coding agents, tự sửa source hoặc tự tạo commit/PR. Không đưa luồng bản ứng viên demo/checklist kiểm thử vào phạm vi này.

## 2. Chức năng

### Quyết định thiết kế mới nhất

- Mobile dùng bottom tab làm điều hướng chính; web dùng header phía trên, không dùng sidebar làm điều hướng chính.
- Bộ lọc thu gọn thành một nút nhỏ, mở phần chọn khi cần. Vị trí/cách mở cụ thể do DESIGN.md đề xuất, vùng chạm phải đủ dùng.
- Đã có [DESIGN.md chính thức v1.0](../../DESIGN.md) do Codex tổng hợp từ bản agent và đối chiếu repo/overview, cùng [báo cáo sàng lọc](10-sang-loc-design.md). Chưa tạo FLUTTER_HANDOVER.md; Codex phụ trách tài liệu này sau khi người dùng xem và duyệt thiết kế, rồi triển khai theo thiết kế đã duyệt.
- File Vista_CI_Project_Overview.docx do bạn của người dùng cung cấp là nguồn đối chiếu. Gemini, Cloud Functions, auto-triage và khóa quyền retry bằng AI trong file đó chưa phải các quyết định triển khai đã chốt. Không áp dụng nguyên mã giả hoặc schema của file nếu mâu thuẫn yêu cầu hiện hành.
- Prototype web hiện tại vẫn có sidebar; thay đổi navigation theo DESIGN.md chưa triển khai trong lượt tổng hợp tài liệu, không xem prototype là chuẩn cuối cùng.

| Mã | Chức năng | Phạm vi |
| --- | --- | --- |
| AUTH | Firebase Email/Password, hồ sơ Admin/Member, session/logout | Kế thừa quyết định trước |
| WS | Danh sách workspace, thông tin dự án, các repo thuộc workspace | Nhiều repo; cô lập quyền theo workspace |
| RUN | Đồng bộ run ID/attempt/repo/workflow/branch/SHA/status/conclusion/timestamps | Bao gồm queued, đang chạy và kết quả kết thúc; không chỉ completed |
| HISTORY | Lọc repo, Pass/Fail/trạng thái, branch và phân trang | Sắp thời điểm nguồn; cursor ở tích hợp thật |
| LOG | Xem job/step và log của đúng run/attempt | Có thiếu quyền, log hết hạn/không có và giới hạn tải |
| AGENT | Phân tích theo yêu cầu, tóm tắt nguyên nhân, dẫn chứng, vị trí và đề xuất | Không chắc thì nói rõ, không đoán file/dòng |
| ACT | Chạy mới workflow, chạy lại run thất bại | Backend kiểm tra quyền và allowlist; người dùng chọn hành động |
| FEEDBACK | Soạn, xem trước, tạo issue hoặc comment PR | Giữ cả hai chức năng; không âm thầm bỏ issue khỏi phạm vi |
| AUDIT | Ai làm gì, lúc nào, repo/run/PR/commit nào, kết quả yêu cầu | Phân biệt actor, tác giả PR và tác giả commit |
| OUTPUT | Liên kết artifact và deployment | Hai loại đầu ra riêng; quyền và hết hạn riêng |
| FCM | Push cho build quan trọng | Giữ sau MVP theo quyết định trước, chưa đổi thành bắt buộc |

Tạo/kết nối repo tùy ý, luồng cấp installation và quản trị workspace chi tiết cần chốt khi tích hợp. Có thể triển khai demo ban đầu bằng các repo đã được chủ sở hữu cài GitHub App. Không coi repo nhập bằng text là đã kết nối.

## 3. Quy tắc phân tích và xử lý

- `code`: lỗi source hoặc test có bằng chứng. Gợi ý tạo issue/comment, người dùng kiểm tra bản nháp trước khi đăng.
- `transient`: dấu hiệu lỗi mạng/runner/dịch vụ tạm thời. Gợi ý chạy lại, không cam kết chạy lại sẽ hết lỗi.
- `configuration`: thiếu secret, sai SDK/quyền hoặc cấu hình. Hướng dẫn sửa trước khi thử lại, không mặc định lỗi ngoài code đều có thể retry ngay.
- `unknown`: log chưa đủ hoặc có nhiều nguyên nhân. Giữ log gốc và đề xuất bước kiểm tra tiếp.

MVP dùng log và metadata làm đầu vào. Chỉ bổ sung file source liên quan tại đúng commit khi có nhu cầu được chốt; không gửi toàn bộ repo mặc định. Log là dữ liệu không tin cậy, không được biến thành chỉ dẫn để agent chạy lệnh.

Mỗi nhận định cần dẫn chứng log. Vị trí file/dòng là tùy chọn, chỉ hiện khi có bằng chứng. Kết quả gắn đúng workspace/repo/run/attempt/job và phiên bản phân tích. Không tự đăng comment hoặc issue từ kết quả agent.

Khi không gắn được PR chắc chắn: không chọn bừa PR; người dùng có thể chọn tạo issue. Chống gửi trùng theo request ID và action/target. Bấm gửi, GitHub nhận lệnh và run hoàn tất là các trạng thái khác nhau.

Audit dùng để truy vết, không kết luận “code ẩu” từ số run fail. Chủ PR không tự là người gây ra lỗi. Có thể hiển thị các thông tin này cạnh nhau nhưng phải giữ đúng ý nghĩa nguồn.

## 4. Ràng buộc agent và backend

Người dùng chưa chốt Agents API, ưu tiên phương án miễn phí. Tách adapter nhà cung cấp ra khỏi UI/domain. Chưa thêm dịch vụ trả phí, key hoặc lệnh gửi log. Phải đánh giá quota, cách dùng và chi phí thực trước khi chọn; không hứa miễn phí vô hạn.

Backend phải xác thực Firebase identity/active/membership/capability cho mọi request. Admin Vista không tự là chủ repo. Credential GitHub/AI giữ phía server. Phân quyền ở UI không thay backend/Rules.

Các bước tích hợp GitHub/AI phải trình bày cách làm trước khi nối theo yêu cầu làm việc của người dùng. Không tự thay billing hoặc deploy môi trường ngoài.

## 5. Dữ liệu mục tiêu

```text
users/{uid}
workspaces/{workspaceId}
  members/{uid}
  repositories/{repositoryId}
    runs/{runId_attempt}
      analyses/{analysisId}
  commands/{requestId}
  audit/{eventId}
```

Đây là schema đề xuất, chưa tạo trên Firebase. Log đầy đủ lấy qua backend có quyền, phân trang/giới hạn theo job; không nhét log lớn hoặc bí mật vào run document. Dữ liệu đối chiếu dùng repository ID nguồn, không chỉ repo name. Dữ liệu kết quả/analysis/audit chỉ được ghi qua quy trình tin cậy.

## 6. Các bước triển khai

1. Chốt luồng bằng UI web và kiểu dữ liệu. Dữ liệu mẫu phải nhận diện rõ, không giả đăng nhập hay gửi lệnh thành công.
2. Nối Auth/profile và membership/workspace thật; xác định Rules, không mở database toàn bộ.
3. Nối backend GitHub, đồng bộ queued/running/completed, lấy log và mapping PR đúng nguồn. Trình bày auth/credential/runtime/chi phí trước bước này.
4. Chạy mới/chạy lại, server audit, allowlist và chống request trùng.
5. Chọn agent theo ưu tiên miễn phí; nối đọc log, dẫn chứng, phân loại và giới hạn chi phí.
6. Tạo issue/comment từ bản nháp đã được người dùng duyệt, lưu kết quả/link và xử lý trùng.
7. Áp dụng luồng đã thống nhất lên Flutter MVVM, hoàn thiện web/mobile và chuẩn bị demo.
8. FCM sau MVP.

Chưa chốt quyền chi tiết Admin/Member cho từng thao tác, dịch vụ chạy backend, Agents API và quyền viết GitHub. Không hiểu yêu cầu phạm vi là đã duyệt mọi lựa chọn tích hợp.

## 7. Hiện trạng lần triển khai đầu

- Web: giao diện đăng nhập xem trước, workspace nhiều repo, bảng run có lọc/phân trang, job/step/log, phân tích mẫu có dẫn chứng, bản nháp chạy mới/chạy lại/issue/comment và audit xem trước trong phiên.
- Có fixture workspace trống và nhiều loại trạng thái lỗi để xem luồng. Tên repo/run trong UI đều là mẫu.
- Kết quả phân tích là ví dụ soạn sẵn, không gọi AI. Các nút gửi GitHub và đăng nhập Firebase chưa kết nối, không báo thành công giả.
- `WorkspaceGateway` xác định ranh giới tích hợp; chưa có implementation thật.
- Firebase config Web do người dùng thêm được giữ nguyên giá trị, export đối tượng app và bỏ khởi tạo Analytics chưa cần dùng.
- Mobile hiện vẫn là scaffold cũ. Chưa cập nhật Firebase Console, Rules, workflow, Google Docs hoặc Sheet trong lần triển khai UI này.
- Chưa chạy build/lint/tests hoặc kiểm thử runtime theo yêu cầu không tự chạy tests. Tài liệu này không phải báo cáo nghiệm thu.

Các Google Docs/Sheet v0.3 đã tạo trước đó đang là snapshot cũ, chưa phản ánh phạm vi này. Không dùng chúng để kết luận đã có multi-repo/agent integration.

## Cập nhật triển khai 01/11/2026

Membership đọc workspace ở MVP hiện dùng `memberUids` (array UID) trong document workspace cha. Đề xuất `members/{uid}` ở mục 5 chưa triển khai; không tạo đồng thời hai nguồn membership. Schema/Rules và hướng dẫn Firebase hiện hành nằm trong `12-mobile-auth-workspaces.md`. Quyền chi tiết cho hành động GitHub sẽ được chốt khi có backend.
