import { useEffect, useState } from 'react'
import {
  connectGitHub,
  disconnectGitHub,
  fetchConnectionInfo,
  refreshConnectionInfo,
} from './githubService'
import type { GitHubConnectionInfo } from './githubService'

export function GitHubConnection({ onBusy }: { onBusy: (busy: boolean) => void }) {
  const [info, setInfo] = useState<GitHubConnectionInfo | null>(null),
    [pending, setPending] = useState(false),
    [error, setError] = useState(''),
    [message, setMessage] = useState('')
  useEffect(() => {
    const controller = new AbortController()
    const load = () => {
      void fetchConnectionInfo(AbortSignal.any([controller.signal, AbortSignal.timeout(20000)]))
        .then((value) => {
          if (!controller.signal.aborted) {
            setInfo(value)
            setError('')
          }
        })
        .catch((cause) => {
          if (!controller.signal.aborted)
            setError(cause instanceof Error ? cause.message : 'Không đọc được kết nối.')
        })
    }
    load()
    window.addEventListener('vista-github-connection', load)
    return () => {
      controller.abort()
      window.removeEventListener('vista-github-connection', load)
    }
  }, [])
  async function act(kind: 'connect' | 'refresh' | 'disconnect') {
    if (pending) return
    if (
      kind === 'disconnect' &&
      !confirm(
        'Ngắt kết nối GitHub trên mọi thiết bị Vista và xóa token đã lưu? Vista sẽ yêu cầu GitHub thu hồi quyền OAuth của ứng dụng. Phiên Firebase hiện tại được giữ.',
      )
    )
      return
    setPending(true)
    onBusy(true)
    setError('')
    setMessage('')
    try {
      if (kind === 'connect') {
        await connectGitHub()
        setInfo(await fetchConnectionInfo())
        window.dispatchEvent(new Event('vista-github-connection'))
        setMessage('Đã kết nối. Backend tự gia hạn token khi cần.')
      }
      if (kind === 'refresh') {
        setInfo(await refreshConnectionInfo(AbortSignal.timeout(30000)))
        setMessage('Đã cập nhật thông tin kết nối.')
      }
      if (kind === 'disconnect') {
        const result = await disconnectGitHub()
        setInfo({ connected: false, state: 'disconnected' })
        setMessage(result.message)
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Không hoàn tất thao tác.')
    } finally {
      setPending(false)
      onBusy(false)
    }
  }
  const date = (value?: number) => (value ? new Date(value).toLocaleString('vi-VN') : '—')
  return (
    <section className="live-panel" aria-labelledby="connection-title">
      <h2 id="connection-title">Kết nối GitHub cho CI/CD</h2>
      <p>
        Đăng nhập Vista và quyền API GitHub là hai phần riêng. Token được mã hóa ở backend, không
        lưu trong trình duyệt.
      </p>
      {info ? (
        <>
          <span className="live-badge">
            {info.connected ? 'Đã lưu kết nối · tự gia hạn' : 'Cần kết nối GitHub'}
          </span>
          {info.login && (
            <p>
              Tài khoản GitHub: <strong>{info.login}</strong>
            </p>
          )}
          {info.connected && (
            <dl className="connection-dates">
              <div>
                <dt>Access token đến hạn</dt>
                <dd>{date(info.expiresAt)}</dd>
              </div>
              <div>
                <dt>Refresh token đến hạn</dt>
                <dd>{date(info.refreshExpiresAt)}</dd>
              </div>
              <div>
                <dt>Cập nhật lần cuối</dt>
                <dd>{date(info.updatedAt)}</dd>
              </div>
              <div>
                <dt>Gia hạn thành công gần nhất</dt>
                <dd>
                  {info.lastRefreshedAt ? date(info.lastRefreshedAt) : 'Chưa ghi nhận lần gia hạn'}
                </dd>
              </div>
              <div>
                <dt>Số lần gia hạn đã ghi nhận</dt>
                <dd>{info.refreshCount ?? 0}</dd>
              </div>
            </dl>
          )}
        </>
      ) : (
        !error && <p role="status">Đang lấy thông tin kết nối…</p>
      )}
      <div className="live-actions">
        <button className="auth-primary" disabled={pending} onClick={() => void act('connect')}>
          {pending ? 'Đang xử lý…' : info?.connected ? 'Kết nối lại GitHub' : 'Kết nối GitHub'}
        </button>
        <button className="auth-secondary" disabled={pending} onClick={() => void act('refresh')}>
          Cập nhật kết nối
        </button>
        {info?.connected && (
          <button
            className="auth-secondary"
            disabled={pending}
            onClick={() => void act('disconnect')}
          >
            Ngắt kết nối
          </button>
        )}
      </div>
      {message && <p role="status">{message}</p>}
      {error && (
        <p role="alert" className="auth-error">
          {error}
        </p>
      )}
    </section>
  )
}
