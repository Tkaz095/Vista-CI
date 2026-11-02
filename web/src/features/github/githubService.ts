import { auth } from '../../lib/firebase'

export interface GitHubRepo {
  id: string
  fullName: string
  htmlUrl: string
  defaultBranch: string
  private: boolean
}
export interface WorkflowRun {
  id: number
  repo: string
  title: string
  workflow: string
  branch: string
  sha: string
  actor: string
  status: string
  conclusion: string | null
  createdAt: string
  attempt: number
}
export interface WorkflowJob {
  id: number
  name: string
  status: string
  conclusion: string | null
  steps: { name: string; number: number; status: string; conclusion: string | null }[]
}

// Remove the legacy browser credential. GitHub tokens now stay in the backend vault.
export function clearGitHub() {
  try {
    sessionStorage.removeItem('vista.github.session.v1')
  } catch {
    /* Storage unavailable. */
  }
}
clearGitHub()
export class GitHubConnectionError extends Error {
  readonly code: string
  readonly retryAt?: number
  constructor(code: string, message: string, retryAt?: number) {
    super(message)
    this.code = code
    this.retryAt = retryAt
  }
}
async function backendRequest(path: string, signal?: AbortSignal, method = 'GET') {
  const user = auth.currentUser
  if (!user)
    throw new GitHubConnectionError('FIREBASE_AUTH_REQUIRED', 'Đăng nhập Vista để đọc GitHub.')
  const response = await fetch(path, {
    method,
    headers: { Authorization: `Bearer ${await user.getIdToken()}` },
    signal,
    cache: 'no-store',
    redirect: 'error',
  })
  if (auth.currentUser?.uid !== user.uid)
    throw new GitHubConnectionError('ACCOUNT_CHANGED', 'Phiên tài khoản đã thay đổi.')
  if (!response.ok) {
    let retryAt: number | undefined
    let code = 'GITHUB_REQUEST_FAILED',
      message = `Không đọc được GitHub (HTTP ${response.status}).`
    if (response.headers.get('content-type')?.includes('application/json')) {
      const detail = (await response.json()) as {
        code?: string
        message?: string
        retryAt?: number
      }
      code = detail.code ?? code
      message = detail.message ?? message
      if (Number.isFinite(detail.retryAt)) retryAt = detail.retryAt
    } else if (response.headers.get('content-type')?.startsWith('text/plain'))
      message = await response.text()
    throw new GitHubConnectionError(code, message, retryAt)
  }
  return response
}
let connecting: Promise<void> | undefined
export function connectGitHub(includePrivate = false): Promise<void> {
  if (includePrivate) return Promise.reject(new Error('Repo private chưa thuộc phạm vi hiện tại.'))
  if (connecting) return connecting
  const uid = auth.currentUser?.uid
  if (!uid) return Promise.reject(new Error('Đăng nhập Vista trước khi kết nối GitHub.'))
  // Open synchronously from the button gesture so async authentication does not block the popup.
  const popup = window.open('about:blank', '_blank', 'popup=yes,width=640,height=760')
  if (!popup) return Promise.reject(new Error('Cho phép popup cho Vista rồi kết nối GitHub lại.'))
  connecting = new Promise<void>((resolve, reject) => {
    const abort = new AbortController()
    const cleanup = () => {
      clearTimeout(deadline)
      clearInterval(closed)
      window.removeEventListener('message', receive)
      abort.abort()
      popup.close()
      connecting = undefined
    }
    const finish = (error?: Error) => {
      cleanup()
      if (error) reject(error)
      else resolve()
    }
    const receive = (event: MessageEvent) => {
      if (
        event.origin !== window.location.origin ||
        event.source !== popup ||
        event.data?.type !== 'vista-github-connected'
      )
        return
      if (auth.currentUser?.uid !== uid) {
        finish(new Error('Phiên tài khoản đã thay đổi.'))
        return
      }
      if (!event.data.ok) {
        finish(
          new Error(
            typeof event.data.message === 'string'
              ? event.data.message
              : 'Chưa kết nối được GitHub.',
          ),
        )
        return
      }
      finish()
    }
    window.addEventListener('message', receive)
    const closed = setInterval(() => {
      if (popup.closed) finish(new Error('Cửa sổ GitHub đã đóng trước khi hoàn tất kết nối.'))
    }, 500)
    const deadline = setTimeout(
      () => finish(new Error('Phiên kết nối GitHub đã hết thời gian. Thử lại.')),
      600000,
    )
    void backendRequest(
      '/api/github-session?action=start',
      AbortSignal.any([abort.signal, AbortSignal.timeout(30000)]),
      'POST',
    )
      .then(async (response) => {
        const data = (await response.json()) as { authorizeUrl?: string }
        const destination = new URL(data.authorizeUrl ?? '')
        if (
          destination.origin !== 'https://github.com' ||
          destination.pathname !== '/login/oauth/authorize'
        )
          throw new Error('Backend trả địa chỉ kết nối không hợp lệ.')
        if (abort.signal.aborted) return
        popup.location.replace(destination.href)
      })
      .catch((error) => {
        if (!abort.signal.aborted)
          finish(error instanceof Error ? error : new Error('Chưa mở được GitHub.'))
      })
  })
  return connecting
}
async function dataRequest(parameters: Record<string, string>, signal?: AbortSignal) {
  const response = await backendRequest(
    `/api/github-data?${new URLSearchParams(parameters)}`,
    signal,
  )
  if (!response.headers.get('content-type')?.includes('application/json'))
    throw new GitHubConnectionError(
      'INVALID_RESPONSE',
      'API backend chưa được phục vụ. Khởi động lại npm run dev hoặc kiểm tra Vercel Function.',
    )
  return response.json() as Promise<{ data: unknown; more: boolean }>
}
export async function fetchGitHubRepos(
  page: number,
  signal?: AbortSignal,
): Promise<{ repos: GitHubRepo[]; more: boolean }> {
  const { data, more } = await dataRequest({ kind: 'repos', page: String(page) }, signal)
  if (!Array.isArray(data)) throw new Error('Dữ liệu GitHub không hợp lệ.')
  const repos: GitHubRepo[] = data.flatMap((row) => {
    if (
      !row ||
      !Number.isSafeInteger(row.id) ||
      row.id <= 0 ||
      typeof row.full_name !== 'string' ||
      typeof row.default_branch !== 'string' ||
      row.private !== false
    )
      return []
    return [
      {
        id: String(row.id),
        fullName: row.full_name,
        htmlUrl: `https://github.com/${row.full_name}`,
        defaultBranch: row.default_branch,
        private: false,
      },
    ]
  })
  return { repos, more }
}
function validateRun(repo: string, id: number, attempt: number) {
  if (
    !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repo) ||
    !Number.isSafeInteger(id) ||
    id <= 0 ||
    !Number.isSafeInteger(attempt) ||
    attempt <= 0
  )
    throw new Error('Định danh lần chạy không hợp lệ.')
}
export async function fetchWorkflowRuns(
  repo: string,
  page: number,
  branch: string,
  status: string,
  signal: AbortSignal,
) {
  validateRun(repo, 1, 1)
  const { data, more } = await dataRequest(
    { kind: 'runs', repo, page: String(page), branch: branch.trim(), status },
    signal,
  )
  if (
    !data ||
    typeof data !== 'object' ||
    !('workflow_runs' in data) ||
    !Array.isArray(data.workflow_runs)
  )
    throw new Error('Dữ liệu CI/CD không hợp lệ.')
  return { runs: parseRuns(repo, data.workflow_runs), more }
}
function parseRuns(repo: string, rows: Record<string, unknown>[]): WorkflowRun[] {
  return rows.flatMap((row: Record<string, unknown>) => {
    if (
      !row ||
      !Number.isSafeInteger(row.id) ||
      typeof row.created_at !== 'string' ||
      !Number.isFinite(Date.parse(row.created_at))
    )
      return []
    const actor = row.actor as { login?: string } | null
    return [
      {
        id: row.id as number,
        repo,
        title: String(row.display_title ?? row.name ?? 'Workflow'),
        workflow: String(row.name ?? 'Workflow'),
        branch: String(row.head_branch ?? '—'),
        sha: String(row.head_sha ?? ''),
        actor: String(actor?.login ?? '—'),
        status: String(row.status ?? 'unknown'),
        conclusion: typeof row.conclusion === 'string' ? row.conclusion : null,
        createdAt: row.created_at,
        attempt: Number(row.run_attempt ?? 1),
      },
    ]
  })
}
export async function fetchWorkflowRun(run: WorkflowRun, signal: AbortSignal) {
  validateRun(run.repo, run.id, run.attempt)
  const { data } = await dataRequest(
    { kind: 'run', repo: run.repo, run: String(run.id), attempt: String(run.attempt) },
    signal,
  )
  if (!data || typeof data !== 'object') throw new Error('Dữ liệu lần chạy không hợp lệ.')
  const result = parseRuns(run.repo, [data as Record<string, unknown>])[0]
  if (!result || result.id !== run.id || result.attempt !== run.attempt)
    throw new Error('GitHub trả sai lần chạy hoặc lần thử.')
  return result
}
export async function fetchRunJobs(run: WorkflowRun, page: number, signal: AbortSignal) {
  validateRun(run.repo, run.id, run.attempt)
  const { data, more } = await dataRequest(
    {
      kind: 'jobs',
      repo: run.repo,
      run: String(run.id),
      attempt: String(run.attempt),
      page: String(page),
    },
    signal,
  )
  if (!data || typeof data !== 'object' || !('jobs' in data) || !Array.isArray(data.jobs))
    throw new Error('Dữ liệu job không hợp lệ.')
  const jobs: WorkflowJob[] = data.jobs.flatMap((job: Record<string, unknown>) => {
    if (!job || !Number.isSafeInteger(job.id) || Number(job.id) <= 0) return []
    return [
      {
        id: job.id as number,
        name: String(job.name ?? 'Job'),
        status: String(job.status ?? 'unknown'),
        conclusion: typeof job.conclusion === 'string' ? job.conclusion : null,
        steps: Array.isArray(job.steps)
          ? job.steps.flatMap((step: Record<string, unknown>) =>
              !step || !Number.isSafeInteger(step.number)
                ? []
                : [
                    {
                      name: String(step.name ?? 'Step'),
                      number: step.number as number,
                      status: String(step.status ?? 'unknown'),
                      conclusion: typeof step.conclusion === 'string' ? step.conclusion : null,
                    },
                  ],
            )
          : [],
      },
    ]
  })
  return { jobs, more }
}
export async function fetchJobLog(repo: string, jobId: number, signal: AbortSignal) {
  validateRun(repo, jobId, 1)
  const response = await backendRequest(
    `/api/github-job-log?${new URLSearchParams({ repo, job: String(jobId) })}`,
    signal,
  )
  if (!response.headers.get('content-type')?.startsWith('text/plain'))
    throw new Error(
      'API log chưa được phục vụ. Chạy lại npm run dev hoặc kiểm tra Vercel Function.',
    )
  return {
    text: await response.text(),
    truncated: response.headers.get('X-Vista-Truncated') === 'true',
  }
}

export interface GitHubConnectionInfo {
  connected: boolean
  state: string
  login?: string
  expiresAt?: number
  refreshExpiresAt?: number
  updatedAt?: number
  lastRefreshedAt?: number
  refreshCount?: number
  automaticRefresh?: boolean
}
export async function fetchConnectionInfo(signal?: AbortSignal): Promise<GitHubConnectionInfo> {
  return (await backendRequest('/api/github-session?action=info', signal)).json()
}
export async function refreshConnectionInfo(signal?: AbortSignal): Promise<GitHubConnectionInfo> {
  await backendRequest('/api/github-session?action=status', signal)
  return fetchConnectionInfo(signal)
}
export async function disconnectGitHub(): Promise<{ message: string; revoked: boolean }> {
  const response = await backendRequest(
    '/api/github-session?action=disconnect',
    AbortSignal.timeout(30000),
    'POST',
  )
  window.dispatchEvent(new Event('vista-github-connection'))
  return response.json()
}
