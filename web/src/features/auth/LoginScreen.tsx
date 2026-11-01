import { useState } from 'react'
import type { FormEvent } from 'react'
import { authErrorMessage, login, loginWithGitHub } from './authService'

export function LoginScreen({ onPreview }: { onPreview: () => void }) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState('')
  const [fieldErrors, setFieldErrors] = useState<{ email?: string; password?: string }>({})

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (submitting) return
    const fields: typeof fieldErrors = {}
    if (!email.trim()) fields.email = 'Vui lòng nhập email.'
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) fields.email = 'Vui lòng nhập email đúng định dạng.'
    if (!password) fields.password = 'Vui lòng nhập mật khẩu.'
    setFieldErrors(fields)
    setError('')
    if (Object.keys(fields).length) return
    setSubmitting(true)
    try {
      await login(email, password)
      setPassword('')
    } catch (cause) {
      setError(authErrorMessage(cause))
    } finally {
      setSubmitting(false)
    }
  }

  async function github() {
    if (submitting) return
    setSubmitting(true)
    setError('')
    try { await loginWithGitHub() } catch (cause) { setError(authErrorMessage(cause)) }
    finally { setSubmitting(false) }
  }

  return <main className="auth-page">
    <header className="auth-header"><span className="auth-brand"><span className="auth-brand-mark" aria-hidden="true">V</span>Vista CI</span><span>Workspace monitoring</span></header>
    <section className="auth-card" aria-labelledby="login-title">
      <span className="auth-kicker">Chào mừng trở lại</span><h1 id="login-title">Đăng nhập Vista</h1>
      <p>Theo dõi CI/CD và hiểu nguyên nhân lỗi trong workspace của bạn.</p>
      <button className="auth-primary auth-github" type="button" disabled={submitting} onClick={github}>{submitting ? 'Đang xác thực…' : 'Tiếp tục với GitHub'}</button>
      <p className="auth-link-note">Đã có tài khoản Email/Password? Đăng nhập bên dưới một lần, vào Tài khoản → Liên kết GitHub để giữ hồ sơ và workspace.</p>
      {error && <div className="auth-error" role="alert">{error}</div>}
      <form noValidate onSubmit={submit} aria-busy={submitting}>
        <label htmlFor="email">Email — tài khoản hiện có</label>
        <input id="email" name="email" type="email" inputMode="email" autoComplete="username" autoCapitalize="none" spellCheck={false} value={email} onChange={(event) => { setEmail(event.target.value); setFieldErrors((fields) => ({ ...fields, email: undefined })); setError('') }} disabled={submitting} aria-invalid={!!fieldErrors.email} aria-describedby={fieldErrors.email ? 'email-error' : undefined} required />
        {fieldErrors.email && <p className="auth-field-error" id="email-error">{fieldErrors.email}</p>}
        <label htmlFor="password">Mật khẩu</label>
        <div className="auth-password"><input id="password" name="password" type={showPassword ? 'text' : 'password'} autoComplete="current-password" value={password} onChange={(event) => { setPassword(event.target.value); setFieldErrors((fields) => ({ ...fields, password: undefined })); setError('') }} disabled={submitting} aria-invalid={!!fieldErrors.password} aria-describedby={fieldErrors.password ? 'password-error' : undefined} required /><button type="button" aria-controls="password" aria-pressed={showPassword} disabled={submitting} onClick={() => setShowPassword((value) => !value)}>{showPassword ? 'Ẩn' : 'Hiện'}</button></div>
        {fieldErrors.password && <p className="auth-field-error" id="password-error">{fieldErrors.password}</p>}
        <button className="auth-secondary" type="submit" disabled={submitting}>{submitting ? 'Đang đăng nhập…' : 'Đăng nhập'}</button>
      </form>
      <div className="auth-demo"><button type="button" className="auth-text" disabled={submitting} onClick={onPreview}>Xem giao diện với dữ liệu mẫu →</button><p>Chế độ mẫu không dùng tài khoản hoặc dữ liệu dự án thật.</p></div>
    </section>
  </main>
}
