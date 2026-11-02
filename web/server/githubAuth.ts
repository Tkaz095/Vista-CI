import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
  randomUUID,
  timingSafeEqual,
} from 'node:crypto'
import type { IncomingMessage, ServerResponse } from 'node:http'
import { applicationDefault, cert, getApps, initializeApp } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore'

export class ApiError extends Error {
  readonly status: number
  readonly code: string
  readonly retryAt?: number
  constructor(status: number, code: string, message: string, retryAt?: number) {
    super(message)
    this.status = status
    this.code = code
    this.retryAt = retryAt
  }
}
function required(name: string) {
  const value = process.env[name]?.trim()
  if (!value)
    throw new ApiError(
      503,
      'SERVER_SETUP_REQUIRED',
      `Backend chưa cấu hình ${name}. Xem hướng dẫn bước 21.`,
    )
  return value
}
export function config() {
  const origin = new URL(required('VISTA_APP_ORIGIN'))
  if (
    origin.origin !== origin.href.replace(/\/$/, '') ||
    (origin.protocol !== 'https:' && !['localhost', '127.0.0.1'].includes(origin.hostname))
  )
    throw new ApiError(
      503,
      'SERVER_SETUP_REQUIRED',
      'VISTA_APP_ORIGIN phải là origin HTTPS, hoặc localhost khi chạy local.',
    )
  const key = Buffer.from(required('GITHUB_TOKEN_ENCRYPTION_KEY'), 'base64')
  if (key.length !== 32)
    throw new ApiError(
      503,
      'SERVER_SETUP_REQUIRED',
      'GITHUB_TOKEN_ENCRYPTION_KEY phải là khóa base64 32 byte.',
    )
  return {
    origin: origin.origin,
    key,
    clientId: required('GITHUB_CLIENT_ID'),
    clientSecret: required('GITHUB_CLIENT_SECRET'),
    callback: `${origin.origin}/api/github-session?action=callback`,
  }
}
function admin() {
  const name = 'vista-backend'
  const projectId = required('FIREBASE_PROJECT_ID')
  let app = getApps().find((item) => item.name === name)
  if (!app) {
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL,
      privateKey = process.env.FIREBASE_PRIVATE_KEY
    if (!!clientEmail !== !!privateKey)
      throw new ApiError(
        503,
        'SERVER_SETUP_REQUIRED',
        'Cấu hình đầy đủ FIREBASE_CLIENT_EMAIL và FIREBASE_PRIVATE_KEY hoặc dùng Application Default Credentials.',
      )
    app = initializeApp(
      {
        projectId,
        credential:
          clientEmail && privateKey
            ? cert({ projectId, clientEmail, privateKey: privateKey.replace(/\\n/g, '\n') })
            : applicationDefault(),
      },
      name,
    )
  }
  return app
}
export const database = () => getFirestore(admin())
export async function authenticate(req: IncomingMessage) {
  const bearer = req.headers.authorization?.match(/^Bearer (\S+)$/)?.[1]
  if (!bearer)
    throw new ApiError(
      401,
      'FIREBASE_AUTH_REQUIRED',
      'Đăng nhập Vista trước khi đọc dữ liệu GitHub.',
    )
  let uid: string
  try {
    uid = (await getAuth(admin()).verifyIdToken(bearer, true)).uid
  } catch (error) {
    if (error instanceof ApiError) throw error
    const code =
      typeof error === 'object' && error !== null && 'code' in error ? String(error.code) : ''
    if (
      [
        'auth/id-token-expired',
        'auth/id-token-revoked',
        'auth/invalid-id-token',
        'auth/argument-error',
        'auth/user-disabled',
        'auth/user-not-found',
      ].includes(code)
    ) {
      throw new ApiError(
        401,
        'FIREBASE_AUTH_REQUIRED',
        'Phiên Firebase không còn hợp lệ. Đăng nhập Vista lại.',
      )
    }
    throw new ApiError(
      503,
      'FIREBASE_BACKEND_UNAVAILABLE',
      'Backend chưa xác minh được Firebase. Kiểm tra credential/quyền server hoặc mạng; không cần cấp lại GitHub token.',
    )
  }
  const [user, profile] = await Promise.all([
    getAuth(admin()).getUser(uid),
    database().doc(`users/${uid}`).get(),
  ])
  const githubId = user.providerData.find((item) => item.providerId === 'github.com')?.uid
  if (!githubId)
    throw new ApiError(409, 'GITHUB_LINK_REQUIRED', 'Liên kết GitHub với tài khoản Vista trước.')
  if (user.disabled || profile.data()?.isActive !== true || profile.data()?.role !== 'user')
    throw new ApiError(403, 'VISTA_ACCESS_DENIED', 'Hồ sơ Vista chưa có quyền sử dụng.')
  return { uid, githubId }
}
export function sameOrigin(req: IncomingMessage, native = false) {
  if (native && !req.headers.origin && req.headers['x-vista-client'] === 'flutter') return
  if (req.headers.origin !== config().origin)
    throw new ApiError(403, 'INVALID_ORIGIN', 'Nguồn yêu cầu không hợp lệ.')
}
export function protect(res: ServerResponse) {
  res.setHeader('Cache-Control', 'no-store, private')
  res.setHeader('X-Content-Type-Options', 'nosniff')
  res.setHeader('Referrer-Policy', 'no-referrer')
}
export function json(res: ServerResponse, status: number, data: unknown) {
  protect(res)
  res.statusCode = status
  res.setHeader('Content-Type', 'application/json; charset=utf-8')
  res.end(JSON.stringify(data))
}
export function failure(res: ServerResponse, error: unknown) {
  if (res.destroyed || res.writableEnded) return
  if (error instanceof ApiError)
    json(res, error.status, { code: error.code, message: error.message, retryAt: error.retryAt })
  else
    json(res, 503, {
      code: 'BACKEND_UNAVAILABLE',
      message:
        'Backend GitHub tạm thời không sẵn sàng. Kiểm tra cấu hình/quyền server hoặc thử lại; không cần cấp lại token vì lỗi mạng.',
    })
}
function seal(value: unknown, aad: string) {
  const iv = randomBytes(12),
    cipher = createCipheriv('aes-256-gcm', config().key, iv)
  cipher.setAAD(Buffer.from(aad))
  const ciphertext = Buffer.concat([cipher.update(JSON.stringify(value), 'utf8'), cipher.final()])
  return Buffer.concat([iv, cipher.getAuthTag(), ciphertext]).toString('base64url')
}
function unseal<T>(value: string, aad: string): T {
  const bytes = Buffer.from(value, 'base64url')
  if (bytes.length < 29) throw new Error('Invalid envelope')
  const decipher = createDecipheriv('aes-256-gcm', config().key, bytes.subarray(0, 12))
  decipher.setAAD(Buffer.from(aad))
  decipher.setAuthTag(bytes.subarray(12, 28))
  return JSON.parse(
    Buffer.concat([decipher.update(bytes.subarray(28)), decipher.final()]).toString('utf8'),
  ) as T
}
interface TokenPair {
  accessToken: string
  refreshToken: string
  expiresAt: number
  refreshExpiresAt: number
}
interface Connection {
  githubId: string
  login: string
  encryptedTokens: string
  connectionId: string
  state: 'connected' | 'reconnect' | 'disconnected' | 'disconnecting'
  leaseId?: string | null
  leaseUntil?: number
  updatedAt: number
  lastRefreshedAt?: number
  refreshCount?: number
}
const ref = (uid: string) => database().collection('githubConnections').doc(uid)
const binding = (uid: string, githubId: string) => `vista-github:${uid}:${githubId}`
async function exchange(parameters: Record<string, string>): Promise<TokenPair> {
  const cfg = config()
  let response: Response
  try {
    response = await fetch('https://github.com/login/oauth/access_token', {
      method: 'POST',
      headers: { Accept: 'application/json', 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: cfg.clientId,
        client_secret: cfg.clientSecret,
        ...parameters,
      }),
      signal: AbortSignal.timeout(15000),
      redirect: 'error',
    })
  } catch {
    throw new ApiError(
      503,
      'GITHUB_UNAVAILABLE',
      'Chưa liên lạc được GitHub để đổi token. Thử lại sau.',
    )
  }
  let value: Record<string, unknown>
  try {
    value = (await response.json()) as Record<string, unknown>
    if (!value || typeof value !== 'object') throw new Error('Invalid token response')
  } catch {
    throw new ApiError(
      503,
      'GITHUB_UNAVAILABLE',
      'GitHub chưa trả kết quả đổi token hợp lệ. Token đã lưu được giữ lại; thử lại sau.',
    )
  }
  if (value.error) {
    if (
      ['bad_refresh_token', 'expired_refresh_token', 'invalid_grant'].includes(String(value.error))
    )
      throw new ApiError(
        409,
        'RECONNECT_REQUIRED',
        'Refresh token đã hết hạn hoặc bị thu hồi. Kết nối GitHub lại.',
      )
    if (String(value.error) === 'incorrect_client_credentials')
      throw new ApiError(
        503,
        'SERVER_SETUP_REQUIRED',
        'GitHub từ chối Client ID/Secret của backend. Kiểm tra cấu hình OAuth App; không cần logout Vista.',
      )
    throw new ApiError(
      409,
      'OAUTH_EXCHANGE_FAILED',
      'Không đổi được token GitHub. Kiểm tra OAuth callback/Client ID/Secret và thử kết nối lại.',
    )
  }
  if (!response.ok)
    throw new ApiError(
      503,
      'GITHUB_UNAVAILABLE',
      'GitHub tạm thời chưa đổi được token. Token đã lưu được giữ lại; thử lại sau.',
    )
  if (
    typeof value.access_token !== 'string' ||
    typeof value.refresh_token !== 'string' ||
    typeof value.expires_in !== 'number' ||
    typeof value.refresh_token_expires_in !== 'number' ||
    value.expires_in <= 0 ||
    value.refresh_token_expires_in <= 0
  )
    throw new ApiError(
      503,
      'REFRESH_NOT_SUPPORTED',
      'GitHub chưa trả cặp token có hạn. Bật Expire user access tokens cho OAuth App và kết nối lại.',
    )
  const now = Date.now()
  return {
    accessToken: value.access_token,
    refreshToken: value.refresh_token,
    expiresAt: now + value.expires_in * 1000,
    refreshExpiresAt: now + value.refresh_token_expires_in * 1000,
  }
}
async function githubIdentity(accessToken: string) {
  const response = await fetch('https://api.github.com/user', {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2026-03-10',
      'User-Agent': 'Vista-CI',
    },
    signal: AbortSignal.timeout(15000),
    redirect: 'error',
  })
  if (!response.ok)
    throw new ApiError(503, 'GITHUB_UNAVAILABLE', 'Chưa xác minh được tài khoản GitHub. Thử lại.')
  const user = (await response.json()) as { id?: number; login?: string }
  if (!Number.isSafeInteger(user.id) || typeof user.login !== 'string')
    throw new ApiError(502, 'INVALID_GITHUB_RESPONSE', 'GitHub trả hồ sơ không hợp lệ.')
  return { id: String(user.id), login: user.login }
}
interface OAuthState {
  baseConnectionId?: string | null
  mobileRequestId?: string
  uid: string
  githubId: string
  nonce: string
  verifier: string
  createdAt: number
}
const cookieName = 'vista_github_oauth'
function stateCookie(value: string, maxAge: number) {
  return `${cookieName}=${value}; Path=/api/github-session; HttpOnly; SameSite=Lax; Max-Age=${maxAge}${config().origin.startsWith('https:') ? '; Secure' : ''}`
}
async function newState(identity: { uid: string; githubId: string }): Promise<OAuthState> {
  const existing = (await ref(identity.uid).get()).data()
  if (existing?.state === 'disconnecting' && existing.leaseUntil > Date.now())
    throw new ApiError(409, 'CONNECTION_BUSY', 'Đang ngắt kết nối. Chờ hoàn tất rồi kết nối lại.')
  return {
    ...identity,
    nonce: randomBytes(32).toString('base64url'),
    verifier: randomBytes(32).toString('base64url'),
    createdAt: Date.now(),
    baseConnectionId: existing?.connectionId ?? null,
  }
}
function authorizeUrl(state: OAuthState) {
  const cfg = config()
  const query = new URLSearchParams({
    client_id: cfg.clientId,
    redirect_uri: cfg.callback,
    state: state.nonce,
    scope: 'read:user offline_access',
    code_challenge: createHash('sha256').update(state.verifier).digest('base64url'),
    code_challenge_method: 'S256',
  })
  return `https://github.com/login/oauth/authorize?${query}`
}
export async function startOAuth(req: IncomingMessage, res: ServerResponse) {
  sameOrigin(req)
  const state = await newState(await authenticate(req))
  res.setHeader('Set-Cookie', stateCookie(seal(state, 'vista-oauth-state'), 600))
  json(res, 200, { authorizeUrl: authorizeUrl(state) })
}
export async function finishOAuth(req: IncomingMessage, res: ServerResponse, url: URL) {
  protect(res)
  let result: { ok: boolean; message?: string } = {
    ok: false,
    message: 'Không hoàn tất kết nối GitHub. Thử lại.',
  }
  let mobileRequestId: string | undefined
  try {
    const raw = req.headers.cookie
      ?.split(';')
      .map((item) => item.trim())
      .find((item) => item.startsWith(`${cookieName}=`))
      ?.slice(cookieName.length + 1)
    if (!raw)
      throw new ApiError(
        400,
        'INVALID_STATE',
        'Phiên kết nối GitHub không còn hợp lệ. Thử lại trong cùng trình duyệt.',
      )
    const state = unseal<OAuthState>(raw, 'vista-oauth-state'),
      returned = url.searchParams.get('state') ?? ''
    if (
      typeof state.nonce !== 'string' ||
      returned.length !== state.nonce.length ||
      !timingSafeEqual(Buffer.from(returned), Buffer.from(state.nonce)) ||
      Date.now() - state.createdAt > 600000 ||
      state.createdAt > Date.now()
    )
      throw new ApiError(400, 'INVALID_STATE', 'Phiên kết nối GitHub không khớp hoặc đã hết hạn.')
    mobileRequestId = state.mobileRequestId
    res.setHeader('Set-Cookie', stateCookie('', 0))
    if (url.searchParams.has('error'))
      throw new ApiError(400, 'OAUTH_CANCELLED', 'Bạn đã hủy cấp quyền GitHub.')
    const code = url.searchParams.get('code')
    if (!code || code.length > 512)
      throw new ApiError(400, 'INVALID_CODE', 'GitHub không trả mã kết nối hợp lệ.')
    const pair = await exchange({
      code,
      redirect_uri: config().callback,
      code_verifier: state.verifier,
    })
    const identity = await githubIdentity(pair.accessToken)
    const user = await getAuth(admin()).getUser(state.uid)
    const profile = await database().doc(`users/${state.uid}`).get()
    if (
      user.disabled ||
      profile.data()?.isActive !== true ||
      profile.data()?.role !== 'user' ||
      user.providerData.find((item) => item.providerId === 'github.com')?.uid !== identity.id ||
      identity.id !== state.githubId
    )
      throw new ApiError(
        403,
        'GITHUB_ACCOUNT_MISMATCH',
        'Chọn đúng tài khoản GitHub đã dùng đăng nhập Vista. Kết nối không được lưu.',
      )
    await database().runTransaction(async (tx) => {
      const current = (await tx.get(ref(state.uid))).data()
      if ((current?.connectionId ?? null) !== (state.baseConnectionId ?? null))
        throw new ApiError(
          409,
          'CONNECTION_CHANGED',
          'Kết nối đã thay đổi. Hãy bắt đầu kết nối GitHub lại.',
        )
      tx.set(ref(state.uid), {
        githubId: identity.id,
        login: identity.login,
        encryptedTokens: seal(pair, binding(state.uid, identity.id)),
        connectionId: randomUUID(),
        state: 'connected',
        leaseId: null,
        leaseUntil: 0,
        updatedAt: Date.now(),
        refreshCount: 0,
      } satisfies Connection)
    })
    result = { ok: true }
  } catch (error) {
    result = {
      ok: false,
      message:
        error instanceof ApiError
          ? error.message
          : 'Chưa lưu được kết nối GitHub. Kiểm tra cấu hình backend rồi thử lại.',
    }
  }
  if (mobileRequestId) {
    try {
      await database()
        .collection('githubOAuthRequests')
        .doc(mobileRequestId)
        .update({
          status: result.ok ? 'success' : 'error',
          message: result.message ?? '',
          encryptedState: FieldValue.delete(),
        })
    } catch {
      /* The vault remains the source of truth; no credential is sent to the browser. */
    }
  }
  const nonce = randomBytes(16).toString('base64'),
    payload = JSON.stringify({ type: 'vista-github-connected', ...result }).replace(/</g, '\\u003c')
  res.setHeader('Content-Type', 'text/html; charset=utf-8')
  res.setHeader(
    'Content-Security-Policy',
    `default-src 'none'; script-src 'nonce-${nonce}'; base-uri 'none'; frame-ancestors 'none'`,
  )
  res.end(
    `<!doctype html><html lang="vi"><meta charset="utf-8"><title>Kết nối GitHub · Vista</title><body><p>${result.ok ? 'Đã kết nối GitHub. Bạn có thể đóng cửa sổ này và quay lại Vista.' : 'Chưa kết nối được GitHub. Quay lại Vista để xem thông báo.'}</p><script nonce="${nonce}">if(window.opener){window.opener.postMessage(${payload},${JSON.stringify(config().origin)})}</script></body></html>`,
  )
}

