import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { onAuthStateChanged, signInWithEmailAndPassword, signOut } from 'firebase/auth'
import type { User } from 'firebase/auth'
import { auth } from '../../lib/firebase'
import { authErrorMessage } from './authErrors'
import { AdminIcon } from './AdminIcon'
import {
  AdminApiError,
  loadAdminOverview,
  loadRemoteConfig,
  saveRemoteConfig,
} from './adminService'
import type { AdminOverview, RemoteConfigSnapshot } from './adminService'
import './admin.css'
import { MonitoringPanel } from './MonitoringPanel'

type AdminTab = 'analytics' | 'monitoring' | 'config'
type AccessState = 'checking' | 'signed_out' | 'verifying' | 'denied' | 'error' | 'ready'

function message(error: unknown) {
  if (error instanceof AdminApiError) return error.message
  return error instanceof Error ? error.message : 'Thao tác chưa hoàn tất. Vui lòng thử lại.'
}

function AdminLogin({ onSubmit, error }: { onSubmit: (email: string, password: string) => Promise<void>; error: string }) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [submitting, setSubmitting] = useState(false)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (submitting) return
    setSubmitting(true)
    try {
      await onSubmit(email.trim(), password)
    } finally {
      setSubmitting(false)
    }
  }

  return <main className="admin-login-page">
    <header className="admin-login-brand"><span className="admin-brand-mark"><AdminIcon name="activity" /></span><span>Vista CI <small>ADMIN</small></span></header>
    <section className="admin-login-card" aria-labelledby="admin-login-title">
      <span className="admin-eyebrow">KHU VỰC QUẢN TRỊ</span>
      <h1 id="admin-login-title">Đăng nhập admin</h1>
      <p>Dùng tài khoản Email/Mật khẩu admin riêng.</p>
      {error && <div className="admin-alert" role="alert">{error}</div>}
      <form className="admin-login-form" onSubmit={submit}>
        <label htmlFor="admin-email">Email</label>
        <input id="admin-email" type="email" autoComplete="username" value={email} onChange={(event) => setEmail(event.target.value)} required disabled={submitting} />
        <label htmlFor="admin-password">Mật khẩu</label>
        <input id="admin-password" type="password" autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} required disabled={submitting} />
        <button className="admin-primary" type="submit" disabled={submitting}>{submitting ? 'Đang đăng nhập…' : 'Đăng nhập quản trị'}</button>
      </form>
      <p className="admin-login-note">Khu vực dành cho quản trị viên. Thành viên sử dụng ứng dụng Vista CI trên điện thoại.</p>
    </section>
  </main>
}

