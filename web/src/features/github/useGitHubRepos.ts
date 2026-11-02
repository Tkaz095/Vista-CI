import { useCallback, useEffect, useRef, useState } from 'react'
import { authErrorMessage } from '../auth/authService'
import { connectGitHub, fetchGitHubRepos, GitHubConnectionError } from './githubService'
import type { GitHubRepo } from './githubService'

export function useGitHubRepos() {
  const [repos, setRepos] = useState<GitHubRepo[]>([])
  const [pending, setPending] = useState(false)
  const [error, setError] = useState('')
  const [more, setMore] = useState(false)
  const [loaded, setLoaded] = useState(false)
  const page = useRef(0),
    busy = useRef(false),
    alive = useRef(true)
  const abort = useRef<AbortController | null>(null)
  useEffect(() => {
    alive.current = true
    return () => {
      alive.current = false
      abort.current?.abort()
    }
  }, [])
  const load = useCallback(async (reconnect = false, includePrivate = false, next = false) => {
    if (busy.current) return
    busy.current = true
    setPending(true)
    setError('')
    if (!next) {
      setRepos([])
      setLoaded(false)
      setMore(false)
      page.current = 0
    }
    let deadline: ReturnType<typeof setTimeout> | undefined
    try {
      if (reconnect) await connectGitHub(includePrivate)
      if (!alive.current) return
      abort.current = new AbortController()
      deadline = setTimeout(() => abort.current?.abort(), 20000)
      const target = next ? page.current + 1 : 1
      const result = await fetchGitHubRepos(target, abort.current.signal)
      if (!alive.current) return
      page.current = target
      setLoaded(true)
      setRepos((previous) => [
        ...new Map([...previous, ...result.repos].map((repo) => [repo.id, repo])).values(),
      ])
      setMore(result.more)
    } catch (cause) {
      if (!alive.current) return
      setError(
        cause instanceof DOMException && cause.name === 'AbortError'
          ? 'Quá thời gian tải repo GitHub. Kiểm tra mạng rồi thử lại.'
          : cause instanceof TypeError
            ? 'Không kết nối được GitHub. Kiểm tra mạng rồi thử lại.'
            : cause instanceof GitHubConnectionError ||
                (cause instanceof Error && !('code' in cause))
              ? cause.message
              : authErrorMessage(cause),
      )
    } finally {
      clearTimeout(deadline)
      busy.current = false
      if (alive.current) setPending(false)
    }
  }, [])
  useEffect(() => {
    const initial = setTimeout(() => {
      void load()
    }, 0)
    return () => clearTimeout(initial)
  }, [load])
  useEffect(() => {
    const refresh = () => {
      void load()
    }
    window.addEventListener('vista-github-connection', refresh)
    return () => window.removeEventListener('vista-github-connection', refresh)
  }, [load])
  return { repos, pending, error, more, loaded, load }
}
