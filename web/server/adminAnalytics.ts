import type { AdminAnalytics, AnalyticsMetrics } from '../shared/adminAnalytics.js'
import { analyticsAccessToken } from './analyticsCredentials.js'

class AnalyticsError extends Error {}

async function analyticsResponseError(response: Response, propertyId: string): Promise<string> {
  if (response.status === 403) {
    // Inspect only known error codes; provider messages and payloads stay server-side.
    const body = await response.json().catch(() => null) as {
      error?: { message?: unknown; details?: { reason?: string; domain?: string; metadata?: { service?: string } }[] }
    } | null
    const details = Array.isArray(body?.error?.details) ? body.error.details : []
    if (details.some(detail => detail?.domain === 'googleapis.com' &&
      detail.reason === 'SERVICE_DISABLED' && detail.metadata?.service === 'analyticsdata.googleapis.com'))
      return 'Google Analytics Data API chưa bật cho project của credential backend. Bật analyticsdata.googleapis.com trong Google Cloud rồi thử lại.'
    if (details.some(detail => detail?.domain === 'googleapis.com' && detail.reason === 'ACCESS_TOKEN_SCOPE_INSUFFICIENT'))
      return 'Token backend thiếu scope analytics.readonly. Kiểm tra credential Analytics; với ADC user, đăng nhập lại ADC có scope Analytics.'
    if (typeof body?.error?.message === 'string' &&
      body.error.message.includes('User does not have sufficient permissions for this property'))
      return `Credential backend không có quyền đọc GA4 property ${propertyId}. Đối chiếu GA4_PROPERTY_ID với Property ID trong Google Analytics → Admin → Property details; cấp Viewer cho đúng service account tại Property access management của chính property này. Quyền Firebase IAM không thay thế quyền GA4.`
    return `Google Analytics từ chối truy cập GA4 property ${propertyId} (HTTP 403). Kiểm tra Property ID, quyền Viewer của credential backend và Google Analytics Data API.`
  }
  const messages: Record<number, string> = {
    401: 'Credential backend chưa xác thực được Google Analytics. Kiểm tra service account và scope analytics.readonly.',
    404: `Không tìm thấy GA4 property ${propertyId}. Kiểm tra GA4_PROPERTY_ID và quyền service account.`,
    429: 'Google Analytics đang giới hạn truy vấn. Chờ một lúc rồi thử lại.',
  }
  return messages[response.status] ?? `Chưa đọc được Google Analytics (HTTP ${response.status}). Vui lòng thử lại.`
}
interface Report {
  dimensionHeaders?: { name: string }[]
  metricHeaders?: { name: string }[]
  rows?: { dimensionValues?: { value: string }[]; metricValues?: { value: string }[] }[]
  rowCount?: number
  metadata?: { timeZone?: string; subjectToThresholding?: boolean; dataLossFromOtherRow?: boolean; samplingMetadatas?: unknown[] }
}

function number(value: string | undefined): number {
  if (value === undefined || !/^\d+$/.test(value) || !Number.isSafeInteger(Number(value)))
    throw new AnalyticsError('Analytics trả số liệu không hợp lệ. Vui lòng thử lại.')
  return Number(value)
}

function rows(report: Report, dimensions: string[]) {
  if ((report.dimensionHeaders ?? []).map(item => item.name).join(',') !== dimensions.join(',') ||
      report.metricHeaders?.map(item => item.name).join(',') !== 'eventCount,totalUsers')
    throw new AnalyticsError('Analytics trả cấu trúc báo cáo không hợp lệ.')
  return (report.rows ?? []).map(row => {
    if ((row.dimensionValues?.length ?? 0) !== dimensions.length || row.metricValues?.length !== 2)
      throw new AnalyticsError('Analytics trả dòng báo cáo không hợp lệ.')
    return { dimensions: row.dimensionValues?.map(item => item.value) ?? [], count: number(row.metricValues[0]?.value), users: number(row.metricValues[1]?.value) }
  })
}