const refreshing = new Map<string, Promise<TokenPair>>()
async function refreshConnection(
  uid: string,
  githubId: string,
  rejected?: string,
): Promise<TokenPair> {
  for (let wait = 0; wait < 80; wait++) {
    const leaseId = randomUUID()
    const claim = await database().runTransaction(async (tx) => {
      const snapshot = await tx.get(ref(uid)),
        data = snapshot.data() as Connection | undefined
      if (!data || data.githubId !== githubId || data.state !== 'connected')
        throw new ApiError(
          409,
          'RECONNECT_REQUIRED',
          'Kết nối GitHub một lần để bật tự làm mới token.',
        )
      const pair = unseal<TokenPair>(data.encryptedTokens, binding(uid, githubId))
      if (pair.refreshExpiresAt <= Date.now())
        throw new ApiError(409, 'RECONNECT_REQUIRED', 'Refresh token hết hạn. Kết nối GitHub lại.')
      if (pair.expiresAt > Date.now() + 60000 && (!rejected || pair.accessToken !== rejected))
        return { ready: pair, connectionId: data.connectionId }
      if ((data.leaseUntil ?? 0) > Date.now())
        return { waiting: true, connectionId: data.connectionId }
      tx.update(ref(uid), { leaseId, leaseUntil: Date.now() + 45000 })
      return { pair, connectionId: data.connectionId }
    })
    if (claim.ready) return claim.ready
    if (claim.waiting) {
      await new Promise((resolve) => setTimeout(resolve, 250))
      continue
    }
    try {
      const pair = await exchange({
        grant_type: 'refresh_token',
        refresh_token: claim.pair!.refreshToken,
      })
      const saved = await database().runTransaction(async (tx) => {
        const data = (await tx.get(ref(uid))).data() as Connection | undefined
        if (data?.connectionId !== claim.connectionId || data.leaseId !== leaseId) return false
        tx.update(ref(uid), {
          encryptedTokens: seal(pair, binding(uid, githubId)),
          leaseId: null,
          leaseUntil: 0,
          updatedAt: Date.now(),
          lastRefreshedAt: Date.now(),
          refreshCount: FieldValue.increment(1),
        })
        return true
      })
      if (saved) return pair
    } catch (error) {
      await database().runTransaction(async (tx) => {
        const data = (await tx.get(ref(uid))).data() as Connection | undefined
        if (data?.connectionId !== claim.connectionId || data.leaseId !== leaseId) return
        tx.update(ref(uid), {
          leaseId: null,
          leaseUntil: 0,
          ...(error instanceof ApiError && error.code === 'RECONNECT_REQUIRED'
            ? { state: 'reconnect', encryptedTokens: '' }
            : {}),
        })
      })
      throw error
    }
  }
  throw new ApiError(503, 'REFRESH_BUSY', 'Kết nối GitHub đang được làm mới. Chờ rồi thử tải lại.')
}
export async function accessToken(uid: string, githubId: string, rejected?: string) {
  const key = `${uid}:${githubId}`
  while (true) {
    const existing = refreshing.get(key)
    if (existing) {
      const pair = await existing
      // A normal concurrent read may have returned the very token GitHub rejected.
      // Join its result only if it actually supplies a different token.
      if (!rejected || pair.accessToken !== rejected) return pair
      if (refreshing.get(key) === existing) refreshing.delete(key)
      continue
    }
    const pending = refreshConnection(uid, githubId, rejected)
    refreshing.set(key, pending)
    try {
      return await pending
    } finally {
      if (refreshing.get(key) === pending) refreshing.delete(key)
    }
  }
}
export async function status(req: IncomingMessage, res: ServerResponse) {
  const identity = await authenticate(req),
    pair = await accessToken(identity.uid, identity.githubId)
  json(res, 200, {
    connected: true,
    expiresAt: pair.expiresAt,
    refreshExpiresAt: pair.refreshExpiresAt,
    automaticRefresh: true,
  })
}
// Short-lived, bounded JSON cache for conditional polling. Auth and repo ownership
// are still checked on every API request; no GitHub token or raw log is cached here.
const readCache = new Map<
  string,
  {
    etag: string
    body: string
    headers: [string, string][]
    until: number
  }
