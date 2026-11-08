import assert from 'node:assert/strict'
import { randomUUID } from 'node:crypto'
import { createServer } from 'node:http'
import { after, before, beforeEach, mock, test } from 'node:test'
import { deleteApp, getApps } from 'firebase-admin/app'
import type { Message } from 'firebase-admin/messaging'
import adminApi from '../api/admin.js'
import { ApiError, database, firebaseAuth, messaging } from './githubAuth.js'
import { listNotificationRecipients, parseNotificationDraft, readNotificationResult, sendAdminNotification } from './adminNotifications.js'

// Refuse to run data-resetting tests against a real Firebase project.
assert.equal(process.env.FIREBASE_PROJECT_ID, 'demo-vista-admin')
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8099')
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:9099')
const db = database(), auth = firebaseAuth()
const server = createServer((req, res) => { void adminApi(req, res) })
let origin = ''
let pushes: Message[] = []
const draft = () => ({ requestId: randomUUID(), uid: 'student', title: 'Bảo trì', body: 'Hệ thống bảo trì lúc 20:00.' })

async function account(uid: string, role = 'user', active = true, disabled = false) {
  await auth.createUser({ uid, email: `${uid}@example.test`, password: 'emulator-password', disabled })
  await db.doc(`users/${uid}`).set({ displayName: uid, role, isActive: active })
}

async function token(uid: string) {
  const response = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: `${uid}@example.test`, password: 'emulator-password', returnSecureToken: true }),
  })
  assert.equal(response.status, 200)
  return (await response.json() as { idToken: string }).idToken
}

before(async () => {
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve))
  const address = server.address()
  assert.ok(address && typeof address !== 'string')
  origin = `http://127.0.0.1:${address.port}/api/admin`
})

beforeEach(async () => {
  mock.restoreAll()
  pushes = []
  const resets = await Promise.all([
    fetch('http://127.0.0.1:8099/emulator/v1/projects/demo-vista-admin/databases/(default)/documents', { method: 'DELETE' }),
    fetch('http://127.0.0.1:9099/emulator/v1/projects/demo-vista-admin/accounts', { method: 'DELETE' }),
  ])
  for (const response of resets) assert.equal(response.ok, true)
  await account('admin', 'admin')
  await account('student')
  mock.method(messaging(), 'send', async (message: Message) => {
    pushes.push(message)
    return 'projects/demo-vista-admin/messages/fake'
  })
})

after(async () => {
  mock.restoreAll()
  await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()))
  await Promise.all(getApps().map(deleteApp))
})

test('validates fields, control characters and UTF-8 payload size', () => {
  const input = draft()
  assert.equal(parseNotificationDraft({ ...input, title: '  Test  ' }).title, 'Test')
  assert.equal(parseNotificationDraft({ ...input, body: 'line 1\nline 2' }).body, 'line 1\nline 2')
  for (const invalid of [
    { ...input, uid: '../student' }, { ...input, requestId: 'bad-id' },
    { ...input, title: 'A\nB' }, { ...input, body: 'A\u0000B' },
    { ...input, body: 'x'.repeat(1001) }, { ...input, extra: true },
    { ...input, title: '漢'.repeat(200), body: '漢'.repeat(1000) },
  ]) assert.throws(() => parseNotificationDraft(invalid), ApiError)
})

test('HTTP endpoints reject anonymous, regular and inactive administrators', async () => {
  assert.equal((await fetch(`${origin}?resource=notification-recipients`)).status, 401)
  for (const resource of ['notification-recipients', 'notifications']) {
    const response = await fetch(`${origin}?resource=${resource}`, { headers: { Authorization: `Bearer ${await token('student')}` } })
    assert.equal(response.status, 403)
  }
  const adminToken = await token('admin')
  await db.doc('users/admin').update({ isActive: false })
  assert.equal((await fetch(`${origin}?resource=notification-recipients`, { headers: { Authorization: `Bearer ${adminToken}` } })).status, 403)
  assert.equal(pushes.length, 0)
})

test('recipient listing excludes disabled, inactive, admin and missing Auth accounts', async () => {
  await account('disabled', 'user', true, true)
  await account('inactive', 'user', false)
  await db.doc('users/orphan').set({ role: 'user', isActive: true })
  const page = await listNotificationRecipients(db, auth, null)
  assert.deepEqual(page.recipients.map(user => user.uid), ['student'])
  assert.equal(page.nextCursor, null)
})

test('recipient pagination scans without dropping eligible users', async () => {
  await Promise.all(Array.from({ length: 51 }, (_, i) => db.doc(`users/a${String(i).padStart(2, '0')}`).set({ role: 'admin', isActive: true })))
  const first = await listNotificationRecipients(db, auth, null)
  assert.ok(first.nextCursor)
  const second = await listNotificationRecipients(db, auth, first.nextCursor)
  assert.deepEqual([...first.recipients, ...second.recipients].map(user => user.uid), ['student'])
})

