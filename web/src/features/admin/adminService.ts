import type { User } from 'firebase/auth'
import type { AdminNotificationDraft, AdminNotificationResult, NotificationRecipient, NotificationRecipientsPage } from '../../../shared/adminNotifications.js'

export interface AdminOverview {
  stats: {
    users: number
    activeUsers: number
    workspaces: number
    activeWorkspaces: number
  }
  workspacesByDay: { date: string; count: number }[]
}

export interface RemoteConfigValues {
  ci_analysis_enabled: string
  cloudinary_cloud_name: string
  cloudinary_upload_preset: string
}

export interface RemoteConfigSnapshot {
  values: RemoteConfigValues
  version: string
}

export interface RemoteConfigUpdate {
  version: string
  values: {
    ci_analysis_enabled: boolean
    cloudinary_cloud_name: string
    cloudinary_upload_preset: string
  }
}

export class AdminApiError extends Error {
  readonly status: number

  constructor(
    message: string,
    status: number,
  ) {
    super(message)
    this.name = 'AdminApiError'
    this.status = status
  }
}

async function request<T>(
  user: User,
  resource: 'overview' | 'config' | 'monitoring' | 'notification-recipients' | 'notifications',
  method: 'GET' | 'PUT' | 'POST' = 'GET',
  body?: unknown,
  query?: Record<string, string>,
): Promise<T> {
  const token = await user.getIdToken()
  const parameters = new URLSearchParams({ resource, ...query })
  const response = await fetch(`/api/admin?${parameters}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
    cache: 'no-store',
    signal: resource === 'notifications' ? AbortSignal.timeout(25000) : undefined,
  })
  const result = (await response.json().catch(() => null)) as
    | { message?: unknown }
    | null
  if (!response.ok)
    throw new AdminApiError(
      typeof result?.message === 'string'
        ? result.message
        : `API admin trả HTTP ${response.status} mà không có thông báo JSON. Kiểm tra Runtime Logs của deployment.`,
      response.status,
    )
  return result as T
}

export const loadAdminOverview = (user: User) => request<AdminOverview>(user, 'overview')
export const loadRemoteConfig = (user: User) => request<RemoteConfigSnapshot>(user, 'config')
export const saveRemoteConfig = (user: User, snapshot: RemoteConfigUpdate) =>
  request<RemoteConfigSnapshot>(user, 'config', 'PUT', {
    version: snapshot.version,
    parameters: snapshot.values,
  })

export const loadAdminMonitoring = (user: User) =>
  request<import('../../../shared/adminMonitoring.js').AdminMonitoring>(user, 'monitoring')

export const loadNotificationRecipients = (user: User, cursor?: string) =>
  request<NotificationRecipientsPage>(user, 'notification-recipients', 'GET', undefined, cursor ? { cursor } : undefined)

export const sendNotification = (user: User, draft: AdminNotificationDraft) =>
  request<AdminNotificationResult>(user, 'notifications', 'POST', draft)

export const loadNotificationResult = (user: User, id: string) =>
  request<AdminNotificationResult>(user, 'notifications', 'GET', undefined, { id })

export interface NotificationDelivery {
  draft: AdminNotificationDraft
  displayName: string
  state: 'pending' | 'sending' | 'completed' | 'failed' | 'unknown'
  result?: AdminNotificationResult
  error?: string
}

export async function loadAllNotificationRecipients(user: User) {
  const recipients = new Map<string, NotificationRecipient>()
  let cursor: string | undefined
  do {
    const page = await loadNotificationRecipients(user, cursor)
    for (const recipient of page.recipients) recipients.set(recipient.uid, recipient)
    cursor = page.nextCursor ?? undefined
  } while (cursor)
  return [...recipients.values()]
}

// Use the existing per-user API so every user keeps their own inbox and request ID.
// Three requests at a time keep a broadcast from becoming one long server request.
export async function deliverNotifications(
  user: User,
  deliveries: NotificationDelivery[],
  action: 'send' | 'check',
  onProgress: (deliveries: NotificationDelivery[]) => void,
  shouldContinue: () => boolean,
) {
  const next = deliveries.map(item => ({ ...item }))
  const indexes = next.flatMap((item, index) =>
    item.state === (action === 'send' ? 'pending' : 'unknown') ? [index] : [])
  let paused = false
  const update = (index: number, change: Partial<NotificationDelivery>) => {
    next[index] = { ...next[index], ...change }
    if (shouldContinue()) onProgress([...next])
  }
  for (let start = 0; start < indexes.length; start += 3) {
    if (paused || !shouldContinue()) break
    await Promise.all(indexes.slice(start, start + 3).map(async index => {
      const item = next[index]
      if (action === 'send') update(index, { state: 'sending', error: undefined })
      try {
        const result = action === 'send'
          ? await sendNotification(user, item.draft)
          : await loadNotificationResult(user, item.draft.requestId)
        if (result.state === 'sending') paused = true
        update(index, {
          result, state: result.state === 'completed' ? 'completed' : 'unknown',
          error: result.state === 'sending' ? 'Server đã lưu lịch sử, chưa xác nhận hoàn tất gửi.' : undefined,
        })
      } catch (cause) {
        if (action === 'check' && cause instanceof AdminApiError && cause.status === 404) {
          // A later send keeps this exact request ID even if the first POST arrives late.
          update(index, { state: 'pending', error: undefined })
          return
        }
        const uncertain = action === 'check' || !(cause instanceof AdminApiError) || cause.status >= 500
        if (uncertain || (cause instanceof AdminApiError && [401, 403].includes(cause.status))) paused = true
        update(index, {
          state: uncertain ? 'unknown' : 'failed',
          error: uncertain ? 'Chưa xác nhận kết quả. Kiểm tra trước khi gửi tiếp.' : cause instanceof Error ? cause.message : 'Không gửi được thông báo.',
        })
      }
    }))
  }
  return next
}
