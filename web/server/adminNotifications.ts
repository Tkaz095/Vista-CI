import { createHash } from 'node:crypto'
import type { Auth } from 'firebase-admin/auth'
import { FieldPath, FieldValue, type DocumentData, type DocumentReference, type Firestore } from 'firebase-admin/firestore'
import type { Message } from 'firebase-admin/messaging'
import type { AdminNotificationDraft, AdminNotificationResult, NotificationRecipientsPage } from '../shared/adminNotifications.js'
import { ApiError, logAdminFailure } from './githubAuth.js'

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/

function containsControl(value: string, multiline = false) {
  return Array.from(value).some(character => {
    const code = character.charCodeAt(0)
    if (multiline && [9, 10, 13].includes(code)) return false
    return code < 32 || (code >= 127 && code <= 159)
  })
}

function validUid(value: unknown): value is string {
  return typeof value === 'string' && value.length > 0 && value.length <= 128 && !value.includes('/') && !containsControl(value)
}

export function parseNotificationDraft(value: unknown): AdminNotificationDraft {
  if (!value || typeof value !== 'object' || Array.isArray(value))
    throw new ApiError(400, 'INVALID_NOTIFICATION', 'Thiếu nội dung thông báo.')
  const input = value as Record<string, unknown>
  if (Object.keys(input).some(key => !['requestId', 'uid', 'title', 'body'].includes(key)))
    throw new ApiError(400, 'INVALID_NOTIFICATION', 'Thông báo chứa trường không được hỗ trợ.')
  const requestId = typeof input.requestId === 'string' ? input.requestId.toLowerCase() : ''
  const title = typeof input.title === 'string' ? input.title.trim() : ''
  const body = typeof input.body === 'string' ? input.body.trim() : ''
  if (!uuid.test(requestId) || !validUid(input.uid))
    throw new ApiError(400, 'INVALID_NOTIFICATION', 'Người nhận hoặc mã yêu cầu không hợp lệ.')
  if (!title || title.length > 200 || containsControl(title) ||
      !body || body.length > 1000 || containsControl(body, true))
    throw new ApiError(400, 'INVALID_NOTIFICATION', 'Nhập tiêu đề tối đa 200 và nội dung tối đa 1.000 ký tự.')
  if (Buffer.byteLength(JSON.stringify({ title, body, uid: input.uid }), 'utf8') > 3500)
    throw new ApiError(400, 'NOTIFICATION_TOO_LARGE', 'Nội dung thông báo quá dài. Hãy rút gọn trước khi gửi.')
  return { requestId, uid: input.uid, title, body }
}

export async function listNotificationRecipients(db: Firestore, auth: Auth, cursor: string | null): Promise<NotificationRecipientsPage> {
  if (cursor !== null && !validUid(cursor))
    throw new ApiError(400, 'INVALID_CURSOR', 'Vị trí tải người nhận không hợp lệ.')
  // Scan by ID to avoid introducing a composite Firestore index.
  let query = db.collection('users').orderBy(FieldPath.documentId()).limit(51)
  if (cursor) query = query.startAfter(cursor)
  const page = await query.get()
  const scanned = page.docs.slice(0, 50)
  const eligible = scanned.filter(doc => doc.get('role') === 'user' && doc.get('isActive') === true)
  const records = eligible.length ? await auth.getUsers(eligible.map(doc => ({ uid: doc.id }))) : { users: [] }
  const enabled = new Map(records.users.filter(user => !user.disabled).map(user => [user.uid, user]))
  return {
    recipients: eligible.filter(doc => enabled.has(doc.id)).map(doc => ({
      uid: doc.id,
      displayName: typeof doc.get('displayName') === 'string' ? doc.get('displayName') : enabled.get(doc.id)?.displayName || doc.id,
    })),
    nextCursor: page.size > 50 ? scanned[scanned.length - 1].id : null,
  }
}

function requestRef(db: Firestore, id: string) {
  if (!uuid.test(id)) throw new ApiError(400, 'INVALID_REQUEST_ID', 'Mã yêu cầu không hợp lệ.')
  return db.collection('adminNotificationRequests').doc(id)
}

function resultFor(id: string, data: DocumentData): AdminNotificationResult {
  return {
    requestId: id, notificationId: data.notificationId, uid: data.uid,
    state: data.state, devices: data.devices, sent: data.sent,
    failed: data.failed, uncertain: data.uncertain,
  }
}

export async function readNotificationResult(db: Firestore, adminUid: string, id: string) {
  const snapshot = await requestRef(db, id).get()
  if (!snapshot.exists || snapshot.get('adminUid') !== adminUid)
    throw new ApiError(404, 'NOTIFICATION_REQUEST_NOT_FOUND', 'Chưa tìm thấy yêu cầu gửi này.')
  return resultFor(id, snapshot.data()!)
}

