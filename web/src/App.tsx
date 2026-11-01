import { useState } from 'react'
import { LoginScreen } from './features/auth/LoginScreen'
import { authErrorMessage, logout } from './features/auth/authService'
import { LiveWorkspace } from './features/workspaces/LiveWorkspace'
import { useAuthSession } from './features/auth/useAuthSession'
import { WorkspaceConsole } from './features/workspaces/WorkspaceConsole'
import './App.css'
import './features/auth/auth.css'

function App() {
  const { session, retry } = useAuthSession()
  const [preview, setPreview] = useState(false)
  const [signingOut, setSigningOut] = useState(false)
  const [exitError, setExitError] = useState('')
  async function exitBlockedSession() {
    setSigningOut(true)
    setExitError('')
    try { await logout() } catch (cause) { setExitError(authErrorMessage(cause)) } finally { setSigningOut(false) }
  }

  if (preview) return <WorkspaceConsole onExit={() => setPreview(false)} />
  if (session.status === 'initializing' || session.status === 'checking_profile') return <main className="auth-page"><section className="auth-card" role="status" aria-live="polite" aria-busy="true"><span className="auth-brand"><span className="auth-brand-mark" aria-hidden="true">V</span>Vista CI</span><h1>{session.status === 'initializing' ? 'Đang kiểm tra phiên' : 'Đang xác minh hồ sơ'}</h1><p>Vui lòng chờ trước khi mở dữ liệu tài khoản.</p><div className="auth-skeleton" aria-hidden="true" /><div className="auth-skeleton auth-skeleton-short" aria-hidden="true" /></section></main>
  if (session.status === 'ready') return <LiveWorkspace key={session.profile.uid} profile={session.profile} />
  if (session.status === 'blocked' || session.status === 'error') return <main className="auth-page"><section className="auth-card" aria-labelledby="session-title"><span className="auth-brand"><span className="auth-brand-mark" aria-hidden="true">V</span>Vista CI</span><h1 id="session-title">{session.status === 'blocked' ? 'Tài khoản chưa được cấp quyền' : 'Chưa xác minh được tài khoản'}</h1><div className="auth-error" role="alert">{session.message}</div>{exitError && <p role="alert" className="auth-field-error">{exitError}</p>}<div className="auth-state-actions"><button className="auth-primary" onClick={retry} disabled={signingOut}>Kiểm tra lại hồ sơ</button><button className="auth-secondary" onClick={exitBlockedSession} disabled={signingOut}>{signingOut ? 'Đang đăng xuất…' : 'Đăng xuất / đổi tài khoản'}</button></div></section></main>
  return <LoginScreen onPreview={() => setPreview(true)} />
}

export default App
