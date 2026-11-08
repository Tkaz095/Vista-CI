import assert from 'node:assert/strict'
import { createHmac } from 'node:crypto'
import { createServer } from 'node:http'
import { after, beforeEach, test } from 'node:test'
import { deleteApp, getApps } from 'firebase-admin/app'
import { getFirestore } from 'firebase-admin/firestore'
import type { Message } from 'firebase-admin/messaging'
import type { Request, Response } from 'firebase-functions/v2/https'
import { deliverRunNotifications as deliver, notificationFor, parseRunEvent, verifyWebhook, wantsNotification, WebhookError, type CiRunEvent } from '../src/ciNotifications.js'
import type { Firestore } from 'firebase-admin/firestore'
import { handleGitHubWebhook } from '../src/index.js'

const emulator = process.env.FIRESTORE_EMULATOR_HOST
const project = process.env.GCLOUD_PROJECT
if (!emulator || !/^(127\.0\.0\.1|localhost):\d+$/.test(emulator) || project !== 'demo-vista-ci-notifications')
  throw new Error('Run with Firestore Emulator and project demo-vista-ci-notifications. Never use production for these tests.')

const db = getFirestore()
const secret = 'local-test-secret-with-at-least-32-characters'
const deliverRunNotifications = (event: CiRunEvent, database: Firestore, send: (message: Message) => Promise<string>) =>
  deliver(event, database, send, async () => true)
const uid = 'student'
const repo = { id: 123456, fullName: 'example/mobile' }
const runPayload = (action = 'completed', conclusion = 'failure', attempt = 1) => ({
  action,
  repository: { id: repo.id, full_name: repo.fullName },
  workflow_run: {
    id: 987654321, run_number: 17, run_attempt: attempt, name: 'Android APK',
    status: action, conclusion: action === 'completed' ? conclusion : null,
    repository: { id: repo.id, full_name: repo.fullName },
  },
})
const eventFor = (action = 'completed', conclusion = 'failure', attempt = 1) => {
  const event = parseRunEvent(runPayload(action, conclusion, attempt))
  assert.ok(event)
  return event
}

async function enroll(mode?: string) {
  await Promise.all([
    db.doc(`ciNotificationRepositories/${repo.id}`).set({
      enabled: true, fullName: repo.fullName, allowedUserUids: [uid],
    }),
    db.doc(`users/${uid}`).set({ role: 'user', isActive: true }),
    db.doc(`users/${uid}/projects/first`).set({ repositories: [repo] }),
    db.doc(`users/${uid}/devices/phone`).set({ fid: 'registered-test-fid', platform: 'android' }),
  ])
  if (mode !== undefined)
    await db.doc(`users/${uid}/ciSubscriptions/${repo.id}`).set({ repoId: `${repo.id}`, repoFullName: repo.fullName, mode })
}

beforeEach(async () => {
  const response = await fetch(`http://${emulator}/emulator/v1/projects/${project}/databases/(default)/documents`, { method: 'DELETE' })
  assert.equal(response.status, 200)
})
after(async () => { await Promise.all(getApps().map(deleteApp)) })

test('Signature matches GitHub official test vector and rejects changed bytes', () => {
  const signature = 'sha256=757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17'
  assert.equal(verifyWebhook(Buffer.from('Hello, World!'), signature, "It's a Secret to Everybody"), true)
  assert.equal(verifyWebhook(Buffer.from('Hello, World! '), signature, "It's a Secret to Everybody"), false)
  assert.equal(verifyWebhook(Buffer.from('Hello, World!'), undefined, secret), false)
  assert.equal(verifyWebhook(Buffer.from('Hello, World!'), 'sha256=short', secret), false)
})

test('Payload uses the base repository, actual run ID and attempt; requested is ignored', () => {
  assert.equal(parseRunEvent(runPayload('requested')), null)
  assert.deepEqual(eventFor(), {
    repoId: repo.id, fullName: repo.fullName, runId: 987654321, attempt: 1,
    number: 17, workflow: 'Android APK', phase: 'completed', conclusion: 'failure',
  })
  assert.equal(eventFor('in_progress').phase, 'started')
  const mismatch = runPayload()
  mismatch.workflow_run.repository.id = 99
  assert.throws(() => parseRunEvent(mismatch), WebhookError)
  assert.throws(() => parseRunEvent(runPayload('completed', 'failure', 0)), WebhookError)
})

test('Preference matrix includes timeout, cancellation, unknown mode and started events', () => {
  const started = eventFor('in_progress')
  const success = eventFor('completed', 'success')
  const failed = eventFor()
  const timedOut = eventFor('completed', 'timed_out')
  const cancelled = eventFor('completed', 'cancelled')
  for (const event of [started, success, failed, timedOut, cancelled]) {
    assert.equal(wantsNotification('off', event), false)
    assert.equal(wantsNotification('invalid', event), false)
    assert.equal(wantsNotification('all', event), true)
    assert.equal(wantsNotification('results', event), event !== started)
    assert.equal(wantsNotification('failures', event), event === failed || event === timedOut)
  }
})

