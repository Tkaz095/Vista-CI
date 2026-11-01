import { useEffect, useState } from 'react'
import { collection, limit, onSnapshot, query, where } from 'firebase/firestore'
import type { Query } from 'firebase/firestore'
import type { VistaProfile } from '../auth/authService'
import { authErrorMessage, logout } from '../auth/authService'
import { db } from '../../lib/firebase'
import { GitHubAccount } from '../auth/GitHubAccount'
import './live-workspace.css'

type Row = { id: string; name: string; description: string }
type Feed = { state: 'loading' | 'ready' | 'error'; rows: Row[]; error: string }
const text = (value: unknown, fallback = '') => typeof value === 'string' && value.trim() ? value.trim() : fallback

function useFeed(source: Query): Feed {
  const [feed, setFeed] = useState<Feed>({ state: 'loading', rows: [], error: '' })
  useEffect(() => {
    let active = true
    const deadline = setTimeout(() => {
      if (active) setFeed({ state: 'error', rows: [], error: 'Chưa nhận được dữ liệu từ máy chủ. Kiểm tra mạng rồi thử lại.' })
    }, 15000)
    const stop = onSnapshot(source, { includeMetadataChanges: true }, snapshot => {
      if (!active || snapshot.metadata.fromCache || snapshot.metadata.hasPendingWrites) return
      clearTimeout(deadline)
      setFeed({ state: 'ready', error: '', rows: snapshot.docs.map(doc => ({ id: doc.id,
        name: text(doc.data().name, doc.id), description: text(doc.data().description) })) })
    }, cause => {
      if (!active) return
      clearTimeout(deadline)
      setFeed({ state: 'error', rows: [], error: cause.code === 'permission-denied'
        ? 'Chưa có quyền đọc dữ liệu workspace. Cập nhật Firestore Rules theo tài liệu bước 12.'
        : 'Không tải được dữ liệu. Kiểm tra mạng rồi thử lại.' })
    })
    return () => { active = false; clearTimeout(deadline); stop() }
  }, [source])
  return feed
}

function RepositoryList({ workspaceId }: { workspaceId: string }) {
  const [source] = useState(() => query(collection(db, 'workspaces', workspaceId, 'repositories'), limit(50)))
  const [attempt, setAttempt] = useState(0)
  return <RepositoryFeed key={attempt} source={source} retry={() => setAttempt(value => value + 1)} />
}
function RepositoryFeed({ source, retry }: { source: Query; retry: () => void }) {
  const feed = useFeed(source)
  return <section className="live-panel"><h2>Repository</h2><p>Danh sách cấu hình trên Vista; chưa kết nối GitHub để đồng bộ workflow.</p>
    {feed.state === 'loading' && <p role="status">Đang tải repository…</p>}
    {feed.state === 'error' && <div role="alert"><p>{feed.error}</p><button className="auth-secondary" onClick={retry}>Thử lại</button></div>}
    {feed.state === 'ready' && !feed.rows.length && <p>Workspace chưa có repository.</p>}
    <div className="live-grid">{feed.rows.map(repo => <article className="live-repo" key={repo.id}><h3>{repo.name}</h3><p>{repo.description}</p><span className="live-badge">Chưa đồng bộ GitHub</span></article>)}</div>
  </section>
}

