import type { User } from 'firebase/auth'

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
  resource: 'overview' | 'config' | 'monitoring',
  method: 'GET' | 'PUT' = 'GET',
  body?: unknown,
): Promise<T> {
  const token = await user.getIdToken()
  const response = await fetch(`/api/admin?resource=${resource}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
    cache: 'no-store',
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
  request<import('../../../shared/adminMonitoring').AdminMonitoring>(user, 'monitoring')
