import { useEffect, useState } from 'react'
import { observeSession } from './authService'
import type { AuthSession } from './authService'

export function useAuthSession() {
  const [session, setSession] = useState<AuthSession>({ status: 'initializing' })
  const [attempt, setAttempt] = useState(0)
  useEffect(() => observeSession(setSession), [attempt])
  return { session, retry: () => setAttempt((value) => value + 1) }
}