function AnalyticsPanel({ overview, onRefresh, refreshing }: { overview: AdminOverview; onRefresh: () => void; refreshing: boolean }) {
  const { stats, workspacesByDay } = overview
  const maxCount = Math.max(1, ...workspacesByDay.map((day) => day.count))
  const cards = [
    { label: 'Tài khoản', value: stats.users, detail: `${stats.activeUsers} đang hoạt động`, icon: 'user' as const },
    { label: 'Tài khoản hoạt động', value: stats.activeUsers, detail: stats.users ? `${Math.round((stats.activeUsers / stats.users) * 100)}% tổng tài khoản` : 'Chưa có tài khoản', icon: 'check' as const },
    { label: 'Workspace', value: stats.workspaces, detail: `${stats.activeWorkspaces} đang hoạt động`, icon: 'workspace' as const },
    { label: 'Workspace hoạt động', value: stats.activeWorkspaces, detail: stats.workspaces ? `${Math.round((stats.activeWorkspaces / stats.workspaces) * 100)}% tổng workspace` : 'Chưa có workspace', icon: 'activity' as const },
  ]
  return <>
    <div className="admin-page-heading">
      <div><span className="admin-eyebrow">TỔNG QUAN</span><h1>Tổng quan hệ thống</h1><p>Số liệu tài khoản và workspace đang lưu trong Firestore.</p></div>
      <button className="admin-secondary" onClick={onRefresh} disabled={refreshing}><AdminIcon name="refresh" />{refreshing ? 'Đang tải…' : 'Làm mới'}</button>
    </div>
    <section className="admin-metric-grid" aria-label="Chỉ số tổng quan">
      {cards.map((card) => <article className="admin-metric-card" key={card.label}>
        <div className="admin-metric-top"><span>{card.label}</span><span className="admin-metric-icon" aria-hidden="true"><AdminIcon name={card.icon} /></span></div>
        <strong>{card.value.toLocaleString('vi-VN')}</strong><small>{card.detail}</small>
      </article>)}
    </section>
    <section className="admin-panel">
      <div className="admin-panel-heading"><div><h2>Workspace mới</h2><p>Số workspace được tạo mỗi ngày trong 14 ngày gần nhất.</p></div><span className="admin-chart-legend"><i /> Workspace</span></div>
      <div className="admin-chart" role="img" aria-label="Biểu đồ số workspace tạo mới theo ngày">
        {workspacesByDay.map((day) => {
          const height = day.count ? Math.max(8, (day.count / maxCount) * 100) : 3
          return <div className="admin-chart-column" key={day.date} title={`${day.date}: ${day.count} workspace`} aria-label={`${day.date}: ${day.count} workspace`}>
            <span className="admin-chart-value">{day.count || ''}</span>
            <div className="admin-chart-track"><i style={{ height: `${height}%` }} /></div>
            <small>{day.date.slice(8)}</small>
          </div>
        })}
      </div>
      <div className="admin-chart-footnote">Thời gian theo UTC · Di chuột lên cột để xem số workspace.</div>
    </section>
  </>
}

function ConfigPanel({
  user,
  snapshot,
  onSaved,
}: {
  user: User
  snapshot: RemoteConfigSnapshot | null
  onSaved: (snapshot: RemoteConfigSnapshot) => void
}) {
  const [enabled, setEnabled] = useState(true)
  const [cloudName, setCloudName] = useState('')
  const [uploadPreset, setUploadPreset] = useState('')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  useEffect(() => {
    let active = true
    void loadRemoteConfig(user).then((config) => {
      if (!active) return
      onSaved(config)
      setEnabled(config.values.ci_analysis_enabled === 'true')
      setCloudName(config.values.cloudinary_cloud_name)
      setUploadPreset(config.values.cloudinary_upload_preset)
    }).catch((cause: unknown) => {
      if (active) setError(message(cause))
    }).finally(() => {
      if (active) setLoading(false)
    })
    return () => { active = false }
  }, [user, onSaved])

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!snapshot || saving) return
    setSaving(true)
    setError('')
    setNotice('')
    try {
      const saved = await saveRemoteConfig(user, {
        version: snapshot.version,
        values: {
          ci_analysis_enabled: enabled,
          cloudinary_cloud_name: cloudName,
          cloudinary_upload_preset: uploadPreset,
        },
      })
      onSaved(saved)
      setNotice('Đã xuất bản cấu hình Firebase Remote Config.')
    } catch (cause) {
      setError(message(cause))
    } finally {
      setSaving(false)
    }
  }

  return <>
    <div className="admin-page-heading">
      <div><span className="admin-eyebrow">FIREBASE REMOTE CONFIG</span><h1>Cấu hình ứng dụng</h1><p>Thay đổi tham số dùng bởi ứng dụng Vista CI.</p></div>
    </div>
    <section className="admin-panel admin-config-panel">
      <div className="admin-panel-heading"><div><h2>Tham số phát hành</h2><p>Lưu sẽ xuất bản giá trị mặc định lên Firebase Remote Config.</p></div><span className="admin-live-badge">Remote Config</span></div>
      {error && <div className="admin-alert" role="alert">{error}{error.includes('thay đổi ở nơi khác') && <button type="button" className="admin-inline-button" onClick={() => window.location.reload()}>Tải lại</button>}</div>}
      {notice && <div className="admin-success" role="status">{notice}</div>}
      {loading ? <div className="admin-loading" role="status">Đang tải cấu hình từ Firebase…</div> : <form className="admin-config-form" onSubmit={submit}>
        <label className="admin-toggle-row" htmlFor="analysis-enabled">
          <span><strong>Cho phép phân tích CI</strong><small>Tắt để chặn bắt đầu phân tích mới trên ứng dụng.</small></span>
          <input id="analysis-enabled" type="checkbox" checked={enabled} onChange={(event) => setEnabled(event.target.checked)} disabled={saving || !snapshot} />
        </label>
        <label htmlFor="cloud-name">Cloudinary cloud name</label>
        <input id="cloud-name" value={cloudName} onChange={(event) => setCloudName(event.target.value)} maxLength={128} autoComplete="off" disabled={saving || !snapshot} />
        <small className="admin-help">Để trống nếu chưa cấu hình upload báo cáo.</small>
        <label htmlFor="upload-preset">Cloudinary unsigned upload preset</label>
        <input id="upload-preset" value={uploadPreset} onChange={(event) => setUploadPreset(event.target.value)} maxLength={128} autoComplete="off" disabled={saving || !snapshot} />
        <small className="admin-help">Giá trị Remote Config là công khai; không nhập API secret hoặc mật khẩu.</small>
        <div className="admin-config-actions"><button className="admin-primary" type="submit" disabled={saving || loading || !snapshot}>{saving ? 'Đang xuất bản…' : 'Lưu và xuất bản'}</button>{snapshot && <span>Phiên bản: {snapshot.version}</span>}</div>
      </form>}
    </section>
  </>
}