>()
const githubCooldown = new Map<string, number>()
async function githubFailureDetails(response: Response) {
  let message = ''
  try {
    const value = (await response.clone().json()) as { message?: unknown }
    if (typeof value.message === 'string') message = value.message
  } catch {
    /* Classify with status/headers when no JSON body is available. */
  }
  const limited =
    response.status === 429 ||
    response.headers.get('x-ratelimit-remaining') === '0' ||
    response.headers.has('retry-after') ||
    /rate limit|abuse detection/i.test(message)
  return {
    limited,
    expired: !limited && /(?:token[^.]*expir|expir[^.]*token|bad credentials)/i.test(message),
    needsRepoAdmin: /must have admin rights/i.test(message),
  }
}
export async function githubRead(
  identity: { uid: string; githubId: string },
  path: string,
  signal?: AbortSignal,
) {
  const identityKey = `${identity.uid}:${identity.githubId}`
  const waitUntil = githubCooldown.get(identityKey) ?? 0
  if (waitUntil > Date.now())
    throw new ApiError(
      429,
      'GITHUB_RATE_LIMITED',
      'GitHub đang giới hạn lượt gọi. Vista sẽ đợi trước khi thử lại.',
      waitUntil,
    )
  githubCooldown.delete(identityKey)
  const cacheKey = `${identityKey}:${path}`
  const cached = readCache.get(cacheKey)
  const entry = cached && cached.until > Date.now() ? cached : undefined
  if (cached && !entry) readCache.delete(cacheKey)
  let pair = await accessToken(identity.uid, identity.githubId)
  const send = () =>
    fetch(`https://api.github.com${path}`, {
      headers: {
        Authorization: `Bearer ${pair.accessToken}`,
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2026-03-10',
        'User-Agent': 'Vista-CI',
        ...(entry ? { 'If-None-Match': entry.etag } : {}),
      },
      signal: signal
        ? AbortSignal.any([signal, AbortSignal.timeout(15000)])
        : AbortSignal.timeout(15000),
      redirect: 'manual',
    })
  let response = await send()
  const details = [401, 403, 429].includes(response.status)
    ? await githubFailureDetails(response)
    : null
  if (!details?.limited && (response.status === 401 || details?.expired)) {
    pair = await accessToken(identity.uid, identity.githubId, pair.accessToken)
    response = await send()
  }
  const rejected = [401, 403, 429].includes(response.status)
    ? await githubFailureDetails(response)
    : null
  if (response.status === 401 && !rejected?.limited) {
    await database().runTransaction(async (tx) => {
      const data = (await tx.get(ref(identity.uid))).data() as Connection | undefined
      if (data?.githubId !== identity.githubId || data.state !== 'connected') return
      const current = unseal<TokenPair>(
        data.encryptedTokens,
        binding(identity.uid, identity.githubId),
      )
      if (current.accessToken === pair.accessToken)
        tx.update(ref(identity.uid), {
          state: 'reconnect',
          encryptedTokens: '',
          leaseId: null,
          leaseUntil: 0,
        })
    })
    throw new ApiError(
      409,
      'RECONNECT_REQUIRED',
      'GitHub vẫn từ chối token sau khi làm mới. Kết nối GitHub lại.',
    )
  }
  if (rejected?.limited) {
    const now = Date.now()
    const retry = Number(response.headers.get('retry-after') ?? 0) * 1000
    const reset =
      response.headers.get('x-ratelimit-remaining') === '0'
        ? Number(response.headers.get('x-ratelimit-reset') ?? 0) * 1000
        : 0
    const retryAt = Math.max(
      now + 60000,
      now + (Number.isFinite(retry) ? retry : 0),
      Number.isFinite(reset) ? reset : 0,
    )
    githubCooldown.set(identityKey, retryAt)
    if (githubCooldown.size > 500) githubCooldown.delete(githubCooldown.keys().next().value!)
    throw new ApiError(
      429,
      'GITHUB_RATE_LIMITED',
      'GitHub đang giới hạn lượt gọi. Vista sẽ chờ đến thời điểm được phép rồi thử lại; không cần đăng nhập lại.',
      retryAt,
    )
  }
  if (response.status === 403 && rejected?.expired)
    throw new ApiError(
      503,
      'GITHUB_AUTH_REJECTED',
      'GitHub vẫn báo token hết hiệu lực sau một lần tự gia hạn. Token đã lưu được giữ lại; kiểm tra kết nối và cấu hình OAuth App.',
    )
  if (response.status === 403) {
    const isLog = /\/actions\/jobs\/\d+\/logs$/.test(path)
    throw new ApiError(
      403,
      'GITHUB_PERMISSION_DENIED',
      isLog
        ? `GitHub từ chối tải log job (HTTP 403). ${rejected?.needsRepoAdmin ? 'Endpoint yêu cầu quyền quản lý repository mà token hiện tại chưa đáp ứng.' : 'Token hiện tại chưa có quyền tải log.'} Lỗi này không chặn việc đọc lịch sử và job.`
        : 'GitHub từ chối quyền truy cập cho yêu cầu này (HTTP 403). Đây không phải thông báo token hết hạn hoặc giới hạn lượt gọi.',
    )
  }
  if (response.status === 410)
    throw new ApiError(410, 'GITHUB_GONE', 'Dữ liệu GitHub đã bị xóa hoặc hết thời gian lưu.')
  if (response.status === 404)
    throw new ApiError(
      404,
      'GITHUB_NOT_FOUND',
      'Không có dữ liệu GitHub hoặc không còn quyền truy cập.',
    )
  if (response.status >= 400)
    throw new ApiError(502, 'GITHUB_UNAVAILABLE', 'GitHub chưa trả dữ liệu. Thử lại sau.')
  if (response.status === 304 && entry) {
    entry.until = Date.now() + 300000
    return new Response(entry.body, { status: 200, headers: entry.headers })
  }
  const etag = response.headers.get('etag')
  if (
    response.status === 200 &&
    etag &&
    response.headers.get('content-type')?.includes('application/json')
  ) {
    const body = await response.text()
    const headers = new Headers(response.headers)
    headers.delete('content-encoding')
    headers.delete('content-length')
    if (Buffer.byteLength(body) <= 512 * 1024) {
      if (readCache.size >= 100) readCache.delete(readCache.keys().next().value!)
      readCache.set(cacheKey, {
        etag,
        body,
        headers: [...headers.entries()],
        until: Date.now() + 300000,
      })
    }
    return new Response(body, { status: 200, headers })
  }
  return response
}
export async function publicOwnedRepo(
  identity: { uid: string; githubId: string },
  repo: string,
  signal?: AbortSignal,
) {
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repo))
    throw new ApiError(400, 'INVALID_REPO', 'Tên repository không hợp lệ.')
  const response = await githubRead(identity, `/repos/${repo}`, signal)
  if (response.status !== 200)
    throw new ApiError(
      409,
      'REPO_MOVED',
      'Repository đã đổi địa chỉ. Cập nhật liên kết repo trong workspace.',
    )
  const metadata = (await response.json()) as { private?: boolean; owner?: { id?: number } }
  if (metadata.private !== false)
    throw new ApiError(403, 'PUBLIC_ONLY', 'Mốc hiện tại chỉ hỗ trợ repo public.')
  if (String(metadata.owner?.id) !== identity.githubId)
    throw new ApiError(
      403,
      'REPO_OWNER_MISMATCH',
      'Chỉ xem repo public thuộc tài khoản GitHub đã đăng nhập ở mốc này.',
    )
}

