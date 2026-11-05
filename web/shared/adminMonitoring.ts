export interface FetchMetrics {
  total: number | null
  points: { time: string; count: number }[]
  appId: string
}

export interface CrashMetrics {
  crashes: number
  affectedUsers: number
  crashFreeUsers: number | null
  crashFreeSessions: number | null
  days: { date: string; crashes: number; crashFreeUsers: number | null }[]
  sessionsMessage: string | null
}

export type MetricSource<T> =
  | { status: 'ready' | 'empty'; data: T; message: string | null; fetchedAt: string }
  | { status: 'unavailable'; data: null; message: string; fetchedAt: string }

export interface AdminMonitoring {
  remoteConfig: MetricSource<FetchMetrics>
  crashlytics: MetricSource<CrashMetrics>
  generatedAt: string
}
