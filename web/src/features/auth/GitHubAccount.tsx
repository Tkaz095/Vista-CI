import { useState } from 'react'
import { authErrorMessage, hasGitHubLink, linkGitHub } from './authService'

export function GitHubAccount({ onBusy }: { onBusy: (busy: boolean) => void }) {
  const [linked, setLinked] = useState(hasGitHubLink)
  const [pending, setPending] = useState(false)
  const [message, setMessage] = useState('')
  async function connect() {
    if (pending || linked) return
    setPending(true)
    onBusy(true)
    setMessage('')
    try {
      await linkGitHub()
      setLinked(hasGitHubLink())
      setMessage('Đã liên kết GitHub. UID và quyền workspace hiện có được giữ nguyên.')
    } catch (cause) {
      setLinked(hasGitHubLink())
      setMessage(authErrorMessage(cause))
    } finally { setPending(false); onBusy(false) }
  }
  return <section className="auth-github-account" aria-labelledby="github-account-title">
    <h2 id="github-account-title">Đăng nhập GitHub</h2>
    <p>{linked ? 'Đã liên kết GitHub với tài khoản Vista này.' : 'Liên kết GitHub để những lần sau đăng nhập bằng GitHub và giữ nguyên UID của tài khoản hiện tại.'}</p>
    {!linked && <button type="button" className="auth-primary" onClick={connect} disabled={pending}>{pending ? 'Đang liên kết…' : 'Liên kết GitHub'}</button>}
    {message && <p role="status">{message}</p>}
    <p>Quyền repository và đồng bộ CI/CD sẽ được cấu hình ở bước kết nối GitHub App.</p>
  </section>
}