test('saves inbox before push and sends the protocol accepted by the mobile app', async () => {
  await db.doc('users/student/devices/device-a').set({ fid: 'test-fid' })
  const input = draft()
  const result = await sendAdminNotification(db, auth, async message => {
    const inbox = await db.doc(`users/student/notifications/admin_${input.requestId}`).get()
    assert.equal(inbox.get('title'), input.title)
    assert.equal(inbox.get('read'), false)
    assert.equal(inbox.get('type'), undefined)
    assert.deepEqual(message.data, { uid: 'student', notification_id: `admin_${input.requestId}` })
    assert.equal('fid' in message && message.fid, 'test-fid')
    assert.equal(message.android?.notification?.channelId, 'vista_ci_runs')
    assert.equal(message.android?.notification?.tag, resultId(input.requestId))
    return 'mock-message'
  }, 'admin', input)
  assert.equal(result.sent, 1)
  assert.equal(result.state, 'completed')
})

function resultId(requestId: string) { return `admin_${requestId}` }

test('accounts without devices still get an inbox notification', async () => {
  const result = await sendAdminNotification(db, auth, messaging().send.bind(messaging()), 'admin', draft())
  assert.equal(result.devices, 0)
  assert.equal(pushes.length, 0)
  assert.equal((await db.doc(`users/student/notifications/${result.notificationId}`).get()).exists, true)
})

test('concurrent same-ID requests send once and preserve an already-read inbox', async () => {
  await db.doc('users/student/devices/one').set({ fid: 'same-fid' })
  await db.doc('users/student/devices/two').set({ fid: 'same-fid' })
  const input = draft()
  await Promise.all([0, 1].map(() => sendAdminNotification(db, auth, messaging().send.bind(messaging()), 'admin', input)))
  assert.equal(pushes.length, 1)
  await db.doc(`users/student/notifications/${resultId(input.requestId)}`).update({ read: true })
  await sendAdminNotification(db, auth, messaging().send.bind(messaging()), 'admin', input)
  assert.equal(pushes.length, 1)
  assert.equal((await db.doc(`users/student/notifications/${resultId(input.requestId)}`).get()).get('read'), true)
  await assert.rejects(sendAdminNotification(db, auth, messaging().send.bind(messaging()), 'admin', { ...input, body: 'Changed' }), { status: 409 })
  await assert.rejects(readNotificationResult(db, 'other-admin', input.requestId), { status: 404 })
})

test('uncertain FCM errors are recorded and never automatically resent', async () => {
  await db.doc('users/student/devices/one').set({ fid: 'test-fid' })
  const input = draft()
  let calls = 0
  const send = async () => { calls++; throw { code: 'messaging/server-unavailable' } }
  const result = await sendAdminNotification(db, auth, send, 'admin', input)
  assert.equal(result.uncertain, 1)
  await sendAdminNotification(db, auth, send, 'admin', input)
  assert.equal(calls, 1)
  assert.equal((await db.doc('users/student/devices/one').get()).exists, true)
})

test('invalid FIDs are removed without deleting a replacement registration', async () => {
  await db.doc('users/student/devices/one').set({ fid: 'old-fid' })
  await db.doc('users/student/devices/two').set({ fid: 'old-fid' })
  const result = await sendAdminNotification(db, auth, async () => {
    await db.doc('users/student/devices/two').set({ fid: 'new-fid' })
    throw { code: 'messaging/registration-token-not-registered' }
  }, 'admin', draft())
  assert.equal(result.failed, 1)
  assert.equal((await db.doc('users/student/devices/one').get()).exists, false)
  assert.equal((await db.doc('users/student/devices/two').get()).get('fid'), 'new-fid')
})

test('validates recipient again at send time and writes nothing when inactive', async () => {
  await db.doc('users/student').update({ isActive: false })
  await assert.rejects(sendAdminNotification(db, auth, messaging().send.bind(messaging()), 'admin', draft()), { status: 409 })
  assert.equal((await db.collection('adminNotificationRequests').get()).empty, true)
  assert.equal((await db.collection('users/student/notifications').get()).empty, true)
  await db.doc('users/student').update({ isActive: true })
  await auth.updateUser('student', { disabled: true })
  await assert.rejects(sendAdminNotification(db, auth, messaging().send.bind(messaging()), 'admin', draft()), { status: 409 })
})

test('admin HTTP POST and status GET use real emulator authentication and mocked FCM', async () => {
  await db.doc('users/student/devices/one').set({ fid: 'test-fid' })
  const headers = { Authorization: `Bearer ${await token('admin')}`, 'Content-Type': 'application/json' }
  const input = draft()
  const response = await fetch(`${origin}?resource=notifications`, { method: 'POST', headers, body: JSON.stringify(input) })
  assert.equal(response.status, 200)
  const sent = await response.json()
  assert.equal(pushes.length, 1)
  const status = await fetch(`${origin}?resource=notifications&id=${input.requestId}`, { headers })
  assert.equal(status.status, 200)
  assert.deepEqual(await status.json(), sent)
  const list = await fetch(`${origin}?resource=notification-recipients`, { headers })
  assert.equal(list.status, 200)
  assert.deepEqual((await list.json()).recipients, [{ uid: 'student', displayName: 'student' }])
  const invalid = await fetch(`${origin}?resource=notifications`, { method: 'POST', headers, body: JSON.stringify({ ...input, requestId: 'bad' }) })
  assert.equal(invalid.status, 400)
  assert.equal(pushes.length, 1)
})
