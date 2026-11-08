import { createHash, createHmac, timingSafeEqual } from 'node:crypto'
import { FieldValue, type Firestore } from 'firebase-admin/firestore'
import type { Message } from 'firebase-admin/messaging'

export class WebhookError extends Error {
  constructor(readonly status: number, readonly code: string, message: string) {
    super(message)
  }
}

export interface CiRunEvent {
  repoId: number
  fullName: string
  runId: number
  attempt: number
  number: number
  workflow: string
  phase: 'started' | 'completed'
  conclusion: string | null
}

// Sign the original bytes. Re-serializing JSON invalidates GitHub's signature.
export function verifyWebhook(body: Buffer, signature: string | undefined, secret: string) {
  if (!/^sha256=[a-f0-9]{64}$/.test(signature ?? '')) return false
  const expected = createHmac('sha256', secret).update(body).digest()
  return timingSafeEqual(expected, Buffer.from(signature!.slice(7), 'hex'))
}

function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value))
    throw new WebhookError(400, 'INVALID_EVENT', 'Thiếu dữ liệu workflow_run.')
  return value as Record<string, unknown>
}

function positive(value: unknown) {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value <= 0)
    throw new WebhookError(400, 'INVALID_EVENT', 'ID hoặc attempt không hợp lệ.')
  return value
}

export function parseRunEvent(payload: unknown): CiRunEvent | null {
  const data = object(payload)
  if (!['in_progress', 'completed'].includes(String(data.action))) return null
  const repo = object(data.repository)
  const run = object(data.workflow_run)
  const repoId = positive(repo.id)
  if (typeof repo.full_name !== 'string' || repo.full_name.length > 201 ||
      !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repo.full_name))
    throw new WebhookError(400, 'INVALID_EVENT', 'Tên repository không hợp lệ.')
  if (run.repository !== undefined) {
    const source = object(run.repository)
    if (source.id !== repoId || source.full_name !== repo.full_name)
      throw new WebhookError(400, 'INVALID_EVENT', 'Repository của run không khớp sự kiện.')
  }
  if (run.status !== data.action ||
      (data.action === 'completed' && typeof run.conclusion !== 'string'))
    throw new WebhookError(400, 'INVALID_EVENT', 'Trạng thái workflow không khớp sự kiện.')
  if (typeof run.name !== 'string' || !run.name.trim() || run.name.length > 200)
    throw new WebhookError(400, 'INVALID_EVENT', 'Tên workflow không hợp lệ.')
  return {
    repoId, fullName: repo.full_name, runId: positive(run.id),
    attempt: positive(run.run_attempt), number: positive(run.run_number),
    workflow: run.name.trim(), phase: data.action === 'in_progress' ? 'started' : 'completed',
    conclusion: data.action === 'completed' ? String(run.conclusion) : null,
  }
}

export function wantsNotification(mode: unknown, event: CiRunEvent) {
  switch (mode) {
    case 'all': return true
    case 'results': return event.phase === 'completed'
    case 'failures':
      return event.phase === 'completed' && ['failure', 'timed_out'].includes(event.conclusion ?? '')
    default: return false // Unknown or malformed settings never enable delivery.
  }
}

export function notificationFor(uid: string, event: CiRunEvent) {
  const id = `run_${event.repoId}_${event.runId}_${event.attempt}_${event.phase}`
  const result: Record<string, string> = {
    success: 'thành công', failure: 'thất bại', timed_out: 'quá thời gian',
    cancelled: 'đã bị hủy', skipped: 'đã bỏ qua',
  }
  const status = event.phase === 'started' ? 'đang chạy' : result[event.conclusion ?? ''] ?? 'đã kết thúc'
  return {
    notification_id: id, uid,
    title: Array.from(`${event.workflow} #${event.number} ${status}`).slice(0, 200).join(''),
    body: `${event.fullName} · attempt ${event.attempt}. Bấm để xem chi tiết CI.`,
    received_at: new Date().toISOString(), read: false,
    type: 'workflow_run', repo_id: `${event.repoId}`, repo_full_name: event.fullName,
    run_id: `${event.runId}`, attempt: `${event.attempt}`, phase: event.phase,
  }
}

function errorCode(error: unknown) {
  const code = typeof error === 'object' && error !== null && 'code' in error ? String(error.code) : 'unknown'
  return /^[a-zA-Z0-9_/-]{1,100}$/.test(code) ? code : 'unknown'
}

/** Only a trusted administrator enrolls repositories and recipients. Mobile's
 * editable project list is a preference, not proof of access to a private repo. */
