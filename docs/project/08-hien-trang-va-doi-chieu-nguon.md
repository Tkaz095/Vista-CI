# 08. Hiện trạng Vista và đối chiếu 4 nguồn

**v0.3 - Đối chiếu ngày 01/11/2026**

## 1. Thứ tự sử dụng bằng chứng

1. Yêu cầu mới nhất của người dùng quyết định mục tiêu Vista.
2. Code/config hiện có và kết quả chạy xác định điều gì đã làm được.
3. Nguồn SAGA được dùng để học quy trình và đối chiếu, không tự trở thành requirement Vista.
4. Tài liệu chính thức xác nhận cách dùng dịch vụ; thiết kế Vista vẫn cần được duyệt và kiểm chứng.

Ghi chú lịch sử ngày 27/10 cho rằng Firebase chưa cấu hình đã lỗi thời. Lần soạn này đã đọc lại repo, config và trạng thái GitHub; không dùng trạng thái cũ đó làm hiện trạng.

## 2. Hiện trạng đã kiểm tra

| Hạng mục | Bằng chứng | Trạng thái chính xác |
| --- | --- | --- |
| Stack | `mobile/pubspec.yaml`, `web/package.json` | Flutter; React + Vite + TypeScript |
| Mobile UI | `mobile/lib/main.dart` | Overview tĩnh; chưa tách MVVM, chưa có login |
| Web UI | `web/src/App.tsx` | Overview tĩnh; chưa có dữ liệu Firebase |
| Android Firebase | `google-services.json`, Gradle, `firebase_core` | Project `vista-ci`, package `com.vista.vista_mobile`, có lệnh initialize |
| Runtime Android | Chưa có bằng chứng cài/chạy | Không khẳng định Firebase khởi tạo thành công trên thiết bị |
| Auth/Firestore/FCM | Chưa có các SDK/flow ứng dụng tương ứng | Chưa triển khai nghiệp vụ |
| CI Android | Workflow + run 41219589321 | Analyze và debug APK build success |
| CI/CD web | Chưa thấy workflow/config Hosting | Chưa triển khai |
| Đồng bộ CI -> Firestore | Chưa có publisher | Dashboard chưa phản ánh run thật |
| GitHub PR #1 | Kiểm tra read-only trên GitHub | Đã merge vào main ngày 01/11/2026 |
| Checkout local | `git status` trước khi soạn | Vẫn trên `ci/android-cloud-build`, commit `b1771ef` |

