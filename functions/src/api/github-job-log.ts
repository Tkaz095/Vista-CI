import type { IncomingMessage, ServerResponse } from 'node:http'
import { ApiError, authenticate, failure, githubRead, publicOwnedRepo } from '../server/githubAuth.js'

// Read a GitHub job log after verifying Firebase identity; GitHub tokens stay server-side.
// Never forward that credential to the signed storage URL or accept arbitrary URLs.
export default async function githubJobLog(req: IncomingMessage, res: ServerResponse) {
  res.setHeader('Cache-Control', 'no-store, private')
  res.setHeader('Content-Type', 'text/plain; charset=utf-8')
  res.setHeader('X-Content-Type-Options', 'nosniff')
  const fail = (code: number, message: string) => {
    res.statusCode = code
    res.end(message)
  }
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET')
    fail(405, 'Chỉ hỗ trợ GET.')
    return
  }
  const url = new URL(req.url ?? '/', 'http://localhost')
  const repo = url.searchParams.get('repo') ?? '',
    job = url.searchParams.get('job') ?? ''
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repo) || !/^[1-9][0-9]{0,19}$/.test(job)) {
    fail(400, 'Repo hoặc job không hợp lệ.')
    return
  }
  const controller = new AbortController()
  const deadline = setTimeout(() => controller.abort(), 20000)
  const disconnected = () => {
    if (!res.writableEnded) controller.abort()
  }
  res.on('close', disconnected)
  let readingLog = false
  try {
    const identity = await authenticate(req)
    await publicOwnedRepo(identity, repo, controller.signal)
    const detail = await githubRead(
      identity,
      `/repos/${repo}/actions/jobs/${job}`,
      controller.signal,
    )
    if (!detail.ok) {
      fail(
        detail.status,
        detail.status === 401
          ? 'Kết nối GitHub hết hạn. Hãy kết nối lại.'
          : detail.status === 403 || detail.status === 429
            ? 'GitHub giới hạn lượt gọi hoặc chưa cấp quyền đọc log.'
            : 'Không đọc được job. Kiểm tra quyền truy cập hoặc job đã bị xóa.',
      )
      return
    }
    const metadata = (await detail.json()) as { id?: number; status?: string }
    if (String(metadata.id) !== job) {
      fail(502, 'Job GitHub trả về không khớp.')
      return
    }
    if (metadata.status !== 'completed') {
      fail(409, 'Job chưa hoàn tất. Log đầy đủ có sau khi job kết thúc.')
      return
    }
    readingLog = true
    const source = await githubRead(
      identity,
      `/repos/${repo}/actions/jobs/${job}/logs`,
      controller.signal,
    )
    if (source.status !== 302) {
      fail(
        source.status === 404 || source.status === 410
          ? 410
          : source.status >= 400
            ? source.status
            : 502,
        source.status === 401
          ? 'Kết nối GitHub hết hạn.'
          : 'Log chưa sẵn sàng, đã hết thời gian lưu trữ hoặc chưa có quyền tải.',
      )
      return
    }
    const location = source.headers.get('location')
    if (!location) {
      fail(502, 'GitHub không trả địa chỉ log.')
      return
    }
    const destination = new URL(location)
    const allowed = [
      '.blob.core.windows.net',
      '.actions.githubusercontent.com',
      '.githubusercontent.com',
    ].some((suffix) => destination.hostname.endsWith(suffix))
    if (
      destination.protocol !== 'https:' ||
      destination.username ||
      destination.password ||
      destination.port ||
      !allowed
    ) {
      fail(502, 'Địa chỉ lưu log GitHub chưa được hỗ trợ.')
      return
    }
    const download = await fetch(destination, { signal: controller.signal, redirect: 'error' })
    if (!download.ok || !download.body) {
      fail(502, 'Không tải được nội dung log từ GitHub. Thử lại.')
      return
    }
    const limit = 2 * 1024 * 1024,
      chunks: Uint8Array[] = []
    let bytes = 0,
      truncated = false
    const reader = download.body.getReader()
    try {
      while (true) {
        const { done, value } = await reader.read()
        if (done) break
        if (bytes + value.byteLength > limit) {
          chunks.push(value.subarray(0, limit - bytes))
          truncated = true
          await reader.cancel()
          break
        }
        chunks.push(value)
        bytes += value.byteLength
      }
    } finally {
      reader.releaseLock()
    }
    res.setHeader('X-Vista-Truncated', truncated ? 'true' : 'false')
    res.end(Buffer.concat(chunks))
  } catch (error) {
    if (!res.destroyed) {
      if (!controller.signal.aborted) {
        if (readingLog && error instanceof ApiError && [404, 410].includes(error.status)) {
          failure(
            res,
            new ApiError(
              410,
              'LOG_UNAVAILABLE',
              'Log chưa có, đã bị xóa/hết thời gian lưu trữ hoặc không còn quyền tải.',
            ),
          )
          return
        }
        failure(res, error)
        return
      }
      fail(
        controller.signal.aborted ? 504 : 502,
        controller.signal.aborted
          ? 'Quá thời gian tải log. Thử lại.'
          : 'Không kết nối được nguồn log GitHub. Thử lại.',
      )
    }
  } finally {
    clearTimeout(deadline)
    res.off('close', disconnected)
  }
}
