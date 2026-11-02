import { GitHubConnection } from '../github/GitHubConnection'
import { UiIcon } from '../cicd/UiIcon'
import { CicdScreen } from '../cicd/CicdScreen'
import { useCallback, useEffect, useRef, useState } from 'react'
import type { FormEvent, ReactNode } from 'react'
import { onSnapshot } from 'firebase/firestore'
import type { Query, DocumentData } from 'firebase/firestore'
import type { VistaProfile } from '../auth/authService'
import { logout } from '../auth/authService'
import { GitHubAccount } from '../auth/GitHubAccount'
import { useGitHubRepos } from '../github/useGitHubRepos'
import type { GitHubRepo } from '../github/githubService'
import {
  addRepository,
  createWorkspace,
  editRepository,
  editWorkspace,
  removeRepository,
  removeWorkspace,
  repoQuery,
  workspaceError,
  workspaceQuery,
} from './workspaceService'
import './live-workspace.css'

type Row = DocumentData & { id: string }
function useFeed(source: Query) {
  const [rows, setRows] = useState<Row[]>([]),
    [loading, setLoading] = useState(true),
    [error, setError] = useState('')
  useEffect(() => {
    let active = true
    const timer = setTimeout(() => {
      if (active) {
        setError('Chưa nhận được dữ liệu từ máy chủ. Kiểm tra mạng rồi tải lại.')
        setLoading(false)
      }
    }, 15000)
    const stop = onSnapshot(
      source,
      { includeMetadataChanges: true },
      (snapshot) => {
        if (!active || snapshot.metadata.fromCache || snapshot.metadata.hasPendingWrites) return
        clearTimeout(timer)
        setError('')
        setLoading(false)
        setRows(snapshot.docs.map((doc) => ({ ...doc.data(), id: doc.id })))
      },
      (cause) => {
        if (active) {
          clearTimeout(timer)
          setRows([])
          setLoading(false)
          setError(workspaceError(cause))
        }
      },
    )
    return () => {
      active = false
      clearTimeout(timer)
      stop()
    }
  }, [source])
  return { rows, loading, error }
}
function RepoEditor({
  repo,
  uid,
  workspaceId,
  act,
  disabled,
  onOpen,
}: {
  onOpen: () => void
  repo: Row
  uid: string
  workspaceId: string
  act: (job: () => Promise<unknown>) => Promise<boolean>
  disabled: boolean
}) {
  const [editing, setEditing] = useState(false),
    [name, setName] = useState(String(repo.displayName)),
    [note, setNote] = useState(String(repo.note ?? ''))
  return (
    <article className="live-repo">
      <h3>
        <button className="live-repo-title" disabled={disabled} onClick={onOpen}>
          {String(repo.displayName)}
          <UiIcon name="arrow" />
        </button>
      </h3>
      <a href={`https://github.com/${String(repo.fullName)}`} target="_blank" rel="noreferrer">
        {String(repo.fullName)}
      </a>
      <p>{String(repo.note ?? '')}</p>
      <button className="auth-primary" disabled={disabled} onClick={onOpen}>
        <UiIcon name="activity" /> CI/CD và log
      </button>
      {editing ? (
        <form
          className="live-form"
          onSubmit={async (event) => {
            event.preventDefault()
            if (await act(() => editRepository(uid, workspaceId, repo.id, name, note)))
              setEditing(false)
          }}
        >
          <label>
            Nhãn hiển thị
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              maxLength={100}
              required
              disabled={disabled}
            />
          </label>
          <label>
            Ghi chú
            <textarea
              value={note}
              onChange={(e) => setNote(e.target.value)}
              maxLength={1000}
              disabled={disabled}
            />
          </label>
          <button type="submit" className="auth-primary" disabled={disabled}>
            Lưu
          </button>
          <button
            type="button"
            className="auth-secondary"
            disabled={disabled}
            onClick={() => setEditing(false)}
          >
            Hủy
          </button>
        </form>
      ) : (
        <div className="live-actions">
          <button
            type="button"
            className="auth-secondary"
            disabled={disabled}
            onClick={() => {
              setName(String(repo.displayName))
              setNote(String(repo.note ?? ''))
              setEditing(true)
            }}
          >
            Sửa
          </button>
          <button
            type="button"
            className="auth-secondary"
            disabled={disabled}
            onClick={() => {
              if (
                confirm(
                  `Gỡ ${repo.fullName} khỏi workspace? Repository trên GitHub được giữ nguyên.`,
                )
              )
                void act(() => removeRepository(uid, workspaceId, repo.id))
            }}
          >
            Gỡ repo
          </button>
        </div>
      )}
    </article>
  )
}
function WorkspaceDetail({
  workspace,
  uid,
  act,
  busy,
  onOpenRepo,
  onAddRepo,
  addingRepo,
  repoPicker,
}: {
  onOpenRepo: (repo: string) => void
  onAddRepo: () => void
  addingRepo: boolean
  repoPicker: ReactNode
  workspace: Row
  uid: string
  act: (job: () => Promise<unknown>) => Promise<boolean>
  busy: boolean
}) {
  const [source] = useState(() => repoQuery(workspace.id)),
    feed = useFeed(source)
  const [editing, setEditing] = useState(false),
    [name, setName] = useState(String(workspace.name)),
    [description, setDescription] = useState(String(workspace.description))
  const deleting = workspace.status === 'deleting'
  return (
    <section className="live-panel">
      <h2>{String(workspace.name)}</h2>
      <p>{String(workspace.description)}</p>
      {deleting && <p role="status">Workspace đang xóa. Nếu bị gián đoạn, bấm Tiếp tục xóa.</p>}
      {editing && !deleting && (
        <form
          className="live-form"
          onSubmit={async (event) => {
            event.preventDefault()
            if (await act(() => editWorkspace(uid, workspace.id, name, description)))
              setEditing(false)
          }}
        >
          <label>
            Tên workspace
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              maxLength={100}
              disabled={busy}
              required
            />
          </label>
          <label>
            Mô tả
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              maxLength={1000}
              disabled={busy}
            />
          </label>
          <button type="submit" className="auth-primary" disabled={busy}>
            Lưu
          </button>
          <button
            type="button"
            className="auth-secondary"
            onClick={() => setEditing(false)}
            disabled={busy}
          >
            Hủy
          </button>
        </form>
      )}
      <div className="live-actions">
        <button
          type="button"
          className="auth-secondary"
          disabled={busy || deleting}
          onClick={() => {
            setName(String(workspace.name))
            setDescription(String(workspace.description))
            setEditing(true)
          }}
        >
          Sửa workspace
        </button>
        <button
          type="button"
          className="auth-secondary"
          disabled={busy}
          onClick={() => {
            if (
              deleting ||
              confirm(
                `Xóa workspace “${workspace.name}” cùng các liên kết repo? Repository trên GitHub được giữ nguyên.`,
              )
            )
              void act(() => removeWorkspace(uid, workspace.id))
          }}
        >
          {deleting ? 'Tiếp tục xóa' : 'Xóa workspace'}
        </button>
      </div>
      <div className="ci-detail-top">
        <div>
          <h2>Repo trong workspace</h2>
          <p>Chọn repo để xem CI/CD, job và log lỗi.</p>
        </div>
        <button className="auth-primary" disabled={busy || deleting} onClick={onAddRepo}>
          {addingRepo ? 'Đóng danh sách repo' : '+ Thêm repository'}
        </button>
      </div>
      {addingRepo && !deleting && repoPicker}
      {feed.loading && <p role="status">Đang tải…</p>}
      {feed.error && <p role="alert">{feed.error}</p>}
      {!feed.loading && !feed.error && !feed.rows.length && (
        <p>Chưa có repo. Bấm Thêm repository để chọn từ GitHub.</p>
      )}
      <div className="live-grid">
        {feed.rows.map((repo) => (
          <RepoEditor
            key={repo.id}
            repo={repo}
            uid={uid}
            workspaceId={workspace.id}
            act={act}
            disabled={busy || deleting}
            onOpen={() => onOpenRepo(String(repo.fullName))}
          />
        ))}
      </div>
    </section>
  )
}
export function LiveWorkspace({ profile }: { profile: VistaProfile }) {
  const [attempt, setAttempt] = useState(0)
  return (
    <WorkspaceHome key={attempt} profile={profile} retry={() => setAttempt((value) => value + 1)} />
  )
}
function savedNavigation(uid: string): { tab: string; workspace: string; repo: string } {
  try {
    const value = JSON.parse(sessionStorage.getItem(`vista.navigation.${uid}`) ?? '{}')
    return {
      tab: ['workspace', 'cicd', 'account'].includes(value.tab) ? value.tab : 'workspace',
      workspace: typeof value.workspace === 'string' ? value.workspace : '',
      repo: typeof value.repo === 'string' ? value.repo : '',
    }
  } catch {
    return { tab: 'workspace', workspace: '', repo: '' }
  }
}
function WorkspaceHome({ profile, retry }: { profile: VistaProfile; retry: () => void }) {
  const [source] = useState(() => workspaceQuery(profile.uid)),
    feed = useFeed(source),
    github = useGitHubRepos()
  const [addingRepository, setAddingRepository] = useState(false)
  const [navigation] = useState(() => savedNavigation(profile.uid))
  const [tab, setTab] = useState(navigation.tab),
    [selectedId, setSelectedId] = useState(navigation.workspace),
    [ciRepo, setCiRepo] = useState(navigation.repo),
    [creating, setCreating] = useState(false)
  const [name, setName] = useState(''),
    [description, setDescription] = useState(''),
    [picked, setPicked] = useState<Set<string>>(new Set())
  const [filter, setFilter] = useState(''),
    [busy, setBusy] = useState(false),
    [linking, setLinking] = useState(false),
    [message, setMessage] = useState(''),
    [failed, setFailed] = useState(false)
  useEffect(() => {
    try {
      sessionStorage.setItem(
        `vista.navigation.${profile.uid}`,
        JSON.stringify({ tab, workspace: selectedId, repo: ciRepo }),
      )
    } catch {
      /* Tab persistence is optional if browser storage is disabled. */
    }
  }, [tab, selectedId, ciRepo, profile.uid])
  function openRepo(repo: string) {
    setCiRepo(repo)
    setTab('cicd')
  }
  const locked = busy || github.pending || linking
  const running = useRef(false),
    mounted = useRef(true)
  useEffect(() => {
    mounted.current = true
    return () => {
      mounted.current = false
    }
  }, [])
  const selected = feed.rows.find((row) => row.id === selectedId)
  const activeWorkspace = selected?.status === 'active'
  const act = useCallback(async (job: () => Promise<unknown>): Promise<boolean> => {
    if (running.current) return false
    running.current = true
    setBusy(true)
    setMessage('')
    setFailed(false)
    const slow = setTimeout(() => {
      if (mounted.current)
        setMessage(
          'Chưa nhận được xác nhận từ máy chủ. Vẫn đang chờ; vui lòng giữ kết nối và không gửi lại.',
        )
    }, 15000)
    try {
      await job()
      if (mounted.current) setMessage('Đã hoàn tất thao tác.')
      return true
    } catch (cause) {
      if (mounted.current) {
        setFailed(true)
        setMessage(workspaceError(cause))
      }
      return false
    } finally {
      clearTimeout(slow)
      running.current = false
      if (mounted.current) setBusy(false)
    }
  }, [])
  function toggle(id: string) {
    setPicked((previous) => {
      const next = new Set(previous)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }
  async function create(event: FormEvent) {
    event.preventDefault()
    let id = ''
    if (
      await act(async () => {
        id = await createWorkspace(
          profile.uid,
          name,
          description,
          github.repos.filter((repo) => picked.has(repo.id)),
        )
      })
    ) {
      if (!mounted.current) return
      setSelectedId(id)
      setCreating(false)
      setPicked(new Set())
      setName('')
      setDescription('')
      setTab('workspace')
    }
  }
  const repoItems = github.repos.filter((repo) =>
    repo.fullName.toLowerCase().includes(filter.toLowerCase()),
  )
  const addToSelectedWorkspace = useCallback(
    (repo: GitHubRepo) => {
      void act(() => addRepository(profile.uid, selectedId, repo))
    },
    [act, profile.uid, selectedId],
  )
  function githubPanel(selecting: boolean) {
    return (
      <section className="live-panel">
        <h2>Repository GitHub</h2>
        <p>
          Repo public thuộc tài khoản GitHub của bạn. Kết nối một lần để backend tự làm mới token;
          F5, mở lại web hoặc restart Vite không xóa kết nối đã lưu.
        </p>
        <div className="live-actions">
          <button
            type="button"
            className="auth-primary"
            disabled={locked}
            onClick={() => {
              setPicked(new Set())
              void github.load(true)
            }}
          >
            Kết nối GitHub tự động gia hạn
          </button>
          <button
            type="button"
            className="auth-secondary"
            disabled={locked}
            onClick={() => {
              setPicked(new Set())
              void github.load()
            }}
          >
            Tải lại repo
          </button>
        </div>
        {github.pending && <p role="status">Đang tải GitHub…</p>}
        {github.error && (
          <p role="alert" className="auth-error">
            {github.error}
          </p>
        )}
        <label>
          Tìm repo
          <input value={filter} onChange={(event) => setFilter(event.target.value)} />
        </label>
        <div className="live-repo-picker">
          {repoItems.map((repo: GitHubRepo) => (
            <article className="live-repo" key={repo.id}>
              {selecting ? (
                <label className="live-check">
                  <input
                    type="checkbox"
                    checked={picked.has(repo.id)}
                    onChange={() => toggle(repo.id)}
                    disabled={locked}
                  />
                  {repo.fullName}
                </label>
              ) : (
                <h3>{repo.fullName}</h3>
              )}
              <span className="live-badge">{repo.private ? 'Private' : 'Public'}</span>{' '}
              <a href={repo.htmlUrl} target="_blank" rel="noreferrer">
                Mở GitHub
              </a>
              {!selecting && (
                <button
                  type="button"
                  className="auth-secondary"
                  disabled={locked || !activeWorkspace}
                  onClick={() => addToSelectedWorkspace(repo)}
                >
                  Thêm vào workspace đã chọn
                </button>
              )}
            </article>
          ))}
        </div>
        {!github.pending && !github.error && !github.repos.length && (
          <p>
            {github.loaded
              ? 'Tài khoản GitHub chưa có repo public thuộc sở hữu trong danh sách này.'
              : 'Chưa tải repo. Bấm Kết nối GitHub hoặc Tải lại repo.'}
          </p>
        )}
        {github.more && (
          <button
            type="button"
            className="auth-secondary"
            disabled={locked}
            onClick={() => void github.load(false, false, true)}
          >
            Tải thêm repo
          </button>
        )}
      </section>
    )
  }
  return (
    <main className="auth-home live-app">
      <a className="live-skip" href="#vista-content">
        Đến nội dung chính
      </a>
      <header className="auth-header live-header">
        <span className="auth-brand">
          <span className="auth-brand-mark">
            <UiIcon name="activity" />
          </span>
          Vista<span className="live-brand-ci">CI</span>
        </span>
        <nav aria-label="Điều hướng chính">
          {[
            ['workspace', 'Workspace'],
            ['cicd', 'CI/CD'],
            ['account', 'Tài khoản'],
          ].map(([id, label]) => (
            <button
              type="button"
              className="live-nav"
              key={id}
              aria-current={tab === id ? 'page' : undefined}
              disabled={locked}
              onClick={() => setTab(id)}
            >
              <UiIcon
                name={id === 'workspace' ? 'workspace' : id === 'cicd' ? 'activity' : 'user'}
              />
              {label}
            </button>
          ))}
        </nav>
        <div className="live-user">
          <span className="live-avatar" aria-hidden="true">
            {profile.displayName.slice(0, 1).toUpperCase() || 'V'}
          </span>
          <span className="live-user-name">{profile.displayName}</span>
          <button
            type="button"
            className="auth-secondary"
            disabled={locked}
            onClick={() => void act(logout)}
          >
            Đăng xuất
          </button>
        </div>
      </header>
      <div id="vista-content" className="auth-home-content live-content" tabIndex={-1}>
        {message && (
          <p role={failed ? 'alert' : 'status'} className={failed ? 'auth-error' : 'live-notice'}>
            {message}
          </p>
        )}
        {feed.error && (
          <section role="alert" className="live-panel">
            <p>{feed.error}</p>
            <button type="button" className="auth-secondary" disabled={locked} onClick={retry}>
              Tải lại workspace
            </button>
          </section>
        )}
        {feed.loading && <p role="status">Đang tải workspace…</p>}
        <div className="live-workspace-heading">
          <div className="live-picker">
            <label htmlFor="workspace">
              <UiIcon name="workspace" /> Workspace hiện tại
            </label>
            <select
              id="workspace"
              disabled={locked || feed.loading}
              value={selected?.id ?? ''}
              onChange={(event) => {
                setSelectedId(event.target.value)
                setCiRepo('')
              }}
            >
              <option value="">Chọn workspace…</option>
              {feed.rows.map((row) => (
                <option key={row.id} value={row.id}>
                  {String(row.name)}
                  {row.status === 'deleting' ? ' (đang xóa)' : ''}
                </option>
              ))}
            </select>
          </div>
          <span className="live-context-note">
            {tab === 'cicd'
              ? 'Theo dõi các repository trong workspace của bạn'
              : tab === 'account'
                ? 'Quản lý hồ sơ và kết nối GitHub'
                : 'Không gian làm việc của bạn'}
          </span>
          {tab === 'workspace' && (
            <button
              type="button"
              className="auth-primary"
              disabled={locked || !!feed.error || feed.loading}
              onClick={() => {
                setCreating(true)
                setName('')
                setDescription('')
                setPicked(new Set())
                setTab('workspace')
              }}
            >
              Tạo workspace
            </button>
          )}
        </div>
        {creating && (
          <section className="live-panel">
            <h1>Tạo workspace</h1>
            <form className="live-form" onSubmit={create}>
              <label>
                Tên workspace
                <input
                  required
                  maxLength={100}
                  value={name}
                  disabled={locked}
                  onChange={(event) => setName(event.target.value)}
                />
              </label>
              <label>
                Mô tả
                <textarea
                  maxLength={1000}
                  value={description}
                  disabled={locked}
                  onChange={(event) => setDescription(event.target.value)}
                />
              </label>
              {githubPanel(true)}
              <p>Đã chọn {picked.size} repo. Tối đa 100 repo mỗi lần tạo; có thể thêm sau.</p>
              <button type="submit" className="auth-primary" disabled={locked}>
                Tạo workspace
              </button>
              <button
                type="button"
                className="auth-secondary"
                disabled={locked}
                onClick={() => setCreating(false)}
              >
                Hủy
              </button>
            </form>
          </section>
        )}
        {!creating && tab === 'workspace' && (
          <>
            {!feed.loading && !feed.error && !feed.rows.length && (
              <section className="live-panel">
                <h1>Workspace của bạn</h1>
                <p>Bạn có thể tự tạo workspace đầu tiên và chọn repo cần dùng.</p>
              </section>
            )}
            {selected ? (
              <>
                <WorkspaceDetail
                  key={selected.id}
                  workspace={selected}
                  uid={profile.uid}
                  act={act}
                  busy={locked}
                  onOpenRepo={openRepo}
                  addingRepo={addingRepository}
                  repoPicker={githubPanel(false)}
                  onAddRepo={() => setAddingRepository((value) => !value)}
                />
              </>
            ) : (
              <div className="live-grid">
                {feed.rows.map((row) => (
                  <button
                    key={row.id}
                    className="live-workspace-card"
                    onClick={() => {
                      setSelectedId(row.id)
                      setCiRepo('')
                    }}
                  >
                    <h2>{String(row.name)}</h2>
                    <p>{String(row.description)}</p>
                  </button>
                ))}
              </div>
            )}
          </>
        )}
        {!creating &&
          tab === 'cicd' &&
          (selected ? (
            <CicdScreen
              key={selected.id}
              workspaceId={selected.id}
              active={selected.status === 'active'}
              initialRepo={ciRepo}
              onRepoChange={setCiRepo}
            />
          ) : (
            <section className="live-panel">
              <h1>CI/CD</h1>
              <p>Chọn workspace ở trên để xem lịch sử CI/CD.</p>
            </section>
          ))}
        {!creating && tab === 'account' && (
          <>
            <section className="auth-profile">
              <h1>Tài khoản</h1>
              <p>
                {profile.displayName} · {profile.email}
              </p>
              <p>Vai trò: user</p>
              <GitHubAccount onBusy={setLinking} />
            </section>
            <GitHubConnection onBusy={setLinking} />
            {githubPanel(false)}
          </>
        )}
      </div>
    </main>
  )
}