export function LiveWorkspace({ profile }: { profile: VistaProfile }) {
  const [attempt, setAttempt] = useState(0)
  return <WorkspaceFeed key={attempt} profile={profile} retry={() => setAttempt(value => value + 1)} />
}
function WorkspaceFeed({ profile, retry }: { profile: VistaProfile; retry: () => void }) {
  const [source] = useState(() => query(collection(db, 'workspaces'), where('memberUids', 'array-contains', profile.uid), limit(50)))
  const feed = useFeed(source)
  const [selectedId, setSelectedId] = useState('')
  const [tab, setTab] = useState('runs')
  const [pending, setPending] = useState(false)
  const [linking, setLinking] = useState(false)
  const [error, setError] = useState('')
  const selected = feed.state === 'ready' ? feed.rows.find(row => row.id === selectedId) : undefined
  async function exit() {
    setPending(true)
    try { await logout() } catch (cause) { setError(authErrorMessage(cause)); setPending(false) }
  }
  return <main className="auth-home">
    <header className="auth-header live-header"><span className="auth-brand"><span className="auth-brand-mark" aria-hidden="true">V</span>Vista CI</span>
      <nav aria-label="Điều hướng chính">{[['runs', 'Run'], ['repos', 'Repo'], ['activity', 'Hoạt động'], ['account', 'Tài khoản']].map(([id, label]) =>
        <button className="live-nav" aria-current={tab === id ? 'page' : undefined} key={id} disabled={pending || linking} onClick={() => setTab(id)}>{label}</button>)}</nav>
      <button className="auth-secondary" onClick={exit} disabled={pending || linking}>{pending ? 'Đang đăng xuất…' : 'Đăng xuất'}</button>
    </header>
    <div className="auth-home-content live-content">
      {error && <p className="auth-error" role="alert">{error}</p>}
      {tab === 'account' ? <section className="auth-profile"><h1>Tài khoản</h1><dl>
        <div><dt>Tên hiển thị</dt><dd>{profile.displayName || 'Chưa đặt tên'}</dd></div>
        <div><dt>Email</dt><dd>{profile.email}</dd></div><div><dt>Vai trò Vista</dt><dd>{profile.role}</dd></div>
        <div><dt>UID</dt><dd><code>{profile.uid}</code></dd></div></dl><p>Vai trò Vista không tự cấp quyền vào mọi workspace.</p><GitHubAccount onBusy={setLinking} /></section>
      : <>
        <div className="live-workspace-heading"><div><span className="auth-kicker">Workspace</span><h1>{selected?.name ?? 'Chọn workspace'}</h1></div>
          <div className="live-picker"><label htmlFor="workspace">Workspace hiện tại</label><select id="workspace" value={selected?.id ?? ''} disabled={feed.state !== 'ready'} onChange={event => { setSelectedId(event.target.value); setTab('runs') }}>
            <option value="">Chọn workspace…</option>{feed.rows.map(row => <option value={row.id} key={row.id}>{row.name}</option>)}</select></div>
        </div>
        {feed.state === 'loading' && <p role="status">Đang tải workspace…</p>}
        {feed.state === 'error' && <section className="live-panel" role="alert"><h2>Chưa tải được workspace</h2><p>{feed.error}</p><button className="auth-secondary" onClick={retry}>Thử lại</button></section>}
        {feed.state === 'ready' && !feed.rows.length && <section className="live-panel"><h2>Bạn chưa có workspace</h2><p>Bạn đã đăng nhập. Khi được thêm vào workspace, danh sách sẽ xuất hiện ở đây.</p><button className="auth-secondary" onClick={retry}>Tải lại</button></section>}
        {feed.state === 'ready' && !selected && <div className="live-grid">{feed.rows.map(row => <button className="live-workspace-card" key={row.id} onClick={() => { setSelectedId(row.id); setTab('runs') }}><h2>{row.name}</h2><p>{row.description}</p><span>Mở workspace →</span></button>)}</div>}
        {selected && (tab === 'repos' ? <RepositoryList key={selected.id} workspaceId={selected.id} /> : <section className="live-panel"><h2>{tab === 'runs' ? 'Chưa kết nối workflow' : 'Chưa có nguồn audit'}</h2><p>{selected.description}</p><p>{tab === 'runs' ? 'Bước tiếp theo sẽ kết nối GitHub để đồng bộ trạng thái, kết quả và log vào workspace này.' : 'Audit sẽ được ghi ở backend khi triển khai chạy lại, tạo issue và bình luận PR.'}</p><button className="auth-secondary" onClick={() => setTab('repos')}>Xem repository</button></section>)}
      </>}
    </div>
  </main>
}
