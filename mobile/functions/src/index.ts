import { getApps, initializeApp } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'
import { getFirestore } from 'firebase-admin/firestore'
import { getMessaging } from 'firebase-admin/messaging'
import { defineSecret } from 'firebase-functions/params'
import { onRequest, type Request } from 'firebase-functions/v2/https'
import type { Response } from 'express'
import { deliverRunNotifications, parseRunEvent, verifyWebhook, WebhookError } from './ciNotifications.js'

const app = getApps()[0] ?? initializeApp()
const webhookSecret = defineSecret('GITHUB_WEBHOOK_SECRET')

async function isUserEnabled(uid: string) {
  try {
    return !(await getAuth(app).getUser(uid)).disabled
  } catch (error) {
    if (typeof error === 'object' && error !== null && 'code' in error && error.code === 'auth/user-not-found')
      return false
    throw error
  }
}

export async function handleGitHubWebhook(req: Request, res: Response, secret: string) {
  res.setHeader('Cache-Control', 'no-store')
  try {
    if (req.method !== 'POST') {
      res.setHeader('Allow', 'POST')
      throw new WebhookError(405, 'METHOD_NOT_ALLOWED', 'Webhook chỉ nhận POST.')
    }
    if (secret.length < 32)
      throw new WebhookError(503, 'WEBHOOK_NOT_CONFIGURED', 'Thiếu webhook secret hợp lệ.')
    // Firebase Functions preserves the original request bytes in rawBody.
    const body = req.rawBody
    if (!Buffer.isBuffer(body))
      throw new WebhookError(400, 'RAW_BODY_REQUIRED', 'Thiếu nội dung webhook gốc.')
    if (body.length > 1024 * 1024)
      throw new WebhookError(413, 'PAYLOAD_TOO_LARGE', 'Webhook vượt quá 1 MB.')
    if (!verifyWebhook(body, req.get('x-hub-signature-256'), secret))
      throw new WebhookError(401, 'INVALID_SIGNATURE', 'Chữ ký GitHub không hợp lệ.')
    const kind = req.get('x-github-event')
    if (kind === 'ping') { res.status(200).json({ received: true }); return }
    if (kind !== 'workflow_run') { res.status(200).json({ ignored: 'event_not_selected' }); return }
    let payload: unknown
    try { payload = JSON.parse(body.toString('utf8')) }
    catch { throw new WebhookError(400, 'INVALID_JSON', 'Webhook JSON không hợp lệ.') }
    const event = parseRunEvent(payload)
    if (!event) { res.status(200).json({ ignored: 'action_not_selected' }); return }
    const result = await deliverRunNotifications(event, getFirestore(app), message => getMessaging(app).send(message), isUserEnabled)
    res.status(200).json({ received: true, ...result })
  } catch (error) {
    if (error instanceof WebhookError) {
      res.status(error.status).json({ code: error.code, message: error.message })
    } else {
      // Never log payloads, FIDs, signatures, user data or credentials.
      console.error('[vista-ci-webhook]', { code: 'BACKEND_UNAVAILABLE' })
      res.status(503).json({ code: 'BACKEND_UNAVAILABLE' })
    }
  }
}

export const githubCiWebhook = onRequest({
  region: 'asia-southeast1',
  secrets: [webhookSecret],
  invoker: 'public', // GitHub authenticates through the HMAC, not Google IAM.
  cors: false,
  maxInstances: 2,
  concurrency: 5,
  timeoutSeconds: 120,
}, async (req, res) => {
  await handleGitHubWebhook(req, res, webhookSecret.value())
})
