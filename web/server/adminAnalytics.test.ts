import assert from 'node:assert/strict'
import { test } from 'node:test'
import { createAnalyticsLoader, parseAnalyticsReports } from './adminAnalytics.js'

const now = new Date('2026-11-10T18:00:00Z')
const metricHeaders = [{ name: 'eventCount' }, { name: 'totalUsers' }]
const metadata = { timeZone: 'Asia/Ho_Chi_Minh' }
const report = (dimensions: string[], values: [string[], string[]][], rowCount = values.length) => ({
  dimensionHeaders: dimensions.map(name => ({ name })), metricHeaders, metadata, rowCount,
  rows: values.map(([d, m]) => ({ dimensionValues: d.map(value => ({ value })), metricValues: m.map(value => ({ value })) })),
})
const reports = () => [
  report([], [[[], ['5', '2']]]),
  report(['eventName'], [[['login'], ['3', '2']], [['project_create'], ['2', '2']]]),
  report(['date'], [[['20261111'], ['5', '2']]]),
]

test('uses independent user aggregate, property timezone and fills successful missing days', () => {
  const data = parseAnalyticsReports(reports(), '123', null, now)
  assert.equal(data.totalUsers, 2) // not 2 + 2 users from event rows
  assert.equal(data.eventCount, 5)
  assert.equal(data.endDate, '2026-11-11')
  assert.equal(data.startDate, '2026-11-05')
  assert.equal(data.days.length, 7)
  assert.equal(data.days[0].count, 0)
  assert.equal(data.days[6].count, 5)
})

test('rejects malformed/incomplete numbers and headers rather than manufacturing zeros', () => {
  const invalid = reports()
  invalid[0].rows[0].metricValues[0].value = 'NaN'
  assert.throws(() => parseAnalyticsReports(invalid, '123', null, now))
  assert.throws(() => parseAnalyticsReports([], '123', null, now))
  const partial = reports()
  partial[2].rowCount = 2
  assert.throws(() => parseAnalyticsReports(partial, '123', null, now))
})

test('exposes thresholding and truncated event table', () => {
  const partial = reports()
  partial[1].rowCount = 101
  const data = parseAnalyticsReports(partial, '123', null, now)
  assert.match(data.warnings[0], /100/)
})

function setup(options: { propertyId?: string; streamId?: string; status?: number; empty?: boolean } = {}) {
  let calls = 0
  let tokenCalls = 0
  let body: Record<string, unknown> = {}
  const loader = createAnalyticsLoader({
    token: async () => { tokenCalls++; return 'fake-test-token' },
    env: () => ({ propertyId: options.propertyId ?? '123', streamId: options.streamId }),
    now: () => now,
    fetch: async (input, init) => {
      calls++
      assert.equal(input, 'https://analyticsdata.googleapis.com/v1beta/properties/123:batchRunReports')
      assert.equal((init?.headers as Record<string, string>).Authorization, 'Bearer fake-test-token')
      body = JSON.parse(init?.body as string) as Record<string, unknown>
      return new Response(JSON.stringify(options.status ? { error: { message: 'upstream-secret-must-not-leak' } } : {
        reports: options.empty ? [report([], []), report(['eventName'], []), report(['date'], [])] : reports(),
      }), { status: options.status ?? 200, headers: { 'Content-Type': 'application/json' } })
    },
  })
  return { loader, calls: () => calls, tokenCalls: () => tokenCalls, body: () => body }
}

test('missing/invalid configuration performs no cloud call and reports setup requirement', async () => {
  for (const propertyId of ['', 'vista-ci', 'G-123', '../123']) {
    const s = setup({ propertyId })
    const result = await s.loader()
    assert.equal(result.status, 'unavailable')
    assert.equal(result.data, null)
    assert.match(result.message!, /GA4_PROPERTY_ID/)
    assert.equal(s.calls(), 0)
    assert.equal(s.tokenCalls(), 0)
  }
})

test('batches three reports, filters Android/stream, and coalesces concurrent refreshes', async () => {
  const s = setup({ streamId: '456' })
  const [first, second] = await Promise.all([s.loader(), s.loader()])
  assert.equal(first.status, 'ready')
  assert.deepEqual(first, second)
  assert.equal(s.calls(), 1)
  await s.loader()
  assert.equal(s.calls(), 1)
  const requests = s.body().requests as { dimensionFilter: { andGroup: { expressions: { filter: { fieldName: string; stringFilter: { value: string } } }[] } } }[]
  assert.equal(requests.length, 3)
  for (const r of requests) {
    assert.deepEqual(r.dimensionFilter.andGroup.expressions.map(e => [e.filter.fieldName, e.filter.stringFilter.value]), [['platform', 'Android'], ['streamId', '456']])
  }
})

test('permission/rate-limit failures are unavailable, sanitized and retryable', async () => {
  for (const status of [401, 403, 404, 429, 500]) {
    const s = setup({ status })
    const value = await s.loader()
    assert.equal(value.status, 'unavailable')
    assert.equal(value.data, null)
    assert.ok(!JSON.stringify(value).includes('upstream-secret'))
    await s.loader()
    assert.equal(s.calls(), 2)
  }
})

test('successful empty report is distinct from unconfigured source', async () => {
  const s = setup({ empty: true })
  const value = await s.loader()
  assert.equal(value.status, 'empty')
  assert.equal(value.data?.eventCount, 0)
  assert.equal(value.data?.totalUsers, 0)
  assert.equal(value.data?.events.length, 0)
})
