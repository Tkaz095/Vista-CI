import type { WorkflowRun, Workspace } from './model'

// Explicit fixtures for reviewing navigation. None are fetched GitHub runs or AI output.
export const demoWorkspaces: Workspace[] = [
  { id: 'vista', name: 'Vista', description: 'Mobile và web trong cùng một không gian làm việc.', repositories: [
    { id: 'mobile', name: 'demo/vista-mobile', description: 'Flutter · Android' },
    { id: 'web', name: 'demo/vista-web', description: 'React · Web' },
  ] },
  { id: 'sandbox', name: 'Sandbox', description: 'Workspace trống để bắt đầu một dự án khác.', repositories: [] },
]

export const demoRuns: WorkflowRun[] = [
  { key: 'sample-108-1', workspaceId: 'vista', repositoryId: 'mobile', workflow: 'Android build', runId: 'sample-108', attempt: 1,
    branch: 'feat/login', sha: 'a31b92f', status: 'failure', startedAt: '2026-11-01T09:20:00+07:00', duration: '2m 14s', triggerActor: 'Minh', pullRequest: { number: 12, author: 'Minh' },
    steps: [{ name: 'Checkout', status: 'success' }, { name: 'Install dependencies', status: 'success' }, { name: 'Analyze Dart', status: 'failure' }, { name: 'Build APK', status: 'cancelled' }],
    log: ['[Mẫu] Flutter analyze', 'Analyzing vista_mobile...', 'error • Undefined name \'authRepository\' • lib/features/auth/login_view_model.dart:24:7', '1 issue found.', 'Process completed with exit code 1.'],
    exampleDiagnosis: { kind: 'code', summary: 'Dart analysis báo tên authRepository chưa được định nghĩa. Workflow dừng trước khi build APK.', evidence: "Undefined name 'authRepository' • lib/features/auth/login_view_model.dart:24:7", location: 'lib/features/auth/login_view_model.dart:24:7', suggestions: ['Kiểm tra khai báo và tên biến authRepository trong ViewModel.', 'Kiểm tra dependency được truyền vào constructor và các import liên quan.', 'Sau khi sửa, tạo commit và chạy lại kiểm tra.'] } },
  { key: 'sample-107-1', workspaceId: 'vista', repositoryId: 'web', workflow: 'Web build', runId: 'sample-107', attempt: 1,
    branch: 'main', sha: 'bc728f1', status: 'success', startedAt: '2026-11-01T08:50:00+07:00', duration: '1m 32s', triggerActor: 'An',
    steps: [{ name: 'Checkout', status: 'success' }, { name: 'Install dependencies', status: 'success' }, { name: 'Build web', status: 'success' }],
    log: ['[Mẫu] npm run build', 'tsc -b && vite build', 'Build completed successfully.'] },
  { key: 'sample-106-1', workspaceId: 'vista', repositoryId: 'mobile', workflow: 'Android build', runId: 'sample-106', attempt: 1,
    branch: 'main', sha: 'ef612d8', status: 'failure', startedAt: '2026-10-31T17:15:00+07:00', duration: '3m 08s', triggerActor: 'An',
    steps: [{ name: 'Checkout', status: 'success' }, { name: 'Install dependencies', status: 'failure' }],
    log: ['[Mẫu] Resolving dependencies...', 'SocketException: Connection timed out while fetching packages.', 'Process completed with exit code 1.'],
    exampleDiagnosis: { kind: 'transient', summary: 'Log ghi nhận kết nối tải package bị timeout. Có thể là sự cố mạng tạm thời; chưa đủ dữ liệu để xác định nguyên nhân gốc.', evidence: 'SocketException: Connection timed out while fetching packages.', suggestions: ['Kiểm tra trạng thái dịch vụ package và kết nối runner.', 'Có thể thử chạy lại nếu không có cấu hình mạng sai đã biết.'] } },
  { key: 'sample-105-1', workspaceId: 'vista', repositoryId: 'web', workflow: 'Web build', runId: 'sample-105', attempt: 1,
    branch: 'feat/workspaces', sha: 'a982cb6', status: 'in_progress', startedAt: '2026-11-01T09:25:00+07:00', duration: 'Đang chạy', triggerActor: 'Linh', pullRequest: { number: 9, author: 'Linh' },
    steps: [{ name: 'Checkout', status: 'success' }, { name: 'Build web', status: 'in_progress' }], log: ['[Mẫu] npm run build', 'Building production bundle...'] },
  { key: 'sample-104-1', workspaceId: 'vista', repositoryId: 'mobile', workflow: 'Android build', runId: 'sample-104', attempt: 1,
    branch: 'main', sha: '732ac19', status: 'queued', startedAt: '2026-11-01T09:26:00+07:00', duration: 'Chờ runner', triggerActor: 'Minh',
    steps: [{ name: 'Build APK', status: 'queued' }], log: ['[Mẫu] Waiting for an available runner...'] },
  { key: 'sample-103-1', workspaceId: 'vista', repositoryId: 'web', workflow: 'Web deploy', runId: 'sample-103', attempt: 1,
    branch: 'main', sha: '1bb736a', status: 'failure', startedAt: '2026-10-31T16:00:00+07:00', duration: '1m 45s', triggerActor: 'Linh',
    steps: [{ name: 'Build web', status: 'success' }, { name: 'Deploy', status: 'failure' }],
    log: ['[Mẫu] Deploying website...', 'Error: Missing deployment credentials.', 'Process completed with exit code 1.'],
    exampleDiagnosis: { kind: 'configuration', summary: 'Bước deploy thiếu credential. Chạy lại ngay có thể gặp cùng lỗi nếu chưa sửa cấu hình.', evidence: 'Error: Missing deployment credentials.', suggestions: ['Kiểm tra secret và quyền cấp cho workflow deploy.', 'Không đưa nội dung credential vào log hoặc bình luận PR.'] } },
]
