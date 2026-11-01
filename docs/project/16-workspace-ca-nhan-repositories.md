# Phạm vi hiện hành — Workspace cá nhân và repository

Ngày 02/11/2026. Quyết định từ người dùng: tài khoản tự tạo workspace; trang Tài khoản hiển thị repo GitHub của tài khoản; tạo workspace và chọn các repo cần dùng; quản lý CRUD repo trong workspace. Dừng phạm vi triển khai tại đây.

## Quyền và luồng

- Một vai trò ứng dụng: `user`. Admin để giai đoạn sau.
- Người dùng đăng nhập GitHub; app tự tạo hồ sơ nếu thiếu theo bước 15.
- Người dùng không cần được thêm sẵn vào workspace để bắt đầu.
- Người dùng tự tạo workspace của mình và có thể tạo nhiều workspace.
- Quyền quản lý workspace dựa trên `ownerUid` trùng UID của phiên Firebase, không dựa trên role Admin.
- Chưa triển khai chia sẻ workspace, lời mời hoặc quản lý thành viên trong phạm vi này.

Luồng UI: Đăng nhập → Tài khoản / danh sách repo GitHub → Tạo workspace (tên, mô tả, chọn repo) → Workspace / quản lý danh sách repo.

## Chức năng

| Khu vực | Chức năng |
|---|---|
| Tài khoản | Hiển thị hồ sơ và danh sách repository từ GitHub mà tài khoản đã cấp quyền cho Vista truy cập |
| Tài khoản | Tải lại, tải thêm/phân trang để không dừng ở 50 repo; trạng thái tải/lỗi/chưa cấp quyền/trống rõ ràng |
| Workspace | Tự tạo với tên, mô tả và chọn repo; xem danh sách workspace của chính mình |
| Repo trong workspace | Thêm từ danh sách GitHub; không nhập một repo tùy ý rồi coi là đã kết nối |
| Repo trong workspace | Xem thông tin và link GitHub |
| Repo trong workspace | Sửa tên hiển thị/ghi chú hoặc cấu hình cục bộ của liên kết repo |
| Repo trong workspace | Gỡ liên kết repo khỏi workspace |

CRUD repo ở đây áp dụng cho **liên kết repo trong workspace**. Gỡ liên kết không xóa repo trên GitHub; sửa nhãn/ghi chú không đổi tên hay source GitHub. Một repo có thể được chọn trong nhiều workspace; không thêm trùng repo ID trong cùng workspace.

## Mô hình dữ liệu đề xuất để triển khai

```text
users/{uid}
  displayName, role: user, isActive

workspaces/{workspaceId}
  ownerUid, name, description, createdAt, updatedAt
  repositories/{githubRepositoryId}
    githubRepositoryId, fullName, htmlUrl, defaultBranch,
    displayName, note, addedAt, updatedAt
```

`ownerUid` bất biến sau khi tạo và được lấy từ Firebase session. Repository ID nguồn là khóa ổn định; fullName/link là metadata. Không lưu token GitHub hoặc Client Secret trong những document này.

Quyền dự kiến: tài khoản active tự tạo workspace có ownerUid của mình; chỉ chủ workspace đọc/sửa workspace và quản lý các liên kết repo bên trong. Query workspace bằng ownerUid. Thay thế mô hình memberUids của bước 12/15 cho workspace cá nhân; không tạo cơ chế đồng bộ hai nguồn quyền. Dữ liệu workspace cũ chưa có ownerUid cần đối chiếu và chuyển có chủ đích, không tự nhận quyền sở hữu từ việc có tên trong memberUids.

## Kết nối GitHub — chưa triển khai

Hiện OAuth/Firebase chỉ xử lý đăng nhập; code bỏ qua access token. Chưa có nguồn repo từ GitHub API, backend hay GitHub App installation. Danh sách account phải phản ánh quyền GitHub thực tế; không hứa thấy private/org repo khi chưa cấp đủ quyền. Cần trình bày phương án credential/quyền trước khi thay đổi tích hợp; người dùng tự thao tác cấu hình bên GitHub/Firebase.

Nguồn repo dùng chung cho web/Flutter. Web giữ header navigation; mobile giữ bottom tabs. Bản mẫu không phải dữ liệu repo thật. Không hiển thị CRUD thành công trước khi Firestore xác nhận.

## Thứ tự triển khai tiếp theo

1. Hoàn tất xử lý lỗi đọc hồ sơ hiện tại bằng việc đối chiếu Rules đang publish với đúng project/database và code đang chạy. Chưa có xác nhận người dùng đăng nhập lại thành công sau bước 15.
2. Đổi model và Rules từ membership sang ownerUid cho workspace cá nhân, thêm giao diện tạo workspace trên hai client.
3. Chốt cách cấp quyền GitHub lấy danh sách repo, trình bày bước cấu hình bên ngoài rồi tích hợp nguồn repo thật.
4. Hoàn thiện chọn repo và CRUD liên kết repo trong workspace, cập nhật trạng thái/lỗi trên hai client.

## Ngoài phạm vi hiện tại

Đồng bộ workflow/CI/CD/log, agent phân tích, rerun, issue/comment PR, audit, FCM, Admin, invitation hoặc chia sẻ workspace. Các phần này trong tài liệu 09–15 là định hướng cũ/để sau, không phải công việc cần triển khai ở mốc này.

## Trạng thái bản cập nhật này

Chỉ ghi lại phạm vi và phương án dữ liệu để đối chiếu. Chưa sửa runtime code/Rules cho ownerUid, chưa gọi GitHub API, chưa thay đổi Firebase/GitHub Console hoặc commit/push/deploy.
