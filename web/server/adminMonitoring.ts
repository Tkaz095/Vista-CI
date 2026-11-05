import { googleCloudAccessToken } from './githubAuth.js'
import type { AdminMonitoring, CrashMetrics, FetchMetrics, MetricSource } from '../shared/adminMonitoring.js'

class SourceError extends Error {}

type CloudError = { error?: { code?: number; message?: string; errors?: { reason?: string }[] } }

async function cloud<T>(url: string, source: 'Monitoring' | 'BigQuery', body?: object): Promise<T> {
  const token = await googleCloudAccessToken()
  const response = await fetch(url, {
    method: body ? 'POST' : 'GET',
    headers: { Authorization: `Bearer ${token}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(15000),
  })
  const data = await response.json() as T & CloudError
  if (!response.ok) {
    if (response.status === 403)
      throw new SourceError(`${source}: API chưa bật hoặc service account thiếu quyền. Xem hướng dẫn cấu hình giám sát.`)
    if (response.status === 404)
      throw new SourceError(`${source}: chưa tìm thấy bảng/dataset hoặc sai Location. Kiểm tra dữ liệu export trong BigQuery.`)
    if (response.status === 429)
      throw new SourceError(`${source}: đã chạm giới hạn truy vấn. Vui lòng thử lại sau.`)
    if (data.error?.errors?.some((item) => item.reason === 'billingTierLimitExceeded') || /bytes billed|bytes.*limit/i.test(data.error?.message ?? ''))
      throw new SourceError('BigQuery: truy vấn vượt giới hạn 100 MB. Cần kiểm tra partition hoặc giảm lượng dữ liệu nguồn.')
    throw new SourceError(`${source}: không đọc được số liệu (HTTP ${response.status}). Kiểm tra tên bảng, Location và schema export.`)
  }
  return data
}

function projectId() {
  const value = process.env.FIREBASE_PROJECT_ID ?? ''
  if (!/^[a-z][a-z0-9-]{4,61}[a-z0-9]$/.test(value))
    throw new SourceError('Backend chưa cấu hình FIREBASE_PROJECT_ID hợp lệ.')
  return value
}

async function remoteMetrics(): Promise<{ data: FetchMetrics; empty: boolean; message: string | null }> {
  const appId = process.env.MONITORING_FIREBASE_APP_ID || '1:1087429884658:android:cdfbf3a5d8a08c0d1a6e6b'
  if (!/^[\w:.-]+$/.test(appId)) throw new SourceError('MONITORING_FIREBASE_APP_ID không hợp lệ.')
  // Use 24 completed UTC hours. The current partial hour is deliberately excluded.
  const end = Math.floor(Date.now() / 3600000) * 3600000
  const start = end - 24 * 3600000
  const points = Array.from({ length: 24 }, (_, index) => ({ time: new Date(start + index * 3600000).toISOString(), count: 0 }))
  type SeriesResponse = {
    timeSeries?: { points?: { interval: { endTime: string }; value: { int64Value?: string; doubleValue?: number } }[] }[]
    nextPageToken?: string
    executionErrors?: unknown[]
  }
  const params = new URLSearchParams({
    filter: `metric.type="firebaseremoteconfig.googleapis.com/project/fetch_request_count" AND metric.labels.app_id="${appId}"`,
    'interval.startTime': new Date(start).toISOString(),
    'interval.endTime': new Date(end).toISOString(),
    'aggregation.alignmentPeriod': '3600s',
    'aggregation.perSeriesAligner': 'ALIGN_SUM',
    'aggregation.crossSeriesReducer': 'REDUCE_SUM',
    view: 'FULL',
    pageSize: '1000',
  })
  const response = await cloud<SeriesResponse>(`https://monitoring.googleapis.com/v3/projects/${projectId()}/timeSeries?${params}`, 'Monitoring')
  if (response.nextPageToken || response.executionErrors?.length)
    throw new SourceError('Monitoring trả dữ liệu chưa đầy đủ. Chưa thể tổng hợp chính xác.')
  let received = false
  for (const series of response.timeSeries ?? []) {
    for (const point of series.points ?? []) {
      const timestamp = Date.parse(point.interval.endTime)
      const index = Math.ceil((timestamp - start) / 3600000) - 1
      const value = Number(point.value.int64Value ?? point.value.doubleValue)
      if (index >= 0 && index < points.length && Number.isFinite(value)) {
        points[index].count += value
        received = true
      }
    }
  }
  return {
    data: { appId, total: received ? points.reduce((sum, point) => sum + point.count, 0) : null, points: received ? points : [] },
    empty: !received,
    message: received ? null : 'Monitoring chưa trả điểm dữ liệu cho app Android trong 24 giờ hoàn chỉnh gần nhất. Không coi thiếu dữ liệu là 0.',
  }
}

function table(name: string, optional = false) {
  const value = process.env[name]?.trim()
  if (!value && optional) return null
  if (!value) throw new SourceError(`Chưa cấu hình ${name}. Bật Crashlytics export sang BigQuery rồi điền tên bảng đầy đủ.`)
  if (!/^[a-z][a-z0-9-]*\.[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*$/.test(value))
    throw new SourceError(`${name} phải có dạng project.dataset.table, không dùng wildcard.`)
  return `\`${value}\``
}

type QueryResponse = {
  jobComplete?: boolean
  jobReference?: { jobId: string; location: string }
  rows?: { f: { v: string }[] }[]
  errors?: { reason?: string }[]
}

async function query<T>(sql: string, start: string, end: string): Promise<T> {
  const location = process.env.BIGQUERY_LOCATION?.trim()
  if (!location || !/^[a-zA-Z0-9-]+$/.test(location))
    throw new SourceError('Chưa cấu hình BIGQUERY_LOCATION theo Location của dataset export.')
  const project = projectId()
  let result = await cloud<QueryResponse>(`https://bigquery.googleapis.com/bigquery/v2/projects/${project}/queries`, 'BigQuery', {
    query: sql,
    useLegacySql: false,
    useQueryCache: true,
    maximumBytesBilled: '104857600',
    timeoutMs: 8000,
    jobTimeoutMs: '15000',
    location,
    parameterMode: 'NAMED',
    queryParameters: [
      { name: 'start', parameterType: { type: 'TIMESTAMP' }, parameterValue: { value: start } },
      { name: 'end', parameterType: { type: 'TIMESTAMP' }, parameterValue: { value: end } },
    ],
  })
  const job = result.jobReference
  if (!result.jobComplete && job) {
    const params = new URLSearchParams({ location: job.location || location, timeoutMs: '8000', maxResults: '1' })
    result = await cloud<QueryResponse>(`https://bigquery.googleapis.com/bigquery/v2/projects/${project}/queries/${encodeURIComponent(job.jobId)}?${params}`, 'BigQuery')
  }
  if (!result.jobComplete || result.errors?.length)
    throw new SourceError('BigQuery chưa hoàn thành truy vấn. Chờ một lúc rồi bấm Làm mới; truy vấn có giới hạn thời gian và dung lượng.')
  const cell = result.rows?.[0]?.f?.[0]?.v
  if (!cell) throw new SourceError('BigQuery không trả dữ liệu tổng hợp hợp lệ.')
  return JSON.parse(cell) as T
}

interface CrashAggregate {
  crashes: number
  affectedUsers: number
  crashedSessions: number
  lastEvent: string | null
  days: { date: string; crashes: number; affectedUsers: number }[]
}
interface SessionAggregate {
  users: number
  sessions: number
  days: { date: string; users: number }[]
}

function ratio(affected: number, total: number) {
  // A missing/incomplete denominator must not turn into a misleading 100%.
  return total > 0 && affected <= total ? Math.round((1 - affected / total) * 10000) / 100 : null
}

async function crashMetrics(): Promise<{ data: CrashMetrics; empty: boolean; message: string | null }> {
  const crashTable = table('CRASHLYTICS_BIGQUERY_TABLE')
  const end = new Date()
  const first = new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth(), end.getUTCDate() - 6))
  const start = first.toISOString()
  // Select a single export table (batch OR realtime); never double count both.
  const crash = await query<CrashAggregate>(`
    WITH events AS (
      SELECT event_id, installation_uuid, firebase_session_id, event_timestamp
      FROM ${crashTable}
      WHERE event_timestamp >= @start AND event_timestamp < @end AND error_type = 'FATAL'
      QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY event_timestamp DESC) = 1
    ), daily AS (
      SELECT CAST(DATE(event_timestamp) AS STRING) AS date,
        COUNT(*) AS crashes, COUNT(DISTINCT installation_uuid) AS affectedUsers
      FROM events GROUP BY date
    )
    SELECT TO_JSON_STRING(STRUCT(
      (SELECT COUNT(*) FROM events) AS crashes,
      (SELECT COUNT(DISTINCT installation_uuid) FROM events) AS affectedUsers,
      (SELECT COUNT(DISTINCT firebase_session_id) FROM events) AS crashedSessions,
      (SELECT CAST(MAX(event_timestamp) AS STRING) FROM events) AS lastEvent,
      ARRAY(SELECT AS STRUCT * FROM daily ORDER BY date) AS days
    ))`, start, end.toISOString())
  let sessions: SessionAggregate | null = null
  let sessionsMessage: string | null = null
  try {
    const sessionsTable = table('SESSIONS_BIGQUERY_TABLE', true)
    if (sessionsTable) {
      sessions = await query<SessionAggregate>(`
        WITH events AS (
          SELECT instance_id, session_id, event_timestamp FROM ${sessionsTable}
          WHERE event_timestamp >= @start AND event_timestamp < @end
            AND crashlytics_data_collection_enabled = TRUE
        ), daily AS (
          SELECT CAST(DATE(event_timestamp) AS STRING) AS date, COUNT(DISTINCT instance_id) AS users
          FROM events GROUP BY date
        )
        SELECT TO_JSON_STRING(STRUCT(
          (SELECT COUNT(DISTINCT instance_id) FROM events) AS users,
          (SELECT COUNT(DISTINCT session_id) FROM events) AS sessions,
          ARRAY(SELECT AS STRUCT * FROM daily ORDER BY date) AS days
        ))`, start, end.toISOString())
    } else sessionsMessage = 'Chưa cấu hình SESSIONS_BIGQUERY_TABLE; chưa tính được tỷ lệ không crash.'
  } catch (error) {
    sessionsMessage = error instanceof SourceError ? error.message : 'Không đọc được Firebase Sessions; số crash vẫn được hiển thị.'
  }
  const days = Array.from({ length: 7 }, (_, index) => {
    const date = new Date(first.getTime() + index * 86400000).toISOString().slice(0, 10)
    const day = crash.days.find((item) => item.date === date)
    const users = sessions?.days.find((item) => item.date === date)?.users ?? 0
    return { date, crashes: day?.crashes ?? 0, crashFreeUsers: sessions ? ratio(day?.affectedUsers ?? 0, users) : null }
  })
  return {
    data: {
      crashes: crash.crashes, affectedUsers: crash.affectedUsers,
      crashFreeUsers: sessions ? ratio(crash.affectedUsers, sessions.users) : null,
      crashFreeSessions: sessions && (crash.crashes === 0 || crash.crashedSessions > 0) ? ratio(crash.crashedSessions, sessions.sessions) : null,
      days, sessionsMessage,
    },
    empty: crash.crashes === 0 && !sessions?.sessions,
    message: 'Nguồn BigQuery export · 7 ngày theo UTC, gồm hôm nay · Tất cả phiên bản Android · Có độ trễ export; có thể khác bộ lọc trên Firebase Console. Người dùng được đếm theo bản cài đặt.',
  }
}

async function source<T>(read: () => Promise<{ data: T; empty: boolean; message: string | null }>): Promise<MetricSource<T>> {
  try {
    const result = await read()
    return { status: result.empty ? 'empty' : 'ready', data: result.data, message: result.message, fetchedAt: new Date().toISOString() }
  } catch (error) {
    return { status: 'unavailable', data: null, message: error instanceof SourceError ? error.message : 'Không kết nối được nguồn thống kê. Kiểm tra credential backend và thử lại.', fetchedAt: new Date().toISOString() }
  }
}

// Short process-local cache and shared in-flight promise avoid repeat billed queries.
let cached: { expires: number; value: AdminMonitoring } | undefined
let pending: Promise<AdminMonitoring> | undefined
export async function loadMonitoring(): Promise<AdminMonitoring> {
  if (cached && cached.expires > Date.now()) return cached.value
  if (pending) return pending
  pending = Promise.all([source(remoteMetrics), source(crashMetrics)]).then(([remoteConfig, crashlytics]) => {
    const value = { remoteConfig, crashlytics, generatedAt: new Date().toISOString() }
    cached = { expires: Date.now() + 60000, value }
    return value
  }).finally(() => { pending = undefined })
  return pending
}
