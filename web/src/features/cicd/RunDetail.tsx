import { useEffect, useRef, useState } from 'react'
import { fetchJobLog, fetchRunJobs, fetchWorkflowRun } from '../github/githubService'
import type { WorkflowJob, WorkflowRun } from '../github/githubService'
import { UiIcon } from './UiIcon'
import { describeFailure, refreshDelay, useAutoRefresh } from './useAutoRefresh'

const labels: Record<string, string> = {
  success: 'Thành công',
  failure: 'Thất bại',
  timed_out: 'Hết thời gian',
  completed: 'Đã hoàn thành',
  in_progress: 'Đang chạy',
  queued: 'Đang chờ',
  cancelled: 'Đã hủy',
  skipped: 'Bỏ qua',
  neutral: 'Trung lập',
  waiting: 'Đang chờ',
}
const failure = (value: string | null) => value === 'failure' || value === 'timed_out'
function message(error: unknown) {
  return error instanceof DOMException && error.name === 'AbortError'
    ? 'Quá thời gian tải dữ liệu. Hãy thử lại.'
    : error instanceof Error
      ? error.message
      : 'Không tải được dữ liệu GitHub.'
}

export function RunDetail({ run: initialRun, onClose }: { run: WorkflowRun; onClose: () => void }) {
  const [run, setRun] = useState(initialRun)
  const [jobs, setJobs] = useState<WorkflowJob[]>([]),
    [selected, setSelected] = useState<number | null>(null),
    [busy, setBusy] = useState(false),
    [error, setError] = useState<ReturnType<typeof describeFailure> | null>(null),
    [failures, setFailures] = useState(0),
    [updated, setUpdated] = useState(''),
    [more, setMore] = useState(false)
  const page = useRef(0),
    controller = useRef<AbortController | null>(null),
    alive = useRef(true),
    running = useRef(false)
  async function load(reset = false) {
    if (running.current) return
    running.current = true
    setBusy(true)
    const abort = new AbortController()
    controller.current = abort
    try {
      const fresh = await fetchWorkflowRun(
        initialRun,
        AbortSignal.any([abort.signal, AbortSignal.timeout(25000)]),
      )
      if (!alive.current || abort.signal.aborted) return
      setRun(fresh)
      const start = reset ? 1 : page.current + 1
      const end = reset ? Math.max(1, page.current) : start
      let incoming: WorkflowJob[] = [],
        more = true,
        lastPage = start
      for (let next = start; next <= end && more; next++) {
        const result = await fetchRunJobs(
          initialRun,
          next,
          AbortSignal.any([abort.signal, AbortSignal.timeout(25000)]),
        )
        incoming = [...incoming, ...result.jobs]
        more = result.more
        lastPage = next
      }
      if (!alive.current || abort.signal.aborted) return
      page.current = lastPage
      setMore(more)
      setJobs((previous) => [
        ...new Map([...(reset ? [] : previous), ...incoming].map((job) => [job.id, job])).values(),
      ])
      setSelected((previous) => {
        if (previous !== null && (!reset || incoming.some((job) => job.id === previous)))
          return previous
        return (incoming.find((job) => failure(job.conclusion)) ?? incoming[0])?.id ?? null
      })
      setError(null)
      setFailures(0)
      setUpdated(new Date().toLocaleTimeString('vi-VN'))
    } catch (cause) {
      if (alive.current && !abort.signal.aborted) {
        setError(describeFailure(cause))
        setFailures((count) => count + 1)
      }
    } finally {
      running.current = false
      if (alive.current) setBusy(false)
    }
  }
  useEffect(() => {
    alive.current = true
    const start = setTimeout(() => void load(true), 0)
    return () => {
      alive.current = false
      clearTimeout(start)
      controller.current?.abort()
    }
    // Mounted with repo/run/attempt identity by the parent.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])
  const baseDelay =
    run.status !== 'completed' || jobs.some((job) => job.status !== 'completed') ? 10000 : 60000
  const delay = refreshDelay(baseDelay, error ? [error] : [], failures)
  useAutoRefresh(() => load(true), delay, error && 'retryAt' in error ? (error.retryAt ?? 0) : 0)
  const job = jobs.find((item) => item.id === selected)
  return (
    <section className="ci-detail" aria-label="Chi tiết lần chạy">
      <div className="ci-detail-top">
        <button className="auth-secondary" onClick={onClose}>
          ← Lịch sử chạy
        </button>
        <a
          className="ci-log-link"
          href={`https://github.com/${run.repo}/actions/runs/${run.id}/attempts/${run.attempt}`}
          target="_blank"
          rel="noreferrer"
        >
          Mở GitHub <UiIcon name="external" />
        </a>
      </div>
      <div className="ci-detail-heading">
        <span className="ci-eyebrow">
          {run.repo} · Lần thử {run.attempt}
        </span>
        <h2>{run.title}</h2>
        <p>
          {run.workflow} · {run.branch} · <code>{run.sha.slice(0, 7)}</code> ·{' '}
          {labels[run.conclusion ?? run.status] ?? run.conclusion ?? run.status}
        </p>
      </div>
      <div className="ci-list-heading">
        <div>
          <h3>Job và step</h3>
          <p>
            {updated ? `Cập nhật thành công ${updated}. ` : ''}
            {delay === null
              ? 'Tạm dừng tự cập nhật; xử lý lỗi rồi thử lại.'
              : `Tự cập nhật mỗi ${Math.ceil(delay / 1000)} giây khi tab đang mở.`}
          </p>
        </div>
        <button className="auth-secondary" disabled={busy} onClick={() => void load(true)}>
          <UiIcon name="refresh" />
          {busy ? 'Đang tải…' : 'Cập nhật job'}
        </button>
      </div>
      {error && (
        <div className="ci-error" role="alert">
          {error.error} <small>({error.code})</small>
        </div>
      )}
      {!busy && !error && !jobs.length && (
        <p className="ci-empty">GitHub chưa trả về job cho lần thử này.</p>
      )}
      {busy && (
        <p className="ci-detail-loading" role="status">
          Đang tải job…
        </p>
      )}
      <div className="ci-detail-grid">
        <aside className="ci-jobs" aria-label="Danh sách job">
          {jobs.map((item) => (
            <button
              key={item.id}
              className={`ci-job ${failure(item.conclusion) ? 'ci-job-failed' : ''}`}
              aria-pressed={item.id === selected}
              onClick={() => setSelected(item.id)}
            >
              <UiIcon
                name={
                  failure(item.conclusion)
                    ? 'cross'
                    : item.conclusion === 'success'
                      ? 'check'
                      : 'clock'
                }
              />
              <span>
                <strong>{item.name}</strong>
                <small>
                  {labels[item.conclusion ?? item.status] ?? item.conclusion ?? item.status}
                </small>
              </span>
            </button>
          ))}
          {more && (
            <button className="auth-secondary" disabled={busy} onClick={() => void load()}>
              Tải thêm job
            </button>
          )}
        </aside>
        {job && (
          <div className="ci-job-content">
            <h3>{job.name}</h3>
            <ol className="ci-steps">
              {job.steps.map((step) => (
                <li className={failure(step.conclusion) ? 'ci-step-failed' : ''} key={step.number}>
                  <UiIcon
                    name={
                      failure(step.conclusion)
                        ? 'cross'
                        : step.conclusion === 'success'
                          ? 'check'
                          : 'clock'
                    }
                  />
                  <span>
                    {step.number}. {step.name}
                  </span>
                  <small>
                    {labels[step.conclusion ?? step.status] ?? step.conclusion ?? step.status}
                  </small>
                </li>
              ))}
            </ol>
            {!job.steps.length && <p>GitHub chưa có thông tin step.</p>}
            {failure(job.conclusion) && (
              <div className="ci-failure-summary">
                <strong>Step lỗi theo kết quả GitHub</strong>
                {job.steps
                  .filter((step) => failure(step.conclusion))
                  .map((step) => (
                    <p key={step.number}>
                      {step.number}. {step.name} —{' '}
                      {labels[step.conclusion ?? ''] ?? step.conclusion}
                    </p>
                  ))}
                {!job.steps.some((step) => failure(step.conclusion)) && (
                  <p>GitHub báo job thất bại nhưng chưa chỉ rõ step. Xem log gốc bên dưới.</p>
                )}
                <p>Đây là dữ liệu GitHub, chưa có agent phân tích nguyên nhân.</p>
              </div>
            )}
            <JobLog key={`${job.id}/${job.status}`} repo={run.repo} job={job} />
          </div>
        )}
      </div>
    </section>
  )
}
function JobLog({ repo, job }: { repo: string; job: WorkflowJob }) {
  const [result, setResult] = useState<{ text: string; truncated: boolean } | null>(null),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(''),
    [attempt, setAttempt] = useState(0),
    [wrap, setWrap] = useState(false)
  useEffect(() => {
    if (job.status !== 'completed') return
    let alive = true
    const abort = new AbortController(),
      timer = setTimeout(() => abort.abort(), 30000)
    const start = setTimeout(() => {
      setBusy(true)
      setError('')
      setResult(null)
      void fetchJobLog(repo, job.id, abort.signal)
        .then((data) => {
          if (alive) setResult(data)
        })
        .catch((cause) => {
          if (alive) setError(message(cause))
        })
        .finally(() => {
          clearTimeout(timer)
          if (alive) setBusy(false)
        })
    }, 0)
    return () => {
      alive = false
      clearTimeout(timer)
      clearTimeout(start)
      abort.abort()
    }
  }, [repo, job.id, job.status, attempt])
  const errors =
    result?.text
      .split('\n')
      .filter((line) => /##\[error\]/i.test(line))
      .slice(0, 12) ?? []
  return (
    <section className="ci-job-log" aria-label="Log gốc từ GitHub">
      <div className="ci-detail-top">
        <h3>Log gốc</h3>
        <button
          className="auth-secondary"
          disabled={busy || job.status !== 'completed'}
          onClick={() => setAttempt((value) => value + 1)}
        >
          <UiIcon name="refresh" />
          Tải lại log
        </button>
      </div>
      {job.status !== 'completed' && (
        <p>Trạng thái job và step đang tự cập nhật. Log đầy đủ sẽ được tải khi job hoàn tất.</p>
      )}
      {busy && <p role="status">Đang tải log từ GitHub…</p>}
      {error && (
        <div className="ci-error" role="alert">
          {error}
        </div>
      )}
      {!!errors.length && (
        <div className="ci-failure-summary">
          <strong>Dòng được GitHub đánh dấu lỗi</strong>
          <pre>{errors.join('\n')}</pre>
          <small>Trích nguyên văn từ phần log đã tải, không phải kết luận AI.</small>
        </div>
      )}
      {result && (
        <>
          <div className="ci-log-toolbar">
            <span>{result.text.split('\n').length.toLocaleString('vi-VN')} dòng đã tải</span>
            <button
              className="auth-secondary"
              aria-pressed={wrap}
              onClick={() => setWrap((value) => !value)}
            >
              {wrap ? 'Tắt xuống dòng' : 'Tự xuống dòng'}
            </button>
          </div>
          {result.truncated && (
            <p className="live-notice">
              Log lớn: đang hiển thị 2 MiB đầu, có thể chưa chứa lỗi ở cuối. Mở GitHub để xem toàn
              bộ.
            </p>
          )}
          {result.text ? (
            <pre
              className={`ci-log-viewer ${wrap ? 'ci-log-wrap' : ''}`}
              tabIndex={0}
              aria-label={`Nội dung log job ${job.name}`}
            >
              {result.text}
            </pre>
          ) : (
            <p>GitHub trả log rỗng.</p>
          )}
        </>
      )}
    </section>
  )
}
