import { useEffect, useId, useState } from 'react'
import type { User } from 'firebase/auth'
import type { AdminMonitoring } from '../../../shared/adminMonitoring'
import { loadAdminMonitoring } from './adminService'

export function Chart({ title, values, labels, percent = false, bars = false }: {
  title: string
  values: (number | null)[] | null
  labels: string[]
  percent?: boolean
  bars?: boolean
}) {
  const id = useId()
  const [selected, setSelected] = useState<number | null>(null)
  const max = percent ? 100 : Math.max(1, ...(values ?? []).filter((value): value is number => value !== null))
  const x = (index: number) => 52 + index * (496 / Math.max(1, labels.length - 1))
  const y = (value: number) => 196 - value / max * 160
  const path = values?.map((value, index) => value === null ? '' : `${index === 0 || values[index - 1] === null ? 'M' : 'L'}${x(index)},${y(value)}`).join(' ')
  return <figure className="admin-monitor-chart">
    <figcaption>{title}</figcaption>
    <svg viewBox="0 0 580 240" role="img" aria-labelledby={`${id}-title`}>
      <title id={`${id}-title`}>{title}{values ? ' — dữ liệu Firebase' : ' — chưa kết nối dữ liệu'}</title>
      {[0, 1, 2, 3, 4].map((step) => {
        const value = max * step / 4
        return <g key={step}>
          <line x1="52" x2="548" y1={y(value)} y2={y(value)} className="admin-monitor-grid" />
          <text x="42" y={y(value) + 4} textAnchor="end">{percent ? `${value}%` : Number(value.toFixed(1))}</text>
        </g>
      })}
      {values && !bars && <path d={path} fill="none" className="admin-monitor-line" />}
      {values?.map((value, index) => value === null ? null : <g key={index}>
        {bars ? <rect x={x(index) - 14} y={y(value)} width="28" height={196 - y(value)} rx="4" className="admin-monitor-bar" /> : <circle cx={x(index)} cy={y(value)} r="4" className="admin-monitor-point" />}
      </g>)}
      {labels.map((label, index) => <g key={label}>
        {(labels.length <= 7 || index % 3 === 0 || index === labels.length - 1) && <text x={x(index)} y="224" textAnchor="middle">{label}</text>}
      </g>)}
    </svg>
    {values ? <>
      <div className="admin-chart-values" aria-label={`Chọn mốc để xem ${title.toLowerCase()}`}>
        {values.map((value, index) => <button type="button" key={index} aria-pressed={selected === index} onClick={() => setSelected(index)} onMouseEnter={() => setSelected(index)} onFocus={() => setSelected(index)} aria-label={`${labels[index]}: ${value === null ? 'Chưa đủ dữ liệu' : `${value}${percent ? '%' : ''}`}`}>{labels[index]}</button>)}
      </div>
      <p className="admin-chart-reading" aria-live="polite">{selected === null ? 'Chọn một mốc thời gian để xem chi tiết.' : `${labels[selected]}: ${values[selected] === null ? 'Chưa đủ dữ liệu' : `${values[selected]}${percent ? '%' : ''}`}`}</p>
    </> : <p className="admin-monitor-empty">Chưa có đủ dữ liệu để hiển thị biểu đồ.</p>}
  </figure>
}

const display = (value: number | null | undefined, percent = false) =>
  value == null ? '—' : `${value.toLocaleString('vi-VN', { maximumFractionDigits: 2 })}${percent ? '%' : ''}`

