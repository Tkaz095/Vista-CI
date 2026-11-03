import type { IncomingMessage, ServerResponse } from 'node:http'
import githubData from './api/github-data.js'
import githubSession from './api/github-session.js'
import githubJobLog from './api/github-job-log.js'
import { failure, json, protect } from './server/githubAuth.js'

const routes = new Map([
  ['/api/github-data', githubData],
  ['/api/github-session', githubSession],
  ['/api/github-job-log', githubJobLog],
])

// Hosting preserves /api/... and the query string when forwarding to the function.
// Each data handler still verifies Firebase identity and repo ownership.
export async function route(req: IncomingMessage, res: ServerResponse) {
  protect(res)
  try {
    const path = new URL(req.url ?? '/', 'http://localhost').pathname
    if (path === '/api/health' && req.method === 'GET') {
      json(res, 200, { status: 'ok', service: 'vista-api' })
      return
    }
    const handler = routes.get(path)
    if (!handler) {
      json(res, 404, { code: 'API_NOT_FOUND', message: 'Không có API Vista tại địa chỉ này.' })
      return
    }
    await handler(req, res)
  } catch (error) {
    failure(res, error)
  }
}