export async function sendAdminNotification(
  db: Firestore,
  auth: Auth,
  send: (message: Message) => Promise<string>,
  adminUid: string,
  input: AdminNotificationDraft,
): Promise<AdminNotificationResult> {
  const draft = parseNotificationDraft(input)
  const ref = requestRef(db, draft.requestId)
  const hash = createHash('sha256').update(JSON.stringify([draft.uid, draft.title, draft.body])).digest('hex')
  const existingResult = (data: DocumentData) => {
    if (data.adminUid !== adminUid || data.contentHash !== hash)
      throw new ApiError(409, 'NOTIFICATION_REQUEST_CHANGED', 'Mã yêu cầu đã được dùng cho nội dung khác. Hãy soạn thông báo mới.')
    return resultFor(draft.requestId, data)
  }
  const old = await ref.get()
  if (old.exists) return existingResult(old.data()!)

  try {
    if ((await auth.getUser(draft.uid)).disabled)
      throw new ApiError(409, 'RECIPIENT_DISABLED', 'Tài khoản nhận đã bị vô hiệu hóa.')
  } catch (error) {
    if (typeof error === 'object' && error !== null && 'code' in error && error.code === 'auth/user-not-found')
      throw new ApiError(404, 'RECIPIENT_NOT_FOUND', 'Tài khoản nhận không còn tồn tại.')
    throw error
  }
  const user = db.collection('users').doc(draft.uid)
  const devices = await user.collection('devices').limit(101).get()
  if (devices.size > 100)
    throw new ApiError(409, 'TOO_MANY_DEVICES', 'Tài khoản có quá nhiều đăng ký thiết bị. Hãy kiểm tra dữ liệu devices.')
  const targets = new Map<string, DocumentReference[]>()
  for (const device of devices.docs) {
    const fid = device.get('fid')
    if (typeof fid !== 'string' || !fid || fid.length > 128) continue
    targets.set(fid, [...targets.get(fid) ?? [], device.ref])
  }
  const notificationId = `admin_${draft.requestId}`
  const initial: AdminNotificationResult = {
    requestId: draft.requestId, notificationId, uid: draft.uid,
    state: 'sending', devices: targets.size, sent: 0, failed: 0, uncertain: 0,
  }
  const claim = await db.runTransaction(async transaction => {
    const existing = await transaction.get(ref)
    if (existing.exists) return { created: false, result: existingResult(existing.data()!) }
    const profile = await transaction.get(user)
    if (profile.get('role') !== 'user' || profile.get('isActive') !== true)
      throw new ApiError(409, 'RECIPIENT_INACTIVE', 'Người nhận phải là tài khoản app đang hoạt động.')
    const inbox = user.collection('notifications').doc(notificationId)
    if ((await transaction.get(inbox)).exists)
      throw new ApiError(409, 'NOTIFICATION_ALREADY_EXISTS', 'Thông báo đã có trong lịch sử. Hãy kiểm tra trước khi soạn mới.')
    transaction.create(ref, {
      ...initial, adminUid, contentHash: hash, createdAt: FieldValue.serverTimestamp(),
    })
    transaction.create(inbox, {
      notification_id: notificationId, uid: draft.uid, title: draft.title, body: draft.body,
      received_at: new Date().toISOString(), read: false,
    })
    return { created: true, result: initial }
  })
  // Exactly one request execution owns this send. Retries only read its result.
  if (!claim.created) return claim.result

  const result = { ...initial }
  const entries = [...targets.entries()]
  for (let start = 0; start < entries.length; start += 5) {
    await Promise.all(entries.slice(start, start + 5).map(async ([fid, refs]) => {
      try {
        await send({
          fid,
          notification: { title: draft.title, body: draft.body },
          data: { uid: draft.uid, notification_id: notificationId },
          android: { priority: 'high', ttl: 15 * 60 * 1000, notification: { channelId: 'vista_ci_runs', tag: notificationId } },
        })
        result.sent++
      } catch (error) {
        const code = logAdminFailure(error, 'send-admin-notification')
        if (['messaging/registration-token-not-registered', 'messaging/installation-id-not-registered', 'messaging/invalid-registration-token'].includes(code)) {
          result.failed++
          await db.runTransaction(async transaction => {
            const current = await transaction.getAll(...refs)
            for (const device of current) if (device.get('fid') === fid) transaction.delete(device.ref)
          })
        } else {
          // A timeout/SDK failure may happen after FCM accepted the message.
          result.uncertain++
        }
      }
    }))
    await ref.update({ sent: result.sent, failed: result.failed, uncertain: result.uncertain })
  }
  result.state = 'completed'
  await ref.update({ state: result.state, completedAt: FieldValue.serverTimestamp() })
  return result
}
