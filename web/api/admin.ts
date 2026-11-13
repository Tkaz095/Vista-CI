import type { IncomingMessage, ServerResponse } from 'node:http'
import { Timestamp } from 'firebase-admin/firestore'
import type { RemoteConfigTemplate } from 'firebase-admin/remote-config'
import {
  ApiError,
  authenticateAdmin,
  database,
  firebaseAuth,
  json,
  logAdminFailure,
  messaging,
  remoteConfig,
} from '../server/githubAuth.js'

import { loadMonitoring } from '../server/adminMonitoring.js'
import { loadAnalytics } from '../server/adminAnalytics.js'
import { listNotificationRecipients, parseNotificationDraft, readNotificationResult, sendAdminNotification } from '../server/adminNotifications.js'

const configDefaults = {
  ci_analysis_enabled: 'true',
  cloudinary_cloud_name: '',
  cloudinary_upload_preset: '',
} as const
type ConfigKey = keyof typeof configDefaults

function configValues(template: RemoteConfigTemplate) {
  return Object.fromEntries(
    Object.keys(configDefaults).map((key) => {
        const defaultValue = template.parameters?.[key]?.defaultValue
        const value =
          typeof defaultValue === 'object' &&
          defaultValue !== null &&
          'value' in defaultValue &&
          typeof defaultValue.value === 'string'
            ? defaultValue.value
            : configDefaults[key as ConfigKey]
        return [key, value]
      }),
    ) as Record<ConfigKey, string>
}

async function overview() {
  const users = database().collection('users'),
    workspaces = database().collection('workspaces')
  const [userCount, activeUserCount, workspaceCount, activeWorkspaceCount] = await Promise.all([
    users.count().get(),
    users.where('isActive', '==', true).count().get(),
    workspaces.count().get(),
    workspaces.where('status', '==', 'active').count().get(),
  ])
  const today = new Date(),
    firstDay = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() - 13)),
    timeline = Array.from({ length: 14 }, (_, index) => {
      const date = new Date(firstDay.getTime())
      date.setUTCDate(firstDay.getUTCDate() + index)
      return { date: date.toISOString().slice(0, 10), count: 0 }
    }),
    counts = new Map(timeline.map((item) => [item.date, item]))
  const recentWorkspaces = await workspaces
    .where('createdAt', '>=', Timestamp.fromDate(firstDay))
    .get()
  for (const workspace of recentWorkspaces.docs) {
    const createdAt = workspace.get('createdAt')
    if (createdAt instanceof Timestamp) {
      const day = counts.get(createdAt.toDate().toISOString().slice(0, 10))
      if (day) day.count += 1
    }
  }
  return {
    stats: {
      users: userCount.data().count,
      activeUsers: activeUserCount.data().count,
      workspaces: workspaceCount.data().count,
      activeWorkspaces: activeWorkspaceCount.data().count,
    },
    workspacesByDay: timeline,
  }
}

async function readBody(req: IncomingMessage): Promise<unknown> {
  const request = req as IncomingMessage & { body?: unknown }
  if (request.body !== undefined) {
    if (typeof request.body === 'string') {
      try {
        return JSON.parse(request.body)
      } catch {
        throw new ApiError(400, 'INVALID_JSON', 'Dữ liệu cấu hình không hợp lệ.')
      }
    }
    return request.body
  }
  const chunks: Buffer[] = []
  let size = 0
  for await (const chunk of req) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)
    size += buffer.byteLength
    if (size > 16 * 1024) throw new ApiError(413, 'REQUEST_TOO_LARGE', 'Dữ liệu cấu hình quá lớn.')
    chunks.push(buffer)
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'))
  } catch {
    throw new ApiError(400, 'INVALID_JSON', 'Dữ liệu cấu hình không hợp lệ.')
  }
}