export function MonitoringPanel({ user }: { user: User }) {
  const [result, setResult] = useState<AdminMonitoring | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [revision, setRevision] = useState(0)
  useEffect(() => {
    let active = true
    void loadAdminMonitoring(user).then((value) => {
      if (active) setResult(value)
    }).catch((cause: unknown) => {
      if (active) setError(cause instanceof Error ? cause.message : 'Không tải được thống kê.')
    }).finally(() => { if (active) setLoading(false) })
    return () => { active = false }
  }, [user, revision])

  const remote = result?.remoteConfig
  const crash = result?.crashlytics
  const fetches = remote?.data
  const crashes = crash?.data
  const dateLabels = crashes?.days.map((day) => day.date.slice(5)) ?? []
  const status = (value: typeof remote | typeof crash) =>
    !value ? 'Chờ tải' : value.status === 'unavailable' ? 'Cần cấu hình' : value.status === 'empty' ? 'Chưa có dữ liệu' : 'Đã kết nối'
  const refreshed = (value: typeof remote | typeof crash) => value ? new Date(value.fetchedAt).toLocaleString('vi-VN') : '—'
  return <>
    <div className="admin-page-heading">
      <div><span className="admin-eyebrow">VẬN HÀNH ỨNG DỤNG</span><h1>Giám sát ứng dụng</h1><p>Số liệu Remote Config và Crashlytics của Vista CI Android.</p></div>
      <button className="admin-secondary" type="button" disabled={loading} onClick={() => { setLoading(true); setError(''); setRevision((value) => value + 1) }}>{loading ? 'Đang tải…' : 'Làm mới'}</button>
    </div>
    {loading && <p role="status" className="admin-loading">Đang đọc nguồn thống kê Google Cloud…</p>}
    {error && <div className="admin-alert" role="alert">{error}{result && ' Đang giữ kết quả tải trước đó.'}</div>}
    <section className="admin-panel admin-monitor-section" aria-labelledby="monitor-fetch-title" aria-busy={loading}>
      <div className="admin-panel-heading"><div><h2 id="monitor-fetch-title">Lượt tải cấu hình</h2><p>Cloud Monitoring · 24 giờ hoàn chỉnh gần nhất · App Android.</p></div><span className="admin-live-badge">{status(remote)}</span></div>
      {remote?.message && <p className="admin-monitor-notice" role="status">{remote.message}</p>}
      <div className="admin-monitor-metrics"><div><span>Tổng lượt tải</span><strong>{display(fetches?.total)}</strong></div></div>
      <Chart title="Lượt fetch theo giờ (UTC)" values={fetches?.points.length ? fetches.points.map((point) => point.count) : null} labels={fetches?.points.map((point) => point.time.slice(11, 16)) ?? []} />
      <p className="admin-chart-footnote">Đọc nguồn: {refreshed(remote)} · Metric này không cung cấp số người tải duy nhất.</p>
    </section>
    <section className="admin-panel admin-monitor-section" aria-labelledby="monitor-crash-title" aria-busy={loading}>
      <div className="admin-panel-heading"><div><h2 id="monitor-crash-title">Độ ổn định ứng dụng</h2><p>Lỗi của app Vista CI; không phải lỗi workflow GitHub.</p></div><span className="admin-live-badge">{status(crash)}</span></div>
      {crash?.message && <p className="admin-monitor-notice" role="status">{crash.message}</p>}
      {crashes?.sessionsMessage && <p className="admin-monitor-notice" role="status">{crashes.sessionsMessage}</p>}
      <div className="admin-monitor-metrics"><div><span>Người dùng không gặp crash</span><strong>{display(crashes?.crashFreeUsers, true)}</strong></div><div><span>Phiên không gặp crash</span><strong>{display(crashes?.crashFreeSessions, true)}</strong></div><div><span>Số crash</span><strong>{display(crashes?.crashes)}</strong></div><div><span>Bản cài đặt bị ảnh hưởng</span><strong>{display(crashes?.affectedUsers)}</strong></div></div>
      <div className="admin-monitor-grid-layout">
        <Chart title="Người dùng không gặp crash theo ngày" percent values={crashes ? crashes.days.map((day) => day.crashFreeUsers) : null} labels={dateLabels} />
        <Chart title="Xu hướng crash" bars values={crashes ? crashes.days.map((day) => day.crashes) : null} labels={dateLabels} />
      </div>
      <p className="admin-chart-footnote">Đọc nguồn: {refreshed(crash)} · Chỉ sự kiện FATAL · Dấu — là chưa đủ dữ liệu. Backend cache kết quả trong 60 giây.</p>
    </section>
  </>
}