test('HTTP validates raw UTF-8 bytes before processing; ping and ignored events acknowledge', async () => {
  const server = createServer(async (req, res) => {
    const chunks = []
    for await (const chunk of req) chunks.push(Buffer.from(chunk))
    const request = req as Request
    request.rawBody = Buffer.concat(chunks)
    request.get = ((name: string) => req.headers[name.toLowerCase()] as string) as Request['get']
    const response = res as unknown as Response
    response.status = (status: number) => { res.statusCode = status; return response }
    response.json = (value: unknown) => { res.setHeader('Content-Type', 'application/json'); res.end(JSON.stringify(value)); return response }
    await handleGitHubWebhook(request, response, secret)
  })
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve))
  const address = server.address()
  assert.ok(address && typeof address !== 'string')
  const endpoint = `http://127.0.0.1:${address.port}`
  try {
    const raw = JSON.stringify({ action: 'requested', title: 'Kiểm tra tiếng Việt' }, null, 2)
    const signature = `sha256=${createHmac('sha256', secret).update(raw).digest('hex')}`
    const headers = { 'Content-Type': 'application/json', 'X-GitHub-Event': 'workflow_run', 'X-Hub-Signature-256': signature }
    assert.equal((await fetch(endpoint)).status, 405)
    assert.equal((await fetch(endpoint, { method: 'POST', body: raw })).status, 401)
    assert.equal((await fetch(endpoint, { method: 'POST', headers, body: `${raw} ` })).status, 401)
    const ignored = await fetch(endpoint, { method: 'POST', headers, body: raw })
    assert.equal(ignored.status, 200)
    assert.deepEqual(await ignored.json(), { ignored: 'action_not_selected' })
    assert.equal((await fetch(endpoint, { method: 'POST', headers: { ...headers, 'X-GitHub-Event': 'ping' }, body: raw })).status, 200)
    const malformed = '{'
    const malformedSignature = `sha256=${createHmac('sha256', secret).update(malformed).digest('hex')}`
    assert.equal((await fetch(endpoint, { method: 'POST', headers: { ...headers, 'X-Hub-Signature-256': malformedSignature }, body: malformed })).status, 400)
  } finally { await new Promise<void>(resolve => server.close(() => resolve())) }
})

test('Missing enrollment cannot deliver even if the user saved the repository', async () => {
  await enroll('all')
  await db.doc(`ciNotificationRepositories/${repo.id}`).delete()
  const result = await deliverRunNotifications(eventFor(), db, async () => assert.fail('Must not send'))
  assert.equal(result.notificationsCreated, 0)
  assert.equal((await db.collection(`users/${uid}/notifications`).get()).empty, true)
})

test('Disabled repository, wrong name or a different workflow cannot deliver', async () => {
  await enroll('all')
  const config = db.doc(`ciNotificationRepositories/${repo.id}`)
  for (const update of [
    { enabled: false }, { enabled: true, fullName: 'other/repo' },
    { enabled: true, fullName: repo.fullName, workflowNames: ['Other workflow'] },
  ]) {
    await config.update(update)
    await deliverRunNotifications(eventFor(), db, async () => assert.fail('Must not send'))
  }
})

test('Only approved, active regular users still following the repository receive CI', async () => {
  await enroll('all')
  for (const profile of [{ role: 'admin', isActive: true }, { role: 'user', isActive: false }]) {
    await db.doc(`users/${uid}`).set(profile)
    await deliverRunNotifications(eventFor(), db, async () => assert.fail('Must not send'))
  }
  await db.doc(`users/${uid}`).set({ role: 'user', isActive: true })
  await db.doc(`users/${uid}/projects/first`).delete()
  await deliverRunNotifications(eventFor(), db, async () => assert.fail('Must not send'))
  await db.doc(`users/${uid}/projects/first`).set({ repositories: [repo] })
  await db.doc(`ciNotificationRepositories/${repo.id}`).update({ allowedUserUids: ['another-user'] })
  await deliverRunNotifications(eventFor(), db, async () => assert.fail('Must not send'))
})

test('Default failures mode persists inbox before FCM and preserves read state on redelivery', async () => {
  await enroll()
  const event = eventFor()
  const inbox = db.doc(`users/${uid}/notifications/${notificationFor(uid, event).notification_id}`)
  const sent: Message[] = []
  const send = async (message: Message) => {
    assert.equal((await inbox.get()).exists, true)
    sent.push(message)
    return 'message-1'
  }
  assert.equal((await deliverRunNotifications(event, db, send)).pushesSent, 1)
  await inbox.update({ read: true })
  assert.equal((await deliverRunNotifications(event, db, send)).pushesSent, 0)
  assert.equal(sent.length, 1)
  assert.equal((await inbox.get()).get('read'), true)
  assert.equal(sent[0].data?.uid, uid)
  assert.equal(sent[0].data?.run_id, '987654321')
  assert.equal(sent[0].data?.attempt, '1')
  assert.equal(sent[0].android?.notification?.channelId, 'vista_ci_runs')
  assert.equal(sent[0].android?.notification?.tag, `ci_${repo.id}_987654321_1`)
})