function isoDate(date: Date, timeZone: string) {
  const parts = new Intl.DateTimeFormat('en', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(date)
  const part = (type: string) => parts.find(item => item.type === type)?.value
  return `${part('year')}-${part('month')}-${part('day')}`
}

export function parseAnalyticsReports(reports: Report[], propertyId: string, streamId: string | null, now: Date): AnalyticsMetrics {
  if (reports.length !== 3 || reports.some(report => !report || typeof report !== 'object'))
    throw new AnalyticsError('Analytics chưa trả đủ ba báo cáo.')
  const [summary, eventReport, dailyReport] = reports
  const total = rows(summary, [])
  if (total.length > 1) throw new AnalyticsError('Analytics trả tổng hợp không hợp lệ.')
  const events = rows(eventReport, ['eventName']).map(row => ({ name: row.dimensions[0], count: row.count, users: row.users }))
  const daily = rows(dailyReport, ['date'])
  if ((dailyReport.rowCount ?? daily.length) > daily.length)
    throw new AnalyticsError('Analytics trả dữ liệu theo ngày chưa đầy đủ.')
  const timeZone = summary.metadata?.timeZone
  if (!timeZone || reports.some(report => report.metadata?.timeZone !== timeZone))
    throw new AnalyticsError('Analytics chưa trả múi giờ báo cáo nhất quán.')
  const endDate = isoDate(now, timeZone)
  const start = new Date(`${endDate}T00:00:00Z`)
  start.setUTCDate(start.getUTCDate() - 6)
  const days = Array.from({ length: 7 }, (_, index) => {
    const date = new Date(start.getTime() + index * 86400000).toISOString().slice(0, 10)
    const row = daily.find(item => item.dimensions[0] === date.replaceAll('-', ''))
    return { date, count: row?.count ?? 0, users: row?.users ?? 0 }
  })
  const warnings: string[] = []
  if ((eventReport.rowCount ?? events.length) > events.length) warnings.push('Bảng hiển thị 100 sự kiện nhiều lượt nhất; tổng lượt lấy từ báo cáo riêng.')
  if (reports.some(report => report.metadata?.subjectToThresholding)) warnings.push('Google Analytics có thể áp dụng ngưỡng bảo vệ dữ liệu cho báo cáo này.')
  if (reports.some(report => report.metadata?.dataLossFromOtherRow || report.metadata?.samplingMetadatas?.length)) warnings.push('Nguồn báo cáo có lấy mẫu hoặc giới hạn số chiều; số liệu có thể không đầy đủ.')
  return { propertyId, streamId, timeZone, startDate: days[0].date, endDate, eventCount: total[0]?.count ?? 0, totalUsers: total[0]?.users ?? 0, events, days, warnings }
}

// Factory keeps cached data isolated by property/stream and allows offline tests.
export function createAnalyticsLoader(deps: {
  token: () => Promise<string>
  fetch: typeof fetch
  env: () => { propertyId?: string; streamId?: string }
  now: () => Date
}) {
  let cache: { key: string; expires: number; value: AdminAnalytics } | undefined
  const pending = new Map<string, Promise<AdminAnalytics>>()
  return async (): Promise<AdminAnalytics> => {
    const configuration = deps.env()
    const propertyId = configuration.propertyId?.trim() ?? ''
    const streamId = configuration.streamId?.trim() || null
    const key = `${propertyId}/${streamId}`
    if (cache?.key === key && cache.expires > deps.now().getTime()) return cache.value
    const inFlight = pending.get(key)
    if (inFlight) return inFlight
    const task = (async (): Promise<AdminAnalytics> => {
      try {
        if (!/^\d{1,20}$/.test(propertyId)) throw new AnalyticsError('Thêm GA4_PROPERTY_ID vào môi trường backend. Đây là Property ID dạng số trong Google Analytics, không phải Firebase Project ID hay G-Measurement ID. Xem docs/project/28-admin-analytics.md.')
        if (streamId && !/^\d{1,20}$/.test(streamId)) throw new AnalyticsError('GA4_ANDROID_STREAM_ID phải là Stream ID dạng số.')
        const filters = [{ filter: { fieldName: 'platform', stringFilter: { matchType: 'EXACT', value: 'Android' } } }]
        if (streamId) filters.push({ filter: { fieldName: 'streamId', stringFilter: { matchType: 'EXACT', value: streamId } } })
        const base = { dateRanges: [{ startDate: '6daysAgo', endDate: 'today' }], metrics: [{ name: 'eventCount' }, { name: 'totalUsers' }], dimensionFilter: { andGroup: { expressions: filters } } }
        const token = await deps.token()
        const response = await deps.fetch(`https://analyticsdata.googleapis.com/v1beta/properties/${propertyId}:batchRunReports`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
          signal: AbortSignal.timeout(15000),
          body: JSON.stringify({ requests: [
            { ...base },
            { ...base, dimensions: [{ name: 'eventName' }], orderBys: [{ metric: { metricName: 'eventCount' }, desc: true }], limit: '100' },
            { ...base, dimensions: [{ name: 'date' }], orderBys: [{ dimension: { dimensionName: 'date' } }], limit: '7' },
          ] }),
        })
        if (!response.ok) {
          throw new AnalyticsError(await analyticsResponseError(response, propertyId))
        }
        const body = await response.json() as { reports?: Report[] }
        const data = parseAnalyticsReports(body.reports ?? [], propertyId, streamId, deps.now())
        const value: AdminAnalytics = { status: data.eventCount || data.totalUsers || data.events.length ? 'ready' : 'empty', data, message: data.eventCount ? null : 'Chưa có sự kiện trong báo cáo. Dữ liệu có độ trễ xử lý; dữ liệu debug có thể bị loại bởi bộ lọc GA4.', fetchedAt: deps.now().toISOString() }
        cache = { key, expires: deps.now().getTime() + 60000, value }
        return value
      } catch (error) {
        return { status: 'unavailable', data: null, message: error instanceof AnalyticsError ? error.message : 'Không kết nối được Google Analytics. Kiểm tra credential backend, mạng và thử lại.', fetchedAt: deps.now().toISOString() }
      }
    })()
    pending.set(key, task)
    try { return await task } finally { pending.delete(key) }
  }
}

export const loadAnalytics = createAnalyticsLoader({ token: analyticsAccessToken, fetch: (...args) => fetch(...args), env: () => ({ propertyId: process.env.GA4_PROPERTY_ID, streamId: process.env.GA4_ANDROID_STREAM_ID }), now: () => new Date() })