export async function connectionInfo(req: IncomingMessage, res: ServerResponse) {
  const identity = await authenticate(req),
    data = (await ref(identity.uid).get()).data() as Connection | undefined
  if (!data || data.githubId !== identity.githubId || data.state !== 'connected') {
    json(res, 200, { connected: false, state: data?.state ?? 'not_connected' })
    return
  }
  const pair = unseal<TokenPair>(data.encryptedTokens, binding(identity.uid, identity.githubId))
  json(res, 200, {
    connected: pair.refreshExpiresAt > Date.now(),
    state: pair.refreshExpiresAt > Date.now() ? 'connected' : 'expired',
    login: data.login,
    expiresAt: pair.expiresAt,
    refreshExpiresAt: pair.refreshExpiresAt,
    updatedAt: data.updatedAt,
    lastRefreshedAt: data.lastRefreshedAt,
    refreshCount: data.refreshCount ?? 0,
    automaticRefresh: true,
  })
}
export async function disconnect(req: IncomingMessage, res: ServerResponse) {
  sameOrigin(req, true)
  const identity = await authenticate(req),
    record = ref(identity.uid),
    disconnectId = randomUUID()
  // Tombstone rotates identity before external revocation; in-flight refresh/callback cannot restore it.
  const pair = await database().runTransaction(async (tx) => {
    const data = (await tx.get(record)).data() as Connection | undefined
    const old =
      data?.githubId === identity.githubId && data.encryptedTokens
        ? unseal<TokenPair>(data.encryptedTokens, binding(identity.uid, identity.githubId))
        : undefined
    tx.set(record, {
      githubId: identity.githubId,
      login: data?.login ?? '',
      encryptedTokens: '',
      connectionId: disconnectId,
      state: 'disconnecting',
      leaseId: null,
      leaseUntil: Date.now() + 20000,
      updatedAt: Date.now(),
    } satisfies Connection)
    return old
  })
  let revoked = !pair
  if (pair) {
    try {
      const cfg = config()
      const response = await fetch(
        `https://api.github.com/applications/${encodeURIComponent(cfg.clientId)}/grant`,
        {
          method: 'DELETE',
          headers: {
            Authorization: `Basic ${Buffer.from(`${cfg.clientId}:${cfg.clientSecret}`).toString('base64')}`,
            Accept: 'application/vnd.github+json',
            'Content-Type': 'application/json',
            'User-Agent': 'Vista-CI',
            'X-GitHub-Api-Version': '2026-03-10',
          },
          body: JSON.stringify({ access_token: pair.accessToken }),
          signal: AbortSignal.timeout(15000),
          redirect: 'error',
        },
      )
      revoked = response.status === 204
    } catch {
      /* Local credential removal is complete, remote revocation is reported separately. */
    }
  }
  await database().runTransaction(async (tx) => {
    const current = (await tx.get(record)).data()
    if (current?.connectionId === disconnectId)
      tx.update(record, { state: 'disconnected', leaseUntil: 0 })
  })
  json(res, 200, {
    connected: false,
    revoked,
    message: revoked
      ? 'Đã ngắt kết nối và xóa token lưu ở Vista.'
      : 'Đã xóa token lưu ở Vista. Chưa xác nhận thu hồi quyền trên GitHub; vào GitHub Authorized OAuth Apps để thu hồi nếu cần.',
  })
}
export async function startMobileOAuth(req: IncomingMessage, res: ServerResponse) {
  sameOrigin(req, true)
  const state = await newState(await authenticate(req)),
    ticket = randomBytes(32).toString('base64url')
  const id = createHash('sha256').update(ticket).digest('hex')
  state.mobileRequestId = id
  const prior = await database()
    .collection('githubOAuthRequests')
    .where('uid', '==', state.uid)
    .limit(20)
    .get()
  const expired = prior.docs.filter(
    (doc) =>
      typeof doc.data().createdAt === 'number' && doc.data().createdAt + 600000 <= Date.now(),
  )
  if (expired.length) {
    const batch = database().batch()
    for (const item of expired) batch.delete(item.ref)
    await batch.commit()
  }
  await database()
    .collection('githubOAuthRequests')
    .doc(id)
    .set({
      uid: state.uid,
      createdAt: state.createdAt,
      expiresAt: Timestamp.fromMillis(state.createdAt + 600000),
      encryptedState: seal(state, `native-oauth:${id}`),
      opened: false,
      status: 'pending',
    })
  json(res, 200, {
    requestId: id,
    createdAt: state.createdAt,
    openUrl: `${config().origin}/api/github-session?action=mobile-open&ticket=${encodeURIComponent(ticket)}`,
  })
}
export async function openMobileOAuth(res: ServerResponse, url: URL) {
  const ticket = url.searchParams.get('ticket') ?? ''
  if (!/^[A-Za-z0-9_-]{43}$/.test(ticket))
    throw new ApiError(400, 'INVALID_TICKET', 'Yêu cầu kết nối mobile không hợp lệ.')
  const id = createHash('sha256').update(ticket).digest('hex'),
    request = database().collection('githubOAuthRequests').doc(id)
  const state = await database().runTransaction(async (tx) => {
    const data = (await tx.get(request)).data()
    if (!data || data.opened || data.createdAt + 600000 <= Date.now())
      throw new ApiError(
        410,
        'EXPIRED_TICKET',
        'Liên kết kết nối đã dùng hoặc hết hạn. Quay lại app và thử lại.',
      )
    const state = unseal<OAuthState>(data.encryptedState, `native-oauth:${id}`)
    tx.update(request, { opened: true, encryptedState: FieldValue.delete() })
    return state
  })
  protect(res)
  res.setHeader('Set-Cookie', stateCookie(seal(state, 'vista-oauth-state'), 600))
  res.statusCode = 302
  res.setHeader('Location', authorizeUrl(state))
  res.end()
}
export async function mobileOAuthResult(req: IncomingMessage, res: ServerResponse, url: URL) {
  const identity = await authenticate(req),
    id = url.searchParams.get('request') ?? ''
  if (!/^[a-f0-9]{64}$/.test(id))
    throw new ApiError(400, 'INVALID_REQUEST', 'Yêu cầu không hợp lệ.')
  const record = database().collection('githubOAuthRequests').doc(id),
    data = (await record.get()).data()
  if (!data || data.uid !== identity.uid)
    throw new ApiError(404, 'REQUEST_NOT_FOUND', 'Không tìm thấy yêu cầu kết nối.')
  if (data.createdAt + 600000 <= Date.now()) {
    await record.delete()
    throw new ApiError(410, 'REQUEST_EXPIRED', 'Yêu cầu kết nối hết hạn. Thử lại.')
  }
  json(res, 200, { status: data.status, message: data.message ?? '' })
  if (data.status !== 'pending') await record.delete()
}