test('A disabled or deleted Firebase Auth account cannot receive CI despite an active profile', async () => {
  await enroll('all')
  await deliver(eventFor(), db, async () => assert.fail('Disabled user must not receive'), async () => false)
  assert.equal((await db.collection(`users/${uid}/notifications`).get()).empty, true)
})

test('Concurrent redeliveries create one inbox item and send once per device', async () => {
  await enroll('all')
  await db.doc(`users/${uid}/projects/second`).set({ repositories: [repo] })
  await db.doc(`ciNotificationRepositories/${repo.id}`).update({ allowedUserUids: [uid, uid] })
  await db.doc(`users/${uid}/devices/tablet`).set({ fid: 'tablet-fid' })
  const sent: Message[] = []
  const send = async (message: Message) => { sent.push(message); return 'message' }
  const results = await Promise.all(Array.from({ length: 3 }, () => deliverRunNotifications(eventFor(), db, send)))
  assert.equal(results.reduce((sum, item) => sum + item.notificationsCreated, 0), 1)
  assert.equal(sent.length, 2)
})

test('Off and results modes suppress started events; results mode delivers completion', async () => {
  await enroll('off')
  await deliverRunNotifications(eventFor(), db, async () => assert.fail('Off must not send'))
  await db.doc(`users/${uid}/ciSubscriptions/${repo.id}`).update({ mode: 'results' })
  await deliverRunNotifications(eventFor('in_progress'), db, async () => assert.fail('Results must not send start'))
  assert.equal((await deliverRunNotifications(eventFor('completed', 'success'), db, async () => 'message')).pushesSent, 1)
})

test('Duplicate device records with the same FID receive only one push', async () => {
  await enroll('all')
  await db.doc(`users/${uid}/devices/duplicate`).set({ fid: 'registered-test-fid' })
  let sent = 0
  const result = await deliverRunNotifications(eventFor(), db, async () => { sent++; return 'message' })
  assert.equal(result.pushesSent, 1)
  assert.equal(sent, 1)
})

test('All mode records both phases; a late start after completion is suppressed', async () => {
  await enroll('all')
  assert.equal((await deliverRunNotifications(eventFor('in_progress'), db, async () => 'started')).pushesSent, 1)
  assert.equal((await deliverRunNotifications(eventFor(), db, async () => 'completed')).pushesSent, 1)
  const docs = await db.collection(`users/${uid}/notifications`).get()
  assert.equal(docs.size, 2)
  const rerun = eventFor('completed', 'success', 2)
  assert.equal((await deliverRunNotifications(rerun, db, async () => 'attempt-2')).pushesSent, 1)
  const late = await deliverRunNotifications(eventFor('in_progress', 'failure', 2), db, async () => assert.fail('Late start'))
  assert.equal(late.notificationsCreated, 0)
})

test('Unregistered FID is removed; the inbox remains available', async () => {
  await enroll()
  const result = await deliverRunNotifications(eventFor(), db, async () => {
    throw Object.assign(new Error('NotRegistered'), { code: 'messaging/registration-token-not-registered' })
  })
  assert.equal(result.pushesFailed, 1)
  assert.equal((await db.doc(`users/${uid}/devices/phone`).get()).exists, false)
  assert.equal((await db.collection(`users/${uid}/notifications`).get()).size, 1)
})

test('A failed old FID cannot delete a fresh device registration', async () => {
  await enroll()
  await deliverRunNotifications(eventFor(), db, async () => {
    await db.doc(`users/${uid}/devices/phone`).update({ fid: 'fresh-fid' })
    throw Object.assign(new Error('NotRegistered'), { code: 'messaging/installation-id-not-registered' })
  })
  assert.equal((await db.doc(`users/${uid}/devices/phone`).get()).get('fid'), 'fresh-fid')
})

test('An uncertain send is not repeated on redelivery', async () => {
  await enroll()
  let calls = 0
  const send = async () => { calls++; throw Object.assign(new Error('timeout'), { code: 'app/network-error' }) }
  await deliverRunNotifications(eventFor(), db, send)
  await deliverRunNotifications(eventFor(), db, send)
  assert.equal(calls, 1)
  assert.equal((await db.collection('ciNotificationDeliveries').get()).docs[0].get('state'), 'uncertain')
})

test('Enrollment validation refuses malformed recipient lists instead of broadening access', async () => {
  await enroll()
  await db.doc(`ciNotificationRepositories/${repo.id}`).update({ allowedUserUids: ['invalid/path'] })
  await assert.rejects(deliverRunNotifications(eventFor(), db, async () => assert.fail('Must not send')), WebhookError)
})