function parseParameters(value: unknown): Record<ConfigKey, string> {
  if (typeof value !== 'object' || value === null)
    throw new ApiError(400, 'INVALID_CONFIG', 'Thiếu các tham số cấu hình.')
  const input = value as Record<string, unknown>
  if (typeof input.ci_analysis_enabled !== 'boolean')
    throw new ApiError(400, 'INVALID_CONFIG', 'Trạng thái phân tích CI phải là bật hoặc tắt.')
  const cloudName = input.cloudinary_cloud_name,
    preset = input.cloudinary_upload_preset
  const containsControl = (text: string) =>
    Array.from(text).some((character) => {
      const code = character.charCodeAt(0)
      return code < 32 || (code >= 127 && code <= 159)
    })
  if (
    typeof cloudName !== 'string' ||
    cloudName.trim().length > 128 ||
    containsControl(cloudName) ||
    typeof preset !== 'string' ||
    preset.trim().length > 128 ||
    containsControl(preset)
  )
    throw new ApiError(400, 'INVALID_CONFIG', 'Cloud name và upload preset tối đa 128 ký tự.')
  return {
    ci_analysis_enabled: String(input.ci_analysis_enabled),
    cloudinary_cloud_name: cloudName.trim(),
    cloudinary_upload_preset: preset.trim(),
  }
}

export default async function adminApi(req: IncomingMessage, res: ServerResponse) {
  res.setHeader('Cache-Control', 'no-store, private')
  try {
    const admin = await authenticateAdmin(req)
    const parameters = new URL(req.url ?? '/', 'http://localhost').searchParams
    const resource = parameters.get('resource')
    if (resource === 'analytics-events' && req.method === 'GET') {
      json(res, 200, await loadAnalytics())
      return
    }
    if (resource === 'notification-recipients' && req.method === 'GET') {
      json(res, 200, await listNotificationRecipients(database(), firebaseAuth(), parameters.get('cursor')))
      return
    }
    if (resource === 'notifications' && req.method === 'GET') {
      json(res, 200, await readNotificationResult(database(), admin.uid, parameters.get('id') ?? ''))
      return
    }
    if (resource === 'notifications' && req.method === 'POST') {
      const draft = parseNotificationDraft(await readBody(req))
      json(res, 200, await sendAdminNotification(database(), firebaseAuth(), message => messaging().send(message), admin.uid, draft))
      return
    }
    if (resource === 'monitoring' && req.method === 'GET') {
      json(res, 200, await loadMonitoring())
      return
    }
    if (resource === 'overview' && req.method === 'GET') {
      json(res, 200, await overview())
      return
    }
    if (resource === 'config' && req.method === 'GET') {
      const template = await remoteConfig().getTemplate()
      json(res, 200, { values: configValues(template), version: template.etag })
      return
    }
    if (resource === 'config' && req.method === 'PUT') {
      const body = await readBody(req)
      if (typeof body !== 'object' || body === null || !('version' in body))
        throw new ApiError(400, 'INVALID_CONFIG', 'Thiếu phiên bản cấu hình hiện tại.')
      const version = (body as { version?: unknown }).version
      if (typeof version !== 'string' || !version)
        throw new ApiError(400, 'INVALID_CONFIG', 'Phiên bản cấu hình không hợp lệ.')
      const values = parseParameters((body as { parameters?: unknown }).parameters)
      const service = remoteConfig(),
        template = await service.getTemplate()
      if (template.etag !== version)
        throw new ApiError(409, 'CONFIG_CHANGED', 'Cấu hình đã được thay đổi ở nơi khác. Hãy tải lại trước khi lưu.')
      for (const key of Object.keys(configDefaults) as ConfigKey[]) {
        template.parameters[key] = {
          ...template.parameters[key],
          defaultValue: { value: values[key] },
          valueType: key === 'ci_analysis_enabled' ? 'BOOLEAN' : 'STRING',
        }
      }
      const published = await service.publishTemplate(template)
      json(res, 200, { values: configValues(published), version: published.etag })
      return
    }
    res.setHeader('Allow', 'GET, PUT, POST')
    throw new ApiError(404, 'ADMIN_RESOURCE_NOT_FOUND', 'Yêu cầu quản trị không hợp lệ.')
  } catch (error) {
    if (error instanceof ApiError) {
      json(res, error.status, { code: error.code, message: error.message })
      return
    }
    logAdminFailure(error, `admin-api:${req.method ?? 'unknown'}`)
    if (res.writableEnded || res.destroyed) return
    json(res, 503, {
      code: 'ADMIN_BACKEND_UNAVAILABLE',
      message: 'Firebase chưa thể hoàn tất thao tác admin. Kiểm tra quyền Admin SDK/Remote Config rồi thử lại.',
    })
  }
}
