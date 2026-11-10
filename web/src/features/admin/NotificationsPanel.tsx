import { useEffect, useRef, useState } from 'react'
import type { FormEvent } from 'react'
import type { User } from 'firebase/auth'
import type { NotificationRecipient } from '../../../shared/adminNotifications'
import { AdminIcon } from './AdminIcon'
import { AdminApiError, deliverNotifications, loadAllNotificationRecipients, loadNotificationRecipients } from './adminService'
import type { NotificationDelivery } from './adminService'

function errorMessage(error: unknown) {
  return error instanceof AdminApiError ? error.message : 'Chưa kết nối được với server. Hãy thử lại.'
}

export function NotificationsPanel({ user, active }: { user: User; active: boolean }) {
  const [recipients, setRecipients] = useState<NotificationRecipient[]>([])
  const [nextCursor, setNextCursor] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [recipientError, setRecipientError] = useState('')
  const [audience, setAudience] = useState<'one' | 'all'>('one')
  const [uid, setUid] = useState('')
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [deliveries, setDeliveries] = useState<NotificationDelivery[] | null>(null)
  const [confirmedAll, setConfirmedAll] = useState(false)
  const [started, setStarted] = useState(false)
  const [operation, setOperation] = useState<'prepare' | 'send' | 'check' | null>(null)
  const [error, setError] = useState('')
  const loaded = useRef(false)
  const busy = useRef(false)
  const mounted = useRef(false)
  const preview = useRef<HTMLElement>(null)
  const recipient = recipients.find(item => item.uid === uid)
  const pending = deliveries?.filter(item => item.state === 'pending').length ?? 0
  const unknown = deliveries?.filter(item => item.state === 'unknown').length ?? 0
  const completed = deliveries?.filter(item => item.state === 'completed').length ?? 0
  const rejected = deliveries?.filter(item => item.state === 'failed').length ?? 0
  const results = deliveries?.flatMap(item => item.result ? [item.result] : []) ?? []
  const devices = results.reduce((total, item) => total + item.devices, 0)
  const accepted = results.reduce((total, item) => total + item.sent, 0)
  const invalid = results.reduce((total, item) => total + item.failed, 0)
  const uncertain = results.reduce((total, item) => total + item.uncertain, 0)
  const finished = started && pending === 0 && unknown === 0 && !operation

  useEffect(() => {
    mounted.current = true
    return () => { mounted.current = false }
  }, [])

  useEffect(() => {
    if (!active || loaded.current) return
    let current = true
    void loadNotificationRecipients(user).then(page => {
      if (!current) return
      loaded.current = true
      setRecipients(page.recipients)
      setNextCursor(page.nextCursor)
      setRecipientError('')
    }).catch((cause: unknown) => {
      if (current) setRecipientError(errorMessage(cause))
    }).finally(() => { if (current) setLoading(false) })
    return () => { current = false }
  }, [active, user])

  useEffect(() => { if (deliveries && !started) preview.current?.focus() }, [deliveries, started])

  async function loadMore(reset = false) {
    if (loading) return
    setLoading(true)
    setRecipientError('')
    try {
      const page = await loadNotificationRecipients(user, reset ? undefined : nextCursor ?? undefined)
      if (!mounted.current) return
      loaded.current = true
      setRecipients(previous => [...new Map([
        ...(reset ? [] : previous).map(item => [item.uid, item] as const),
        ...page.recipients.map(item => [item.uid, item] as const),
      ]).values()])
      if (reset) setUid('')
      setNextCursor(page.nextCursor)
    } catch (cause) {
      if (mounted.current) setRecipientError(errorMessage(cause))
    } finally { if (mounted.current) setLoading(false) }
  }

  async function review(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (busy.current || (audience === 'one' && !recipient) || !title.trim() || !body.trim()) return
    busy.current = true
    setOperation('prepare')
    setError('')
    try {
      // Load every page again for a broadcast; never send only the visible select options.
      const targets = audience === 'all' ? await loadAllNotificationRecipients(user) : [recipient!]
      if (!mounted.current) return
      if (!targets.length) {
        setError('Chưa có user đang hoạt động để gửi thông báo.')
        return
      }
      setDeliveries(targets.map(target => ({
        draft: { requestId: crypto.randomUUID(), uid: target.uid, title: title.trim(), body: body.trim() },
        displayName: target.displayName, state: 'pending',
      })))
      setConfirmedAll(false)
      setStarted(false)
    } catch (cause) {
      if (mounted.current) setError(errorMessage(cause))
    } finally {
      busy.current = false
      if (mounted.current) setOperation(null)
    }
  }

  async function process(action: 'send' | 'check') {
    if (!deliveries || busy.current || (action === 'send' && (unknown > 0 || (audience === 'all' && !confirmedAll)))) return
    busy.current = true
    setOperation(action)
    setStarted(true)
    setError('')
    try {
      await deliverNotifications(user, deliveries, action, setDeliveries, () => mounted.current)
    } finally {
      busy.current = false
      if (mounted.current) setOperation(null)
    }
  }

  function edit() {
    setDeliveries(null)
    setError('')
    setConfirmedAll(false)
    setStarted(false)
  }

  return <>
    <div className="admin-page-heading admin-notification-heading">
      <div><h1>Thông báo</h1><p>Gửi tới một tài khoản hoặc tất cả user đang hoạt động trên Vista CI.</p></div>
      <button className="admin-secondary" type="button" disabled={loading || !!deliveries || !!operation} onClick={() => void loadMore(true)}><AdminIcon name="refresh" />Làm mới tài khoản</button>
    </div>
    <div className="admin-notifications-grid">
      <section className="admin-panel" aria-labelledby="notification-compose-title">
        <div className="admin-panel-heading"><div><h2 id="notification-compose-title">Soạn thông báo</h2><p>Kiểm tra người nhận và bản xem trước trước khi gửi.</p></div></div>
        <form onSubmit={event => void review(event)} className="admin-notification-form" aria-busy={!!operation}>
          <fieldset className="admin-notification-fields" disabled={!!deliveries || !!operation}>
            <label htmlFor="notification-audience">Phạm vi gửi</label>
            <select id="notification-audience" value={audience} onChange={event => setAudience(event.target.value as 'one' | 'all')}>
              <option value="one">Một tài khoản</option>
              <option value="all">Tất cả user đang hoạt động</option>
            </select>
            {audience === 'one' ? <>
              <label htmlFor="notification-recipient">Người nhận</label>
              <select id="notification-recipient" value={uid} onChange={event => setUid(event.target.value)} required disabled={loading || !!deliveries || !!operation} aria-describedby="notification-recipient-help">
                <option value="">{loading ? 'Đang tải tài khoản…' : 'Chọn tài khoản app'}</option>
                {recipients.map(item => <option key={item.uid} value={item.uid}>{item.displayName} · {item.uid}</option>)}
              </select>
              <small className="admin-help" id="notification-recipient-help">Gửi tới các thiết bị đã đăng ký của tài khoản này. Lịch sử vẫn được lưu nếu chưa có thiết bị.</small>
              {recipientError && <div className="admin-alert" role="alert">{recipientError}<button type="button" className="admin-inline-button" onClick={() => void loadMore(true)} disabled={loading}>Tải lại danh sách</button></div>}
              {!loading && !recipientError && recipients.length === 0 && <p className="admin-help">Chưa có tài khoản app đang hoạt động trong danh sách đã tải.</p>}
              {nextCursor && <button type="button" className="admin-secondary" onClick={() => void loadMore()} disabled={loading}>{loading ? 'Đang tải…' : 'Tải thêm tài khoản'}</button>}
            </> : <p className="admin-help">Gửi tới mọi thiết bị đã đăng ký của toàn bộ user đang hoạt động. Không gồm admin, tài khoản bị khóa hoặc đã vô hiệu hóa.</p>}
            <div className="admin-notification-label"><label htmlFor="notification-title">Tiêu đề</label><small>{title.length}/200</small></div>
            <input id="notification-title" value={title} onChange={event => setTitle(event.target.value)} maxLength={200} required placeholder="Ví dụ: Lịch bảo trì hệ thống" />
            <div className="admin-notification-label"><label htmlFor="notification-body">Nội dung</label><small>{body.length}/1.000</small></div>
            <textarea id="notification-body" value={body} onChange={event => setBody(event.target.value)} maxLength={1000} rows={6} required placeholder="Nhập nội dung người dùng sẽ nhận trên app…" />
          </fieldset>
          {!deliveries && <button className="admin-primary" type="submit" disabled={!!operation || (audience === 'one' && (loading || !uid)) || !title.trim() || !body.trim()}>{operation === 'prepare' ? 'Đang tải toàn bộ người nhận…' : 'Xem lại thông báo'}</button>}
          {deliveries && <>
            {audience === 'all' && !started && <label className="admin-notification-confirm"><input type="checkbox" checked={confirmedAll} onChange={event => setConfirmedAll(event.target.checked)} /><span>Tôi xác nhận gửi thông báo này cho <strong>{deliveries.length} user</strong>.</span></label>}
            <div className="admin-notification-actions">
              {pending > 0 && unknown === 0 && <button className="admin-primary" type="button" onClick={() => void process('send')} disabled={!!operation || (audience === 'all' && !confirmedAll)}>{operation === 'send' ? 'Đang gửi…' : started ? 'Tiếp tục gửi phần còn lại' : audience === 'all' ? `Gửi cho ${deliveries.length} user` : 'Gửi thông báo'}</button>}
              {unknown > 0 && <button className="admin-secondary" type="button" onClick={() => void process('check')} disabled={!!operation}>{operation === 'check' ? 'Đang kiểm tra…' : 'Kiểm tra kết quả'}</button>}
              {!started && <button className="admin-secondary" type="button" onClick={edit} disabled={!!operation}>Chỉnh sửa</button>}
              {finished && <button className="admin-secondary" type="button" onClick={() => { edit(); setTitle(''); setBody('') }}>Soạn thông báo mới</button>}
            </div>
          </>}
        </form>
        {error && <div className="admin-alert" role="alert">{error}</div>}
        {deliveries && <p className="admin-help">Danh sách gồm {deliveries.length} user tại lúc xem lại. Giữ trang web mở đến khi hoàn tất; có thể chuyển giữa các tab quản trị.</p>}
        {started && deliveries && <>
          <div className="admin-notification-result" role="status" aria-live="polite">
            <strong>{finished ? 'Đã kết thúc lượt gửi.' : 'Tiến độ gửi thông báo'}</strong>
            <p>Đã xử lý: {completed + rejected}/{deliveries.length} tài khoản.</p>
            <ul>
              <li>Đã lưu lịch sử: {results.length} tài khoản.</li>
              <li>FCM chấp nhận: {accepted}/{devices} thiết bị đã có kết quả phản hồi.</li>
              {results.some(item => item.devices === 0) && <li>{results.filter(item => item.devices === 0).length} tài khoản chưa có thiết bị; thông báo vẫn có trong lịch sử trên app.</li>}
              {invalid > 0 && <li>{invalid} đăng ký thiết bị hết hiệu lực; đã dọn đăng ký cũ.</li>}
              {uncertain > 0 && <li>Chưa xác nhận được FCM cho {uncertain} thiết bị. Kiểm tra quyền FCM và Runtime Logs của server.</li>}
              {rejected > 0 && <li>Không gửi được: {rejected} tài khoản.</li>}
              {unknown > 0 && <li>Chưa xác nhận: {unknown} tài khoản. Kiểm tra kết quả trước khi gửi tiếp.</li>}
              {pending > 0 && <li>Chưa gửi: {pending} tài khoản.</li>}
            </ul>
            <p className="admin-help">FCM chấp nhận yêu cầu chưa bảo đảm điện thoại đã hiển thị hoặc người dùng đã đọc.</p>
          </div>
          {(rejected > 0 || unknown > 0) && <details className="admin-notification-errors"><summary>Chi tiết tài khoản cần kiểm tra ({rejected + unknown})</summary><ul>{deliveries.filter(item => item.error).map(item => <li key={item.draft.requestId}><strong>{item.displayName}</strong> · {item.draft.uid}<br />{item.error}</li>)}</ul></details>}
        </>}
      </section>
      <aside className="admin-notification-preview" aria-labelledby="notification-preview-title" ref={preview} tabIndex={-1}>
        <h2 id="notification-preview-title">{started ? 'Nội dung của lượt gửi' : deliveries ? 'Kiểm tra trước khi gửi' : 'Bản xem trước'}</h2>
        <p>{audience === 'all' ? <strong>{deliveries ? `Gửi tới ${deliveries.length} user đang hoạt động` : 'Gửi tới tất cả user đang hoạt động'}</strong> : recipient ? <>Gửi tới <strong>{recipient.displayName}</strong></> : 'Chọn người nhận để chuẩn bị gửi.'}</p>
        {audience === 'one' && uid && <code className="admin-notification-uid">{uid}</code>}
        <div className="admin-notification-message">
          <div className="admin-notification-app"><AdminIcon name="bell" /><span>Vista CI</span></div>
          <h3>{deliveries?.[0].draft.title || title.trim() || 'Tiêu đề thông báo'}</h3>
          <p>{deliveries?.[0].draft.body || body.trim() || 'Nội dung bạn nhập sẽ xuất hiện tại đây.'}</p>
        </div>
        <p className="admin-help">Thông báo quản trị được mở trong app. Tùy chọn nhận kết quả CI của từng repo được quản lý riêng.</p>
      </aside>
    </div>
  </>
}
