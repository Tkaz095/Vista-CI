import { RunDetail } from './RunDetail'
import { UiIcon } from './UiIcon'
import { canAutoRetry, describeFailure, refreshDelay, useAutoRefresh } from './useAutoRefresh'
import { useEffect, useMemo, useRef, useState } from 'react'
import { onSnapshot } from 'firebase/firestore'
import { repoQuery } from '../workspaces/workspaceService'
import { fetchWorkflowRuns } from '../github/githubService'
import type { WorkflowRun } from '../github/githubService'

const runLabels: Record<string, string> = {
  queued: 'Đang chờ',
  in_progress: 'Đang chạy',
  completed: 'Đã hoàn thành',
  success: 'Thành công',
  failure: 'Thất bại',
  cancelled: 'Đã hủy',
  timed_out: 'Hết thời gian',
  skipped: 'Bỏ qua',
  neutral: 'Trung lập',
  action_required: 'Cần xử lý',
  waiting: 'Chờ phê duyệt',
  pending: 'Đang chờ',
  requested: 'Đã yêu cầu',
}
export function CicdScreen({
  workspaceId,
  active,
  initialRepo = '',
  onRepoChange,
}: {
  workspaceId: string
  active: boolean
  initialRepo?: string
  onRepoChange: (repo: string) => void
}) {
  const [feed, setFeed] = useState<{
    repos: string[]
    loading: boolean
    error: string
  }>({ repos: [], loading: true, error: '' })
  useEffect(() => {
    const timeout = setTimeout(
      () =>
        setFeed({
          repos: [],
          loading: false,
          error: 'Chưa nhận được repo từ máy chủ. Hãy chọn lại workspace để thử lại.',
        }),
      15000,
    )
    const stop = onSnapshot(
      repoQuery(workspaceId),
      { includeMetadataChanges: true },
      (snapshot) => {
        if (snapshot.metadata.fromCache || snapshot.metadata.hasPendingWrites) return
        clearTimeout(timeout)
        setFeed({
          repos: [...new Set(snapshot.docs.map((doc) => String(doc.data().fullName ?? '')))].sort(),
          loading: false,
          error: '',
        })
      },
      () => {
        clearTimeout(timeout)
        setFeed({
          repos: [],
          loading: false,
          error: 'Không đọc được repo trong workspace. Kiểm tra mạng và quyền Firestore.',
        })
      },
    )
    return () => {
      clearTimeout(timeout)
      stop()
    }
  }, [workspaceId])
  return (
    <section className="ci-page" aria-labelledby="ci-title">
      <div className="ci-page-heading">
        <div>
          <span className="ci-eyebrow">
            <UiIcon name="activity" /> GitHub Actions
          </span>
          <h1 id="ci-title">Theo dõi CI/CD</h1>
          <p>Từ lần chạy đầu tiên đến kết quả cuối cùng, trong một không gian.</p>
        </div>
        <span className="ci-source">
          <span /> Dữ liệu từ GitHub
        </span>
      </div>
      {!active ? (
        <p>Workspace đang xóa. Chọn workspace đang hoạt động.</p>
      ) : feed.loading ? (
        <p role="status">Đang tải repo…</p>
      ) : feed.error ? (
        <p role="alert">{feed.error}</p>
      ) : !feed.repos.length ? (
        <p>Workspace chưa có repo. Thêm repo tại tab Workspace.</p>
      ) : (
        <Runs
          key={JSON.stringify(feed.repos)}
          repos={feed.repos}
          initialRepo={initialRepo}
          onRepoChange={onRepoChange}
        />
      )}
    </section>
  )
}
type Page = {
  runs: WorkflowRun[]
  next: number
  more: boolean
  error: string
  code: string
  retryAt?: number
}
function Runs({
  repos,
  initialRepo,
  onRepoChange,
}: {
  repos: string[]
  initialRepo: string
  onRepoChange: (repo: string) => void
}) {
  const [repo, setRepo] = useState(() => (repos.includes(initialRepo) ? initialRepo : '')),
    [branch, setBranch] = useState(''),
    [status, setStatus] = useState('')
  return (
    <>
      <div className="ci-toolbar">
        <label className="live-picker ci-repo-picker">
          <span>
            <UiIcon name="repo" /> Repository
          </span>
          <select
            value={repo}
            onChange={(e) => {
              setRepo(e.target.value)
              onRepoChange(e.target.value)
            }}
          >
            <option value="">Tất cả repo ({repos.length})</option>
            {repos.map((name) => (
              <option key={name}>{name}</option>
            ))}
          </select>
        </label>
        <details className="ci-filters">
          <summary>
            <UiIcon name="filter" /> Bộ lọc
            {(branch || status) && (
              <span className="ci-filter-count">{Number(!!branch) + Number(!!status)}</span>
            )}
          </summary>
          <form
            className="live-form"
            onSubmit={(e) => {
              e.preventDefault()
              const fields = new FormData(e.currentTarget)
              setBranch(String(fields.get('branch') ?? '').trim())
              setStatus(String(fields.get('status') ?? ''))
              const panel = e.currentTarget.closest('details')
              if (panel) {
                panel.open = false
                panel.querySelector('summary')?.focus()
              }
            }}
          >
            <label>
              Branch chính xác
              <input
                name="branch"
                placeholder="Ví dụ: main"
                key={`branch/${branch}`}
                defaultValue={branch}
              />
            </label>
            <label>
              Trạng thái / kết quả
              <select name="status" key={`status/${status}`} defaultValue={status}>
                <option value="">Tất cả</option>
                {[
                  'queued',
                  'in_progress',
                  'completed',
                  'success',
                  'failure',
                  'cancelled',
                  'timed_out',
                ].map((s) => (
                  <option key={s} value={s}>
                    {runLabels[s]}
                  </option>
                ))}
              </select>
            </label>
            <button className="auth-secondary" type="submit">
              Áp dụng
            </button>
          </form>
        </details>
      </div>
      {(branch || status) && (
        <div className="ci-applied">
          <span className="ci-chip">
            <UiIcon name="filter" /> {branch || 'Mọi branch'}
          </span>
          {status && <span className="ci-chip">{runLabels[status]}</span>}
          <button
            className="auth-secondary"
            onClick={() => {
              setBranch('')
              setStatus('')
            }}
          >
            Xóa bộ lọc
          </button>
        </div>
      )}
      <RunFeed
        key={JSON.stringify([repo, branch, status])}
        repos={repo ? [repo] : repos}
        branch={branch}
        status={status}
      />
    </>
  )
}
function RunFeed({ repos, branch, status }: { repos: string[]; branch: string; status: string }) {
  const [selectedRun, setSelectedRun] = useState<WorkflowRun | null>(null)
  const [pages, setPages] = useState<Record<string, Page>>({}),
    [busy, setBusy] = useState(false),
    [updated, setUpdated] = useState(''),
    [failures, setFailures] = useState(0)
  const controller = useRef<AbortController | null>(null),
    alive = useRef(true),
    running = useRef(false)
  const current = useRef(pages)
  useEffect(() => {
    current.current = pages
  }, [pages])
  const runs = useMemo(
    () =>
      Object.values(pages)
        .flatMap((p) => p.runs)
        .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt)),
    [pages],
  )
  async function load(mode: 'reset' | 'refresh' | 'more' | 'auto') {
    if (running.current) return
    running.current = true
    setBusy(true)
    const abort = new AbortController()
    controller.current = abort
    const previous = current.current
    const targets = repos.filter((repo) =>
      mode === 'auto'
        ? canAutoRetry(previous[repo]?.code ?? '')
        : mode !== 'more' || !previous[repo] || previous[repo].more || previous[repo].error,
    )
    let cursor = 0,
      failed = false,
      succeeded = false
    await Promise.all(
      Array.from({ length: Math.min(3, targets.length) }, async () => {
        while (cursor < targets.length && !abort.signal.aborted) {
          const repo = targets[cursor++],
            old = previous[repo]
          const start = mode === 'more' ? (old?.next ?? 1) : 1
          const end =
            mode === 'refresh' || mode === 'auto' ? Math.max(1, (old?.next ?? 2) - 1) : start
          try {
            let incoming: WorkflowRun[] = [],
              lastPage = start,
              more = true
            for (let page = start; page <= end && more; page++) {
              const result = await fetchWorkflowRuns(
                repo,
                page,
                branch,
                status,
                AbortSignal.any([abort.signal, AbortSignal.timeout(25000)]),
              )
              incoming = [...incoming, ...result.runs]
              more = result.more
              lastPage = page
            }
            if (alive.current && !abort.signal.aborted) {
              succeeded = true
              setPages((value) => ({
                ...value,
                [repo]: {
                  runs: [
                    ...new Map(
                      [...(mode === 'more' ? (old?.runs ?? []) : []), ...incoming].map((run) => [
                        run.id,
                        run,
                      ]),
                    ).values(),
                  ],
                  next: lastPage + 1,
                  more,
                  error: '',
                  code: '',
                },
              }))
            }
          } catch (cause) {
            if (alive.current && !abort.signal.aborted) {
              failed = true
              setPages((value) => ({
                ...value,
                [repo]: {
                  runs: old?.runs ?? [],
                  next: old?.next ?? 1,
                  more: old?.more ?? true,
                  ...describeFailure(cause),
                },
              }))
            }
          }
        }
      }),
    )
    running.current = false
    if (alive.current && !abort.signal.aborted) {
      setBusy(false)
      setFailures((count) => (failed ? count + 1 : 0))
      if (succeeded) setUpdated(new Date().toLocaleTimeString('vi-VN'))
    }
  }
  useEffect(() => {
    alive.current = true
    const timer = setTimeout(() => void load('reset'), 0)
    const reconnect = () => void load('refresh')
    window.addEventListener('vista-github-connection', reconnect)
    return () => {
      alive.current = false
      clearTimeout(timer)
      window.removeEventListener('vista-github-connection', reconnect)
      controller.current?.abort()
    }
    // A new feed is mounted whenever the repository or filters change.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])
  const errors = Object.entries(pages).filter(([, page]) => page.error)
  const baseDelay = runs.some((run) => run.status !== 'completed') ? 15000 : 60000
  const retryable = errors.filter(([, page]) => canAutoRetry(page.code))
  const retryAt = Math.max(0, ...retryable.map(([, page]) => page.retryAt ?? 0))
  const delay =
    errors.length - retryable.length === repos.length
      ? null
      : refreshDelay(
          baseDelay,
          retryable.map(([, page]) => page),
          failures,
        )
  useAutoRefresh(() => load('auto'), selectedRun ? null : delay, retryAt)
  const hasData = Object.values(pages).some((page) => !page.error || page.runs.length > 0)
  const stats = [
    { label: 'Lần chạy đã tải', count: runs.length, tone: 'neutral', icon: 'activity' as const },
    {
      label: 'Thành công',
      count: runs.filter((run) => run.conclusion === 'success').length,
      tone: 'success',
      icon: 'check' as const,
    },
    {
      label: 'Thất bại / hết giờ',
      count: runs.filter((run) => ['failure', 'timed_out'].includes(run.conclusion ?? '')).length,
      tone: 'failure',
      icon: 'cross' as const,
    },
    {
      label: 'Đang chạy',
      count: runs.filter((run) => run.status === 'in_progress').length,
      tone: 'running',
      icon: 'activity' as const,
    },
  ]
  if (selectedRun)
    return (
      <RunDetail
        key={`${selectedRun.repo}/${selectedRun.id}/${selectedRun.attempt}`}
        run={selectedRun}
        onClose={() => {
          setSelectedRun(null)
          void load('refresh')
        }}
      />
    )
  return (
    <>
      <div className="ci-stats" aria-label="Tóm tắt các lần chạy đã tải">
        {stats.map((stat) => (
          <div className={`ci-stat ci-tone-${stat.tone}`} key={stat.label}>
            <div>
              <span>{stat.label}</span>
              <strong>{hasData ? stat.count : '—'}</strong>
            </div>
            <span className="ci-stat-icon">
              <UiIcon name={stat.icon} />
            </span>
          </div>
        ))}
      </div>
      <div className="ci-list-panel" aria-busy={busy}>
        <div className="ci-list-heading">
          <div>
            <h2>
              Lịch sử chạy <span className="ci-count">{runs.length}</span>
            </h2>
            <p>{updated ? `Lần cập nhật thành công ${updated}` : 'Chưa cập nhật thành công'}</p>
            <p>
              {delay === null
                ? 'Tạm dừng tự cập nhật: xử lý lỗi bên dưới rồi bấm Làm mới.'
                : `Tự cập nhật mỗi ${Math.ceil(delay / 1000)} giây khi tab đang mở.`}
            </p>
          </div>
          <button
            className="auth-secondary ci-refresh"
            disabled={busy}
            onClick={() => void load('refresh')}
          >
            <UiIcon name="refresh" /> {busy ? 'Đang tải…' : 'Làm mới'}
          </button>
        </div>
        {errors.length > 0 && (
          <div className="ci-error" role="alert">
            <UiIcon name="alert" />
            <div>
              <strong>Chưa tải được {errors.length} repository</strong>
              <p>Dữ liệu đã tải được giữ lại. Nguyên nhân:</p>
              {errors.map(([repo, page]) => (
                <p key={repo}>
                  <strong>{repo}</strong> — {page.error} <small>({page.code})</small>
                </p>
              ))}
              {errors.some(([, page]) =>
                ['SERVER_SETUP_REQUIRED', 'FIREBASE_BACKEND_UNAVAILABLE'].includes(page.code),
              ) && (
                <p>
                  Đây là cấu hình backend. Logout/login không sửa được lỗi này; kiểm tra
                  web/.env.local và khởi động lại Vite.
                </p>
              )}
            </div>
          </div>
        )}
        {busy && !runs.length && (
          <div className="ci-loading" role="status">
            <span className="ci-eyebrow">Đang tải lịch sử chạy…</span>
            {[1, 2, 3].map((i) => (
              <div className="ci-skeleton" key={i}>
                <span />
                <div>
                  <i />
                  <i />
                </div>
              </div>
            ))}
          </div>
        )}
        {!busy && !runs.length && !errors.length && Object.keys(pages).length === repos.length && (
          <div className="ci-empty">
            <span className="ci-empty-icon">
              <UiIcon name="activity" />
            </span>
            <h3>Chưa có lần chạy phù hợp</h3>
            <p>
              {branch || status
                ? 'Thử xóa bộ lọc hoặc chọn repository khác.'
                : 'Khi repository chạy GitHub Actions, kết quả sẽ tự xuất hiện tại đây khi tab đang mở.'}
            </p>
          </div>
        )}
        <div className="ci-runs">
          {runs.map((run) => (
            <RunRow key={`${run.repo}/${run.id}`} run={run} onOpen={() => setSelectedRun(run)} />
          ))}
        </div>
        <footer className="ci-list-footer">
          <p>
            Hiển thị kết quả đã tải · Tối đa 20 lần chạy/repo mỗi lượt.
            <br />
            Sắp xếp theo thời gian tạo; tải thêm để xem lịch sử cũ hơn.
          </p>
          {repos.some((repo) => !pages[repo] || pages[repo].more || pages[repo].error) && (
            <button className="auth-secondary" disabled={busy} onClick={() => void load('more')}>
              {errors.length ? 'Tải thêm / thử lại' : 'Tải thêm lịch sử'}
              <UiIcon name="arrow" />
            </button>
          )}
        </footer>
      </div>
    </>
  )
}
function RunRow({ run, onOpen }: { run: WorkflowRun; onOpen: () => void }) {
  const result = run.conclusion ?? run.status
  const tone =
    result === 'success'
      ? 'success'
      : ['failure', 'timed_out'].includes(result)
        ? 'failure'
        : result === 'in_progress'
          ? 'running'
          : ['action_required', 'waiting'].includes(result)
            ? 'warning'
            : 'neutral'
  const icon =
    tone === 'success'
      ? 'check'
      : tone === 'failure'
        ? 'cross'
        : tone === 'running'
          ? 'activity'
          : tone === 'warning'
            ? 'alert'
            : result === 'cancelled'
              ? 'pause'
              : 'clock'
  const date = new Date(run.createdAt)
  return (
    <article className={`ci-run ci-tone-${tone}`}>
      <span className="ci-run-icon">
        <UiIcon name={icon} />
      </span>
      <div className="ci-run-main">
        <div className="ci-run-title">
          <h3>{run.title}</h3>
          <span className="ci-attempt">Lần thử {run.attempt}</span>
        </div>
        <p className="ci-run-repo">
          <UiIcon name="repo" />
          <span>{run.repo}</span>
          <span className="ci-meta-divider">/</span>
          <span>{run.workflow}</span>
        </p>
        <div className="ci-run-meta">
          <span title={`Branch: ${run.branch}`}>
            <UiIcon name="branch" />
            {run.branch}
          </span>
          <span title={run.sha}>
            <UiIcon name="commit" />
            <code>{run.sha.slice(0, 7)}</code>
          </span>
          <span>
            <UiIcon name="user" />
            {run.actor}
          </span>
        </div>
      </div>
      <div className="ci-run-outcome">
        <span className="ci-status">
          <UiIcon name={icon} />
          {runLabels[result] ?? result}
        </span>
        <time dateTime={run.createdAt} title={date.toLocaleString('vi-VN')}>
          {date.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' })} ·{' '}
          {date.toLocaleDateString('vi-VN')}
        </time>
        <span className="ci-run-phase">{runLabels[run.status] ?? run.status}</span>
      </div>
      <button
        className="auth-secondary ci-log-link"
        onClick={onOpen}
        aria-label={`Xem chi tiết và log ${run.title}, ${run.repo}, lần thử ${run.attempt}`}
      >
        <span>Chi tiết / log</span>
        <UiIcon name="arrow" />
      </button>
    </article>
  )
}
