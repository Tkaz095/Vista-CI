import { onRequest } from 'firebase-functions/v2/https'
import { route } from './router.js'
import { githubClientSecret, tokenEncryptionKey } from './settings.js'

export const vistaApi = onRequest(
  {
    region: 'asia-southeast1',
    memory: '256MiB',
    cpu: 1,
    minInstances: 0,
    maxInstances: 2,
    concurrency: 10,
    timeoutSeconds: 60,
    invoker: 'public',
    cors: false,
    secrets: [githubClientSecret, tokenEncryptionKey],
  },
  async (req, res) => { await route(req, res) },
)
