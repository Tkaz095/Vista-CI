import type { IncomingMessage, ServerResponse } from 'node:http'
import {
  ApiError,
  failure,
  finishOAuth,
  startOAuth,
  status,
  connectionInfo,
  disconnect,
  startMobileOAuth,
  openMobileOAuth,
  mobileOAuthResult,
} from '../server/githubAuth.js'
export default async function githubSession(req: IncomingMessage, res: ServerResponse) {
  try {
    const url = new URL(req.url ?? '/', 'http://localhost'),
      action = url.searchParams.get('action')
    if (action === 'info' && req.method === 'GET') {
      await connectionInfo(req, res)
      return
    }
    if (action === 'disconnect' && req.method === 'POST') {
      await disconnect(req, res)
      return
    }
    if (action === 'mobile-start' && req.method === 'POST') {
      await startMobileOAuth(req, res)
      return
    }
    if (action === 'mobile-open' && req.method === 'GET') {
      await openMobileOAuth(res, url)
      return
    }
    if (action === 'mobile-result' && req.method === 'GET') {
      await mobileOAuthResult(req, res, url)
      return
    }
    if (action === 'callback' && req.method === 'GET') {
      await finishOAuth(req, res, url)
      return
    }
    if (action === 'start' && req.method === 'POST') {
      await startOAuth(req, res)
      return
    }
    if (action === 'status' && req.method === 'GET') {
      await status(req, res)
      return
    }
    throw new ApiError(405, 'METHOD_NOT_ALLOWED', 'Yêu cầu kết nối GitHub không hợp lệ.')
  } catch (error) {
    failure(res, error)
  }
}
