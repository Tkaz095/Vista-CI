import assert from 'node:assert/strict'
import { createCipheriv, randomBytes } from 'node:crypto'
import { createServer } from 'node:http'
import { once } from 'node:events'
import { after, before, test } from 'node:test'
import { readFile } from 'node:fs/promises'
import { route } from '../lib/router.js'

// Synthetic fixtures only. No Firebase credentials, GitHub tokens or live API writes.
const key = Buffer.alloc(32, 7)
process.env.VISTA_APP_ORIGIN = 'https://vista-ci.web.app'
process.env.GITHUB_CLIENT_ID = 'test-client-id'
process.env.GITHUB_CLIENT_SECRET = 'test-client-secret'
process.env.GITHUB_TOKEN_ENCRYPTION_KEY = key.toString('base64')
const server = createServer((req, res) => { void route(req, res) })
let base
before(async () => {
  server.listen(0, '127.0.0.1')
  await once(server, 'listening')
  base = `http://127.0.0.1:${server.address().port}`
})
after(() => new Promise((resolve, reject) => {
  server.closeAllConnections()
  server.close((error) => error ? reject(error) : resolve())
}))

test('compiled ESM handlers load without credentials; health is not cached', async () => {
  const response = await fetch(`${base}/api/health`)
  assert.equal(response.status, 200)
  assert.match(response.headers.get('cache-control'), /no-store/)
  assert.deepEqual(await response.json(), { status: 'ok', service: 'vista-api' })
})

test('each protected route rejects requests without Firebase ID token', async () => {
  for (const path of [
    '/api/github-session?action=info',
    '/api/github-data?kind=repos',
    '/api/github-job-log?repo=Tkaz095/Vista-CI&job=124877202889',
    '/api/github-session?action=mobile-result&ticket=test',
  ]) {
    const response = await fetch(`${base}${path}`)
    assert.equal(response.status, 401, path)
    assert.equal((await response.json()).code, 'FIREBASE_AUTH_REQUIRED')
  }
})

test('unknown API is JSON 404 rather than the SPA; unsupported method is rejected', async () => {
  const missing = await fetch(`${base}/api/not-found`)
  assert.equal(missing.status, 404)
  assert.equal((await missing.json()).code, 'API_NOT_FOUND')
  const post = await fetch(`${base}/api/github-data?kind=repos`, { method: 'POST' })
  assert.equal(post.status, 405)
})

test('invalid job input is rejected before any credential or GitHub access', async () => {
  const response = await fetch(`${base}/api/github-job-log?repo=../private&job=bad`)
  assert.equal(response.status, 400)
})

test('OAuth start rejects cross-origin browser requests', async () => {
  const response = await fetch(`${base}/api/github-session?action=start`, {
    method: 'POST', headers: { Origin: 'https://untrusted.example' },
  })
  assert.equal(response.status, 403)
  assert.equal((await response.json()).code, 'INVALID_ORIGIN')
})

function cookie(state) {
  const iv = randomBytes(12)
  const cipher = createCipheriv('aes-256-gcm', key, iv)
  cipher.setAAD(Buffer.from('vista-oauth-state'))
  const payload = Buffer.concat([cipher.update(JSON.stringify(state), 'utf8'), cipher.final()])
  return Buffer.concat([iv, cipher.getAuthTag(), payload]).toString('base64url')
}
const fixture = () => ({ uid: 'test-user', githubId: '123', nonce: 'test-nonce', createdAt: Date.now() })

test('OAuth callback accepts Hosting __session state and clears the secure cookie', async () => {
  const response = await fetch(`${base}/api/github-session?action=callback&state=test-nonce&error=access_denied`, {
    headers: { Cookie: `__session=${cookie(fixture())}` },
  })
  const body = await response.text()
  assert.match(body, /Bạn đã hủy cấp quyền GitHub/)
  assert.match(response.headers.get('set-cookie'), /^__session=;.*HttpOnly;.*Max-Age=0; Secure/)
  assert.match(response.headers.get('content-security-policy'), /frame-ancestors 'none'/)
  assert.match(body, /https:\/\/vista-ci.web.app/)
})

test('OAuth callback rejects mismatched or expired state before exchanging a token', async () => {
  for (const state of [
    { ...fixture(), nonce: 'different-nonce' },
    { ...fixture(), createdAt: Date.now() - 700000 },
  ]) {
    const response = await fetch(`${base}/api/github-session?action=callback&state=test-nonce&error=access_denied`, {
      headers: { Cookie: `__session=${cookie(state)}` },
    })
    assert.match(await response.text(), /không khớp hoặc đã hết hạn/)
    assert.equal(response.headers.get('set-cookie'), null)
  }
})

test('Hosting routes API before SPA and uses the deployed function region', async () => {
  const config = JSON.parse(await readFile(new URL('../../firebase.json', import.meta.url), 'utf8'))
  assert.equal(config.hosting.rewrites[0].source, '/api/**')
  assert.deepEqual(config.hosting.rewrites[0].function, {
    functionId: 'vistaApi', region: 'asia-southeast1',
  })
  assert.equal(config.hosting.rewrites[1].destination, '/index.html')
})

test('deployed function is bound to secrets and scales to zero with a low instance limit', async () => {
  const { vistaApi } = await import('../lib/index.js')
  const options = vistaApi.__endpoint
  assert.equal(options.minInstances, 0)
  assert.equal(options.maxInstances, 2)
  assert.equal(options.timeoutSeconds, 60)
  assert.deepEqual(options.secretEnvironmentVariables.map((item) => item.key).sort(),
    ['GITHUB_CLIENT_SECRET', 'GITHUB_TOKEN_ENCRYPTION_KEY'])
})
