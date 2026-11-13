import { useEffect, useState } from 'react'
import type { User } from 'firebase/auth'
import type { AdminAnalytics } from '../../../shared/adminAnalytics'
import { loadAdminAnalytics } from './adminService'
import { Chart } from './MonitoringPanel'

const eventLabels: Record<string, string> = {
  login: 'Đăng nhập', logout: 'Đăng xuất', session_restored: 'Khôi phục phiên',
  project_create: 'Tạo project', project_update: 'Sửa project', project_delete: 'Xóa project',
  project_detail_view: 'Xem project', workflow_detail_view: 'Xem workflow',
  ci_analysis_start: 'Bắt đầu phân tích AI', ci_analysis_complete: 'Hoàn tất phân tích AI',
  workflow_rerun_requested: 'Yêu cầu chạy lại CI', pr_comment_sent: 'Gửi comment PR',
  ci_report_export: 'Xuất báo cáo', ci_report_upload: 'Upload báo cáo',
}

export function EventAnalyticsPanel({ user }: { user: User }) {
  const [state, setState] = useState<{ owner: string; result?: AdminAnalytics; error?: string } | null>(null)
  const [loaded, setLoaded] = useState(-1)
  const [revision, setRevision] = useState(0)
  useEffect(() => {
    let active = true
    void loadAdminAnalytics(user).then(result => {
      if (active) setState({ owner: user.uid, result })
    }).catch((error: unknown) => {
      if (active) setState({ owner: user.uid, error: error instanceof Error ? error.message : 'Không tải được sự kiện Analytics.' })
    }).finally(() => { if (active) setLoaded(revision) })
    return () => { active = false }
  }, [user, revision])
  const ownState = state?.owner === user.uid ? state : null
  const loading = !ownState || loaded !== revision
  const result = ownState?.result
  const data = result?.data
  const status = loading ? 'Đang tải' : result?.status === 'ready' ? 'Đã kết nối' : result?.status === 'empty' ? 'Chưa có dữ liệu' : 'Chưa kết nối'
  const display = (value?: number) => value === undefined ? '—' : value.toLocaleString('vi-VN')
  return <section className="admin-panel admin-monitor-section" aria-labelledby="analytics-events-title" aria-busy={loading}>
    <div className="admin-panel-heading">
      <div><span className="admin-eyebrow">FIREBASE ANALYTICS</span><h2 id="analytics-events-title">Sự kiện sử dụng ứng dụng</h2><p>7 ngày gần nhất, gồm hôm nay · Android · Số liệu hành vi người dùng.</p></div>
      <div className="admin-event-actions"><span className="admin-live-badge">{status}</span><button className="admin-secondary" type="button" disabled={loading} onClick={() => setRevision(value => value + 1)}>{loading ? 'Đang tải…' : 'Làm mới sự kiện'}</button></div>
    </div>
    {ownState?.error && <p className="admin-alert" role="alert">{ownState.error}</p>}
    {result?.message && <p className="admin-monitor-notice" role="status">{result.message}</p>}
    {data?.warnings.map(warning => <p key={warning} className="admin-monitor-notice">{warning}</p>)}
    <div className="admin-monitor-metrics">
      <div><span>Tổng lượt sự kiện</span><strong>{display(data?.eventCount)}</strong></div>
      <div><span>Người dùng trong kỳ</span><strong>{display(data?.totalUsers)}</strong></div>
    </div>
    <Chart title="Lượt sự kiện theo ngày" bars values={data?.days.map(day => day.count) ?? null} labels={data?.days.map(day => day.date.slice(5)) ?? []} />
    {data && <>
      <div className="admin-events-scroll"><table className="admin-events-table">
        <caption>Sự kiện Analytics · {data.startDate} – {data.endDate}</caption>
        <thead><tr><th scope="col">Sự kiện</th><th scope="col">Tên kỹ thuật</th><th scope="col">Lượt xảy ra</th><th scope="col">Người dùng</th></tr></thead>
        <tbody>{data.events.length ? data.events.map(event => <tr key={event.name}><th scope="row">{eventLabels[event.name] ?? 'Sự kiện tự động / khác'}</th><td><code>{event.name}</code></td><td>{display(event.count)}</td><td>{display(event.users)}</td></tr>) : <tr><td colSpan={4}>Chưa có sự kiện trong báo cáo.</td></tr>}</tbody>
      </table></div>
      <p className="admin-chart-footnote">Property {data.propertyId} · {data.streamId ? `Stream ${data.streamId}` : 'Tất cả stream Android trong property'} · Múi giờ {data.timeZone}. Người dùng được Google Analytics tổng hợp; không cộng số người dùng của các sự kiện/ngày thành tổng.</p>
    </>}
    <p className="admin-chart-footnote">Báo cáo có độ trễ xử lý, không phải DebugView. Bao gồm sự kiện tự động và sự kiện nghiệp vụ. Dấu — là chưa đọc được nguồn dữ liệu; không coi lỗi cấu hình là 0. Cache 60 giây{result ? ` · Đọc nguồn: ${new Date(result.fetchedAt).toLocaleString('vi-VN')}` : ''}.</p>
  </section>
}
