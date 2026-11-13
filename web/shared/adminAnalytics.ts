import type { MetricSource } from './adminMonitoring.js'

export interface AnalyticsMetrics {
  propertyId: string
  streamId: string | null
  timeZone: string
  startDate: string
  endDate: string
  eventCount: number
  totalUsers: number
  events: { name: string; count: number; users: number }[]
  days: { date: string; count: number; users: number }[]
  warnings: string[]
}

export type AdminAnalytics = MetricSource<AnalyticsMetrics>
