import assert from 'node:assert/strict'
import { randomUUID } from 'node:crypto'
import { afterEach, mock, test } from 'node:test'
import type { User } from 'firebase/auth'
import { deliverNotifications, loadAllNotificationRecipients } from '../src/features/admin/adminService.js'
import type { NotificationDelivery } from '../src/features/admin/adminService.js'
import type { AdminNotificationResult } from '../shared/adminNotifications.js'

const user = { getIdToken: async () => 'test-admin-token' } as User
const response = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status })
function deliveries(count: number): NotificationDelivery[] {
  return Array.from({ length: count }, (_, i) => ({
    draft: { requestId: randomUUID(), uid: `student-${i}`, title: 'Bảo trì', body: 'Nội dung mẫu' },
    displayName: `Sinh viên ${i}`, state: 'pending',
  }))
}
function completed(item: NotificationDelivery): AdminNotificationResult {
  return {
    requestId: item.draft.requestId, notificationId: `admin_${item.draft.requestId}`, uid: item.draft.uid,
    state: 'completed', devices: 2, sent: 2, failed: 0, uncertain: 0,
  }
}
afterEach(() => mock.restoreAll())

test('broadcast preparation loads every page, including empty pages and duplicate IDs', async () => {
  const cursors: (string | null)[] = []
  mock.method(globalThis, 'fetch', async (input: string | URL | Request) => {
    const cursor = new URL(String(input), 'http://localhost').searchParams.get('cursor')
    cursors.push(cursor)
    if (cursor === null) return response({ recipients: [{ uid: 'a', displayName: 'A' }], nextCursor: 'page-2' })
    if (cursor === 'page-2') return response({ recipients: [], nextCursor: 'page-3' })
    return response({ recipients: [{ uid: 'a', displayName: 'A' }, { uid: 'b', displayName: 'B' }], nextCursor: null })
  })
  assert.deepEqual((await loadAllNotificationRecipients(user)).map(item => item.uid), ['a', 'b'])
  assert.deepEqual(cursors, [null, 'page-2', 'page-3'])
})

test('incomplete recipient loading rejects without returning a partial audience', async () => {
  let page = 0
  mock.method(globalThis, 'fetch', async () => ++page === 1
    ? response({ recipients: [{ uid: 'a', displayName: 'A' }], nextCursor: 'next' })
    : response({ message: 'Unavailable' }, 503))
  await assert.rejects(loadAllNotificationRecipients(user), { status: 503 })
})

test('sends all users in bounded groups and preserves their distinct request IDs', async () => {
  const plan = deliveries(8), sent: string[] = [], progress: NotificationDelivery[][] = []
  let active = 0, maxActive = 0
  mock.method(globalThis, 'fetch', async (_input: unknown, options: RequestInit) => {
    assert.equal(options.headers && (options.headers as Record<string, string>).Authorization, 'Bearer test-admin-token')
    const draft = JSON.parse(String(options.body))
    const item = plan.find(item => item.draft.uid === draft.uid)!
    assert.equal(draft.requestId, item.draft.requestId)
    active++
    maxActive = Math.max(maxActive, active)
    await new Promise(resolve => setTimeout(resolve, 5))
    sent.push(draft.uid)
    active--
    return response(completed(item))
  })
  const result = await deliverNotifications(user, plan, 'send', next => progress.push(next), () => true)
  assert.equal(sent.length, 8)
  assert.equal(new Set(sent).size, 8)
  assert.equal(maxActive, 3)
  assert.ok(result.every(item => item.state === 'completed'))
  assert.equal(result.reduce((total, item) => total + item.result!.sent, 0), 16)
  assert.ok(progress.length > 1)
  assert.ok(plan.every(item => item.state === 'pending'))
})

test('one inactive recipient does not stop the rest of the broadcast', async () => {
  const plan = deliveries(5)
  mock.method(globalThis, 'fetch', async (_input: unknown, options: RequestInit) => {
    const draft = JSON.parse(String(options.body))
    return draft.uid === 'student-1'
      ? response({ message: 'Tài khoản đã vô hiệu hóa.' }, 409)
      : response(completed(plan.find(item => item.draft.uid === draft.uid)!))
  })
  const result = await deliverNotifications(user, plan, 'send', () => {}, () => true)
  assert.equal(result.filter(item => item.state === 'completed').length, 4)
  assert.equal(result[1].state, 'failed')
  assert.equal(result[1].error, 'Tài khoản đã vô hiệu hóa.')
})

test('network uncertainty pauses remaining groups and status checks do not POST', async () => {
  const plan = deliveries(5), posts: string[] = []
  mock.method(globalThis, 'fetch', async (_input: unknown, options: RequestInit) => {
    const draft = JSON.parse(String(options.body))
    posts.push(draft.uid)
    if (draft.uid === 'student-0') throw new TypeError('Network interrupted')
    return response(completed(plan.find(item => item.draft.uid === draft.uid)!))
  })
  const paused = await deliverNotifications(user, plan, 'send', () => {}, () => true)
  assert.equal(posts.length, 3)
  assert.equal(paused[0].state, 'unknown')
  assert.equal(paused.filter(item => item.state === 'pending').length, 2)
  mock.restoreAll()
  mock.method(globalThis, 'fetch', async (input: string | URL | Request, options: RequestInit) => {
    assert.equal(options.method, 'GET')
    assert.equal(new URL(String(input), 'http://localhost').searchParams.get('id'), plan[0].draft.requestId)
    return response(completed(plan[0]))
  })
  const checked = await deliverNotifications(user, paused, 'check', () => {}, () => true)
  assert.equal(checked[0].state, 'completed')
  assert.equal(checked.filter(item => item.state === 'pending').length, 2)
})

test('404 status makes only that request retryable with the original ID', async () => {
  const plan = deliveries(2)
  plan[0].state = 'unknown'
  plan[1] = { ...plan[1], state: 'completed', result: completed(plan[1]) }
  mock.method(globalThis, 'fetch', async () => response({ message: 'Not found' }, 404))
  const checked = await deliverNotifications(user, plan, 'check', () => {}, () => true)
  assert.equal(checked[0].state, 'pending')
  mock.restoreAll()
  let count = 0
  mock.method(globalThis, 'fetch', async (_input: unknown, options: RequestInit) => {
    const draft = JSON.parse(String(options.body))
    assert.equal(draft.requestId, plan[0].draft.requestId)
    count++
    return response(completed(plan[0]))
  })
  await deliverNotifications(user, checked, 'send', () => {}, () => true)
  assert.equal(count, 1)
})

test('an in-progress server request remains unknown and is never resent', async () => {
  const plan = deliveries(4)
  mock.method(globalThis, 'fetch', async (_input: unknown, options: RequestInit) => {
    const draft = JSON.parse(String(options.body))
    return response({ ...completed(plan.find(item => item.draft.uid === draft.uid)!), state: 'sending' })
  })
  const paused = await deliverNotifications(user, plan, 'send', () => {}, () => true)
  assert.equal(paused.filter(item => item.state === 'unknown').length, 3)
  assert.equal(paused[3].state, 'pending')
})

test('losing admin access or leaving the panel prevents starting further groups', async () => {
  let calls = 0
  mock.method(globalThis, 'fetch', async () => { calls++; return response({ message: 'Đăng nhập lại.' }, 401) })
  const plan = deliveries(7)
  const paused = await deliverNotifications(user, plan, 'send', () => {}, () => true)
  assert.equal(calls, 3)
  assert.equal(paused.filter(item => item.state === 'pending').length, 4)
  await deliverNotifications(user, plan, 'send', () => {}, () => false)
  assert.equal(calls, 3)
})