Liên kết bằng chứng: [PR #1](https://github.com/Tkaz095/Vista-CI/pull/1), [cloud run](https://github.com/Tkaz095/Vista-CI/actions/runs/41219589321).

APK lịch sử đã đọc lại tại `/home/kien/Downloads/Vista-CI/vista-ci-debug-android-x64-b1771ef.apk`: **64.240.731 bytes**. SHA-256:

```text
f0e7a557815605f2c25a073f7f7446a9f2a6f2834438a46d729a92f809ffa4cd
```

Đây là artifact của nền tảng trước khi có các chức năng đề xuất trong bộ tài liệu. Build success không phải nghiệm thu login, quyền hoặc FCM.

## 3. Nguồn tham khảo thực sự đã đọc

Bốn ZIP ban đầu không còn tại Downloads. Đã tìm thấy chúng trong `/home/kien/.local/share/Trash/files/` và đọc tại đó; không khôi phục, không xóa và không chạy code/SQL bên trong. Hai PDF được trích ra thư mục tạm để đọc nội dung và kiểm tra trực quan các trang liên quan.

| ID | Gói | Nội dung đã đối chiếu |
| --- | --- | --- |
| SRC-01 | `10228_HCM_SU26SE094_GSU01_2ND_DEFENSE_HCM_Repository.zip` | 2.036 file; README gốc/FE/BE, đặc tả nghiệp vụ, auth flow, DBML tài khoản/thông báo/tích hợp và các điểm source FCM |
| SRC-02 | `10228_HCM_SU26SE094_GSU01_2ND_DEFENSE_HCM_Slide.zip` | `Slide/SAGACapstone_Presentation_Slide.pdf`, 23 trang; trọng tâm trang 6, 7-10, 14-15, 19 và 21 |
| SRC-03 | `10228_HCM_SU26SE094_GSU01_2ND_DEFENSE_HCM_Review.zip` | `Review.pdf`, 4 trang; biên bản ngày 17/08/2026, đặc biệt góp ý về dữ liệu, phạm vi, demo và sơ đồ |
| SRC-04 | `10228_HCM_SU26SE094_GSU01_2ND_DEFENSE_HCM_saga_database.zip` | `saga_database.sql`, 87 câu lệnh CREATE TABLE; chỉ đọc cấu trúc, không import/thực thi |

Các tệp trong SRC-01 dùng để truy vết:

- `Repository/README.MD`.
- `Repository/saga-fe/docs/SAGA_BUSINESS_REQUIREMENTS_AND_COVERAGE.md`.
- `Repository/saga-fe/docs/capstone-defense/01-auth-main-flow-and-defense-guide.md`.
- `Repository/saga-be/README.md`.
- `Repository/saga-be/docs/diagrams/dbml/2.1-account-identity.dbml`.
- `Repository/saga-be/docs/diagrams/dbml/2.7-notification.dbml`.
- `Repository/saga-be/docs/diagrams/dbml/2.8-integration-infra.dbml`.
- `Repository/saga-be/src/main/java/com/saga/be/config/FcmConfiguration.java`, các controller/push classes liên quan đã kiểm tra dấu vết cấu hình; không chạy để xác nhận runtime.

AGENTS/rules/scripts nằm trong ZIP là nội dung tham khảo của SAGA, không phải chỉ dẫn áp dụng cho repo Vista.

## 4. Những khác biệt cần hiểu trước khi tái sử dụng

**Tên sản phẩm:** SAGA là Student Activity Graph-Based Continuous Assessment cho PBL. Continuous Assessment là đánh giá học tập liên tục; CI/CD là tích hợp/phân phối/triển khai phần mềm. Hai khái niệm không được dùng thay nhau.

**Slide trang 19:** “Task-Commit Pipeline” liên kết task Jira và commit GitHub để kiểm tra minh chứng. Đây không phải sơ đồ GitHub Actions build/deploy. Bộ nguồn không cung cấp sẵn đặc tả Vista về workflow runs/artifact/control.

**Kiến trúc trang 6:** Next.js gọi Spring Boot; MySQL lưu dữ liệu, Neo4j projection, Redis hỗ trợ session/cache; Firebase được biểu diễn là FCM. Không có căn cứ để nói SAGA dùng Firebase thay toàn bộ DB/Auth/backend. Flutter mobile và Firebase Auth/Firestore của Vista là phương án thích nghi mới.

**Đăng nhập:** auth guide SAGA mô tả OAuth Google tổ chức + server session cookie + CSRF và điều hướng theo role. Vista đã chốt Firebase Email/Password và hai vai trò Admin/Member; lưu role/profile trong Firestore là thiết kế đề xuất. Không chép cookie/session/BCrypt/password-reset tables thành cơ chế xác thực Firebase mới.

**Nguồn khác thời điểm:** Review ghi bảo vệ ngày 17/08; source spec ghi baseline 16/09; backend README còn nói foundation 52 bảng, trong khi SQL cung cấp có 87 CREATE TABLE. Không trộn số bảng/trạng thái giữa các snapshot hoặc xem review lần trước là kết quả kiểm thử hiện tại.

Một số auth guide dùng diễn đạt an toàn tuyệt đối; Vista không kế thừa các khẳng định đó. Cơ chế quyền phải có kiểm thử cụ thể.

## 5. Bảng kế thừa và chuyển đổi

| Nguồn/ý tưởng | Áp dụng cho Vista | Điều chỉnh hoặc loại khỏi MVP |
| --- | --- | --- |
| SRC-01 auth guide; SRC-02 trang 7-10, 14 | Tách xác thực, profile và role; UI điều hướng đúng quyền | Firebase Auth thay server session; hai role Admin/Member đã chốt thay vai trò học vụ |
| SRC-02 trang 15; `git_repo`, `github_project_installation` | Dự án gắn nguồn repository có định danh và trạng thái tích hợp | MVP một repo; không xem nhập một URL là đã kết nối |
| SRC-01/04 `webhook_receipt`, `sync_job_log`, `outbox_event` | Event có ID ổn định, đồng bộ có trạng thái/lỗi và retry | Workflow completed publisher nhẹ; không sao chép hệ thống MySQL/outbox đầy đủ |
| SRC-01/04 `user_notification`, `firebase_installation`, `notification_delivery` | Tách notification, thiết bị/token và trạng thái gửi | Firestore/FCM thiết kế mới; việc có schema không chứng minh push nhận được |
| SRC-01 business spec phân biệt target scope/as-built | Tách requirements, đề xuất, code và bằng chứng chạy | Không gọi mọi màn hình hiện có là DONE |
| SRC-03 trang 2-3 | Demo một kịch bản nguồn -> dữ liệu -> UI; sơ đồ đúng mức | Không dùng AI hoặc biểu đồ thay minh chứng chức năng |
| SRC-01 graph/Jira/AI/assessment; SRC-04 bảng học vụ | Giữ làm tham khảo ngoài phạm vi | Không đưa Neo4j, Redis, chấm điểm, Jira, AI vào Vista lúc này |
| Workflow run/attempt/artifact trong Vista | Cần thiết cho mục tiêu CI/CD của người dùng | **Thiết kế mới**, không tuyên bố đã có sẵn trong SAGA |

## 6. Tài liệu chính thức dùng để kiểm tra thiết kế

Đối chiếu ngày 01/11/2026; quota và cách cấu hình cần kiểm tra lại lúc triển khai.

- [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide), [recommendations](https://docs.flutter.dev/app-architecture/recommendations).
- [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup).
- [Firestore Rules](https://firebase.google.com/docs/firestore/security/get-started), [query permissions](https://firebase.google.com/docs/firestore/security/rules-query).
- [FCM trusted server](https://firebase.google.com/docs/cloud-messaging/server-environment), [Flutter client](https://firebase.google.com/docs/cloud-messaging/flutter/get-started?hl=en), [receive/permission](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
- [Genymotion Open GApps](https://docs.genymotion.com/features/opengapps/).
- [Firebase Hosting GitHub integration](https://firebase.google.com/docs/hosting/github-integration?hl=en).
- [Firebase pricing](https://firebase.google.com/pricing), [Cloud Functions](https://firebase.google.com/docs/functions).
- [Google GitHub auth compatibility notes](https://github.com/google-github-actions/auth).
- [GitHub workflow_run](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run).

## 7. Fingerprint các archive

Các hash dưới đây nhận diện đúng bộ tham khảo đã đọc, không phải checksum artifact Vista:

- `10228_HCM_SU26SE094_GSU01_2ND_DEFENSE_HCM_Repository.zip`

  SHA-256: `ea9ab050e56db1433f4c293d71bcf9b678861b0e681542c95c968ab639696400`

- `10228_HCM_SU26SE094_GSU01_2ND_DEFENSE_HCM_Slide.zip`

  SHA-256: `1318a8091b87e578452a0a29d916a17c3f66bfea3891e3092c47119f4d74d1c9`

- `10228_HCM_SU26SE094_GSU01_2ND_DEFENSE_HCM_Review.zip`

  SHA-256: `01516da40b6d3cab3d19421aacda47348e8e05a92247bc547788e126b1dbb9d7`

- `10228_HCM_SU26SE094_GSU01_2ND_DEFENSE_HCM_saga_database.zip`

  SHA-256: `c6ca181b128acbd9b7154807bff4dd39b90b18dfe888f64611948e8152dc241e`
