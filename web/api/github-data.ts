import type { IncomingMessage, ServerResponse } from 'node:http'
import {
  ApiError,
  authenticate,
  failure,
  githubRead,
  json,
  publicOwnedRepo,
} from '../server/githubAuth'
export default async function githubData(req: IncomingMessage, res: ServerResponse) {
  try {
    if (req.method !== 'GET')
      throw new ApiError(405, 'METHOD_NOT_ALLOWED', 'Chỉ hỗ trợ đọc dữ liệu GitHub.')
    const identity = await authenticate(req),
      query = new URL(req.url ?? '/', 'http://localhost').searchParams
    const kind = query.get('kind'),
      repo = query.get('repo') ?? '',
      page = Number(query.get('page') ?? 1)
    if (!Number.isSafeInteger(page) || page < 1 || page > 10000)
      throw new ApiError(400, 'INVALID_PAGE', 'Trang không hợp lệ.')
    let path: string
    if (kind === 'repos')
      path = `/user/repos?visibility=public&affiliation=owner&per_page=100&sort=updated&page=${page}`
    else {
      await publicOwnedRepo(identity, repo)
      if (kind === 'runs') {
        const branch = query.get('branch') ?? '',
          state = query.get('status') ?? ''
        const allowed = [
          '',
          'queued',
          'in_progress',
          'completed',
          'success',
          'failure',
          'cancelled',
          'timed_out',
        ]
        if (branch.length > 255 || !allowed.includes(state))
          throw new ApiError(400, 'INVALID_FILTER', 'Bộ lọc CI/CD không hợp lệ.')
        const filter = new URLSearchParams({ per_page: '20', page: String(page) })
        if (branch) filter.set('branch', branch)
        if (state) filter.set('status', state)
        path = `/repos/${repo}/actions/runs?${filter}`
      } else if (kind === 'jobs' || kind === 'run') {
        const run = query.get('run') ?? '',
          attempt = query.get('attempt') ?? ''
        if (!/^[1-9][0-9]{0,19}$/.test(run) || !/^[1-9][0-9]{0,9}$/.test(attempt))
          throw new ApiError(400, 'INVALID_RUN', 'Lần chạy không hợp lệ.')
        path = `/repos/${repo}/actions/runs/${run}/attempts/${attempt}${kind === 'jobs' ? `/jobs?per_page=50&page=${page}` : ''}`
      } else throw new ApiError(400, 'INVALID_KIND', 'Loại dữ liệu không hợp lệ.')
    }
    const response = await githubRead(identity, path)
    if (response.status !== 200)
      throw new ApiError(502, 'GITHUB_RESPONSE', 'GitHub chưa trả dữ liệu hợp lệ.')
    json(res, 200, {
      data: await response.json(),
      more: /rel="next"/.test(response.headers.get('Link') ?? ''),
    })
  } catch (error) {
    failure(res, error)
  }
}