export function AdminConsole() {
  const [user, setUser] = useState<User | null>(null)
  const [access, setAccess] = useState<AccessState>('checking')
  const [activeTab, setActiveTab] = useState<AdminTab>('analytics')
  const [loginError, setLoginError] = useState('')
  const [accessError, setAccessError] = useState('')
  const [overview, setOverview] = useState<AdminOverview | null>(null)
  const [configSnapshot, setConfigSnapshot] = useState<RemoteConfigSnapshot | null>(null)
  const [refreshing, setRefreshing] = useState(false)
  const [refreshError, setRefreshError] = useState('')

  useEffect(() => {
    const previousTitle = document.title
    document.title = 'Vista CI — Quản trị'
    return () => { document.title = previousTitle }
  }, [])

  useEffect(() => onAuthStateChanged(auth, (nextUser) => {
    setUser(nextUser)
    setAccess(nextUser ? 'verifying' : 'signed_out')
    setAccessError('')
    setOverview(null)
    setConfigSnapshot(null)
  }), [])

  useEffect(() => {
    if (!user) return
    let active = true
    void loadAdminOverview(user).then((result) => {
      if (!active) return
      setOverview(result)
      setAccess('ready')
    }).catch((cause: unknown) => {
      if (!active) return
      setAccessError(message(cause))
      // Keep the error visible; only an explicit sign-out should return to login.
      setAccess(
        cause instanceof AdminApiError && cause.status === 403
          ? 'denied'
          : 'error',
      )
    })
    return () => { active = false }
  }, [user])

  async function loginAdmin(email: string, password: string) {
    setLoginError('')
    try {
      await signInWithEmailAndPassword(auth, email, password)
    } catch (cause) {
      setLoginError(authErrorMessage(cause))
    }
  }

  async function refreshOverview() {
    if (!user || refreshing) return
    setRefreshing(true)
    setRefreshError('')
    try {
      setOverview(await loadAdminOverview(user))
    } catch (cause) {
      setRefreshError(message(cause))
    } finally {
      setRefreshing(false)
    }
  }

  if (access === 'checking' || access === 'verifying')
    return <main className="admin-login-page"><section className="admin-login-card" role="status" aria-live="polite"><span className="admin-brand-mark"><AdminIcon name="activity" /></span><h1>Đang xác minh quyền</h1><p>Đang kiểm tra phiên đăng nhập và quyền admin với Firebase.</p></section></main>
  if (access === 'signed_out' && user)
    return <AdminLogin onSubmit={loginAdmin} error={accessError || loginError} />
  if (access === 'signed_out' || !user)
    return <AdminLogin onSubmit={loginAdmin} error={loginError} />
  if (access === 'denied')
    return <main className="admin-login-page"><section className="admin-login-card" aria-labelledby="denied-title"><span className="admin-brand-mark"><AdminIcon name="activity" /></span><h1 id="denied-title">Chưa được cấp quyền admin</h1><div className="admin-alert" role="alert">{accessError}</div><button className="admin-secondary admin-full-button" onClick={() => void signOut(auth)}>Đăng xuất / đổi tài khoản</button></section></main>
  if (access === 'error')
    return <main className="admin-login-page"><section className="admin-login-card" aria-labelledby="admin-error-title"><span className="admin-brand-mark"><AdminIcon name="activity" /></span><h1 id="admin-error-title">Chưa xác minh được quyền</h1><div className="admin-alert" role="alert">{accessError}</div><button className="admin-secondary admin-full-button" onClick={() => window.location.reload()}>Thử lại</button><button className="admin-secondary admin-full-button" onClick={() => void signOut(auth)}>Đăng xuất</button></section></main>

  const email = user.email || user.displayName || 'Quản trị viên'
  return <div className="admin-shell">
    <header className="admin-sidebar">
      <a className="admin-brand" href="/"><span className="admin-brand-mark"><AdminIcon name="activity" /></span><span>Vista CI<small>ADMIN CONSOLE</small></span></a>
      <span className="admin-nav-caption">QUẢN LÝ</span>
      <nav className="admin-nav" aria-label="Điều hướng admin">
        <button className={activeTab === 'analytics' ? 'active' : ''} aria-current={activeTab === 'analytics' ? 'page' : undefined} onClick={() => setActiveTab('analytics')}><AdminIcon name="workspace" />Tổng quan</button>
        <button className={activeTab === 'monitoring' ? 'active' : ''} aria-current={activeTab === 'monitoring' ? 'page' : undefined} onClick={() => setActiveTab('monitoring')}><AdminIcon name="activity" />Giám sát ứng dụng</button>
        <button className={activeTab === 'config' ? 'active' : ''} aria-current={activeTab === 'config' ? 'page' : undefined} onClick={() => setActiveTab('config')}><AdminIcon name="settings" />Cấu hình ứng dụng</button>
      </nav>
      <div className="admin-sidebar-bottom"><span className="admin-secure-dot" /> Quản trị hệ thống</div>
    </header>
    <a className="admin-skip" href="#admin-content">Đến nội dung chính</a>
    <main className="admin-main">
      <header className="admin-topbar"><div><span className="admin-topbar-kicker">VISTA CI</span><strong>{activeTab === 'analytics' ? 'Tổng quan hệ thống' : activeTab === 'monitoring' ? 'Giám sát ứng dụng' : 'Cấu hình ứng dụng'}</strong></div><div className="admin-account"><span className="admin-avatar">{email.slice(0, 1).toUpperCase()}</span><span>{email}<small>ADMIN</small></span><button onClick={() => void signOut(auth)}>Đăng xuất</button></div></header>
      <div className="admin-content" id="admin-content" tabIndex={-1}>
        {activeTab === 'analytics' && (overview ? <AnalyticsPanel overview={overview} onRefresh={() => void refreshOverview()} refreshing={refreshing} /> : <div className="admin-panel admin-loading" role="status">Đang tải số liệu…</div>)}
        {activeTab === 'analytics' && refreshError && <div className="admin-alert" role="alert">{refreshError}</div>}
        {activeTab === 'monitoring' && <MonitoringPanel user={user} />}
        {activeTab === 'config' && <ConfigPanel user={user} snapshot={configSnapshot} onSaved={setConfigSnapshot} />}
      </div>
    </main>
  </div>
}