export async function deliverRunNotifications(
  event: CiRunEvent,
  db: Firestore,
  send: (message: Message) => Promise<string>,
  isUserEnabled: (uid: string) => Promise<boolean>,
) {
  const totals = { notificationsCreated: 0, pushesSent: 0, pushesFailed: 0 }
  const enrollment = await db.doc(`ciNotificationRepositories/${event.repoId}`).get()
  if (!enrollment.exists || enrollment.get('enabled') !== true || enrollment.get('fullName') !== event.fullName)
    return { ...totals, ignored: 'repository_not_enrolled' }
  const recipients: unknown = enrollment.get('allowedUserUids')
  if (!Array.isArray(recipients) || recipients.length > 50 || recipients.some(
    uid => typeof uid !== 'string' || !uid || uid.length > 128 || uid.includes('/'),
  )) throw new WebhookError(503, 'INVALID_RECIPIENTS', 'Cấu hình tối đa 50 UID hợp lệ cho repo.')
  const workflows: unknown = enrollment.get('workflowNames')
  if (workflows !== undefined && (!Array.isArray(workflows) || workflows.some(name => typeof name !== 'string')))
    throw new WebhookError(503, 'INVALID_WORKFLOWS', 'workflowNames phải là danh sách tên workflow.')
  if (Array.isArray(workflows) && workflows.length && !workflows.includes(event.workflow))
    return { ...totals, ignored: 'workflow_not_selected' }

  for (const uid of new Set(recipients as string[])) {
    const user = db.collection('users').doc(uid)
    const [profile, setting, projects] = await Promise.all([
      user.get(), user.collection('ciSubscriptions').doc(`${event.repoId}`).get(),
      user.collection('projects').where('repositories', 'array-contains', {
        id: event.repoId, fullName: event.fullName,
      }).limit(1).get(),
    ])
    if (profile.get('isActive') !== true || profile.get('role') !== 'user' || projects.empty) continue
    const mode = setting.exists ? setting.get('mode') : 'failures'
    if (!wantsNotification(mode, event)) continue
    if (!await isUserEnabled(uid)) continue
    const notification = notificationFor(uid, event)
    const inbox = user.collection('notifications').doc(notification.notification_id)
    const completed = user.collection('notifications').doc(
      `run_${event.repoId}_${event.runId}_${event.attempt}_completed`,
    )
    const ready = await db.runTransaction(async transaction => {
      const existing = await transaction.get(inbox)
      if (event.phase === 'started' && (await transaction.get(completed)).exists) return false
      if (!existing.exists) transaction.create(inbox, notification)
      return { created: !existing.exists }
    })
    if (!ready) continue
    if (ready.created) totals.notificationsCreated++

    // A separate claim per device survives parallel deliveries and partial errors.
    // Keep claims after uncertain sends: retrying blindly can notify twice.
    const devices = await user.collection('devices').get()
    const seenFids = new Set<string>()
    for (const device of devices.docs) {
      const fid: unknown = device.get('fid')
      if (typeof fid !== 'string' || !fid || fid.length > 128 || seenFids.has(fid)) continue
      seenFids.add(fid)
      const key = createHash('sha256').update(`${uid}/${notification.notification_id}/${fid}`).digest('hex')
      const delivery = db.collection('ciNotificationDeliveries').doc(key)
      const claimed = await db.runTransaction(async transaction => {
        const old = await transaction.get(delivery)
        if (old.exists) return false
        if (event.phase === 'started' && (await transaction.get(completed)).exists) return false
        transaction.create(delivery, {
          uid, notificationId: notification.notification_id, installationId: device.id,
          state: 'sending', updatedAt: FieldValue.serverTimestamp(),
        })
        return true
      })
      if (!claimed) continue
      try {
        await send({
          fid,
          notification: { title: notification.title, body: notification.body },
          data: {
            notification_id: notification.notification_id, uid, type: 'workflow_run',
            repo_id: notification.repo_id, repo_full_name: notification.repo_full_name,
            run_id: notification.run_id, attempt: notification.attempt, phase: notification.phase,
          },
          android: {
            priority: 'high', ttl: 15 * 60 * 1000,
            notification: { channelId: 'vista_ci_runs', tag: `ci_${event.repoId}_${event.runId}_${event.attempt}` },
          },
        })
      } catch (error) {
        const code = errorCode(error)
        const invalid = [
          'messaging/registration-token-not-registered',
          'messaging/installation-id-not-registered',
          'messaging/invalid-registration-token',
        ].includes(code)
        totals.pushesFailed++
        // A fresh registration may have replaced this FID while the request ran.
        if (invalid) await db.runTransaction(async transaction => {
          if ((await transaction.get(device.ref)).get('fid') === fid) transaction.delete(device.ref)
        })
        await delivery.update({ state: invalid ? 'unregistered' : 'uncertain', errorCode: code, updatedAt: FieldValue.serverTimestamp() })
        console.error('[vista-ci-notifications]', { code, phase: event.phase })
        continue
      }
      totals.pushesSent++
      await delivery.update({ state: 'sent', updatedAt: FieldValue.serverTimestamp() })
    }
  }
  return totals
}
