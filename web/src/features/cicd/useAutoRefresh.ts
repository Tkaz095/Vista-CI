import { useEffect, useEffectEvent } from 'react'
import { GitHubConnectionError } from '../github/githubService'

const requiresAction = new Set([
  'SERVER_SETUP_REQUIRED',
  'FIREBASE_BACKEND_UNAVAILABLE',
  'FIREBASE_AUTH_REQUIRED',
  'VISTA_ACCESS_DENIED',
  'GITHUB_LINK_REQUIRED',
  'RECONNECT_REQUIRED',
  'REPO_OWNER_MISMATCH',
  'PUBLIC_ONLY',
  'GITHUB_NOT_FOUND',
  'REPO_MOVED',
  'INVALID_RESPONSE',
  'GITHUB_PERMISSION_DENIED',
  'REFRESH_NOT_SUPPORTED',
  'OAUTH_EXCHANGE_FAILED',
  'GITHUB_AUTH_REJECTED',
])
export const canAutoRetry = (code: string) => !requiresAction.has(code)

export function refreshDelay(
  base: number,
  errors: { code: string; retryAt?: number }[],
  failures: number,
) {
  if (errors.some((error) => requiresAction.has(error.code))) return null
  const retryAt = Math.max(0, ...errors.map((error) => error.retryAt ?? 0))
  return Math.max(base * 2 ** Math.min(failures, 5), retryAt - Date.now())
}

export function describeFailure(cause: unknown) {
  if (cause instanceof GitHubConnectionError)
    return { error: cause.message, code: cause.code, retryAt: cause.retryAt }
  return {
    error:
      cause instanceof DOMException && cause.name === 'AbortError'
        ? 'Hết thời gian chờ backend. Thử lại.'
        : cause instanceof TypeError
          ? 'Không kết nối được backend Vista. Kiểm tra mạng và Vite/Vercel.'
          : cause instanceof Error
            ? cause.message
            : 'Không tải được CI/CD.',
    code: 'NETWORK_OR_RESPONSE',
  }
}

// One request cycle at a time; hidden/offline tabs do not poll.
export function useAutoRefresh(action: () => Promise<void>, delay: number | null, notBefore = 0) {
  const refresh = useEffectEvent(action)
  useEffect(() => {
    if (delay === null) return
    let disposed = false,
      busy = false
    let timer: ReturnType<typeof setTimeout> | undefined
    function schedule() {
      clearTimeout(timer)
      if (!disposed && document.visibilityState === 'visible' && navigator.onLine)
        timer = setTimeout(() => void tick(), delay ?? 60000)
    }
    async function tick() {
      if (disposed || busy || document.visibilityState !== 'visible' || !navigator.onLine) return
      if (Date.now() < notBefore) {
        timer = setTimeout(() => void tick(), notBefore - Date.now())
        return
      }
      busy = true
      try {
        await refresh()
      } finally {
        busy = false
        schedule()
      }
    }
    function resume() {
      clearTimeout(timer)
      if (document.visibilityState === 'visible' && navigator.onLine) void tick()
    }
    schedule()
    document.addEventListener('visibilitychange', resume)
    window.addEventListener('online', resume)
    return () => {
      disposed = true
      clearTimeout(timer)
      document.removeEventListener('visibilitychange', resume)
      window.removeEventListener('online', resume)
    }
  }, [delay, notBefore])
}
