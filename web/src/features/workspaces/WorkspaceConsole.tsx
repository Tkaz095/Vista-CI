import { useState } from 'react'
import { demoRuns, demoWorkspaces } from './demo-data'
import type { AuditEntry, CommandAction, CommandDraft, RunStatus, WorkflowRun } from './model'

const statuses: Record<RunStatus, string> = { queued: 'Đang chờ', in_progress: 'Đang chạy', success: 'Pass', failure: 'Fail', cancelled: 'Đã hủy' }
const actions: Record<CommandAction, string> = { dispatch: 'Chạy workflow mới', rerun: 'Chạy lại', create_issue: 'Tạo issue', comment_pr: 'Bình luận PR' }
const kinds = { code: 'Lỗi code / kiểm tra', transient: 'Có thể tạm thời', configuration: 'Lỗi cấu hình', unknown: 'Chưa kết luận' }
const dateLabel = (date: string) => new Intl.DateTimeFormat('vi-VN', { dateStyle: 'short', timeStyle: 'short', timeZone: 'Asia/Ho_Chi_Minh' }).format(new Date(date))
const pageSize = 4

function Status({ value }: { value: RunStatus }) {
  return <span className={`status status-${value}`}><span aria-hidden="true" />{statuses[value]}</span>
}

export function WorkspaceConsole({ onExit }: { onExit: () => void }) {
  const [workspaceId, setWorkspaceId] = useState(demoWorkspaces[0].id)
  const [view, setView] = useState<'runs' | 'repositories' | 'audit'>('runs')
  const [repositoryId, setRepositoryId] = useState('all')
  const [status, setStatus] = useState('all')
  const [branch, setBranch] = useState('all')
  const [page, setPage] = useState(0)
  const [selectedKey, setSelectedKey] = useState<string | null>(null)
  const [tab, setTab] = useState<'log' | 'analysis'>('log')
  const [analyzed, setAnalyzed] = useState<string[]>([])
  const [draft, setDraft] = useState<CommandDraft | null>(null)
  const [audit, setAudit] = useState<AuditEntry[]>([])
  const [notice, setNotice] = useState('')
  const workspace = demoWorkspaces.find((item) => item.id === workspaceId)!
  const runs = demoRuns.filter((run) => run.workspaceId === workspaceId)
  const filtered = runs.filter((run) => (repositoryId === 'all' || run.repositoryId === repositoryId) && (status === 'all' || run.status === status) && (branch === 'all' || run.branch === branch))
    .sort((a, b) => b.startedAt.localeCompare(a.startedAt))
  const totalPages = Math.max(1, Math.ceil(filtered.length / pageSize))
  const selected = runs.find((run) => run.key === selectedKey)
  const diagnosis = selected?.exampleDiagnosis
  const repoName = (id: string) => workspace.repositories.find((repo) => repo.id === id)?.name ?? id
  const workspaceAudit = audit.filter((entry) => entry.workspaceId === workspaceId)
  function resetFilters() { setRepositoryId('all'); setStatus('all'); setBranch('all'); setPage(0) }
  function changeWorkspace(id: string) { setWorkspaceId(id); resetFilters(); setSelectedKey(null); setDraft(null); setNotice('') }
  function openRun(run: WorkflowRun) { setSelectedKey(run.key); setTab('log'); setDraft(null); setNotice('') }
  function previewCommand(run: WorkflowRun, action: CommandAction) {
    const analysis = run.exampleDiagnosis
    const body = (action === 'comment_pr' || action === 'create_issue') && analysis
      ? `Phân tích mẫu của Vista — chưa gửi\n\nRun: ${run.runId}, attempt ${run.attempt}, commit ${run.sha}\nNhận định: ${analysis.summary}\nDẫn chứng: ${analysis.evidence}\n${analysis.location ? `Vị trí: ${analysis.location}\n` : ''}Đề xuất:\n${analysis.suggestions.map((item) => `- ${item}`).join('\n')}\n\nCần kiểm tra lại trước khi đăng.`
      : `${actions[action]}\nRepository: ${repoName(run.repositoryId)}\nWorkflow: ${run.workflow}\nBranch: ${run.branch}${action === 'rerun' ? `\nRun nguồn: ${run.runId}, attempt ${run.attempt}` : ''}`
    setDraft({ workspaceId, repositoryId: run.repositoryId, runKey: run.key, action, body })
    setAudit((entries) => [{ id: crypto.randomUUID(), workspaceId, actor: 'Người xem thử', action: `Xem trước: ${actions[action]}`, target: `${repoName(run.repositoryId)} · ${run.runId}`, at: new Date().toISOString(), outcome: 'preview' }, ...entries])
  }
  return <div className="app-shell">
    <aside className="sidebar">
      <button className="brand brand-button" onClick={() => setView('runs')}><span className="brand-mark">V</span> Vista <strong>CI</strong></button>
      <label className="workspace-picker">WORKSPACE<select value={workspaceId} onChange={(event) => changeWorkspace(event.target.value)}>{demoWorkspaces.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
      <nav className="side-nav" aria-label="Điều hướng workspace">
        <button className={`nav-item ${view === 'runs' ? 'active' : ''}`} onClick={() => setView('runs')}><span aria-hidden="true">◷</span> CI/CD runs <small>{runs.length}</small></button>
        <button className={`nav-item ${view === 'repositories' ? 'active' : ''}`} onClick={() => setView('repositories')}><span aria-hidden="true">⌘</span> Repositories <small>{workspace.repositories.length}</small></button>
        <button className={`nav-item ${view === 'audit' ? 'active' : ''}`} onClick={() => setView('audit')}><span aria-hidden="true">≡</span> Audit</button>
      </nav>
      <div className="sidebar-note"><strong>Một nơi cho cả dự án</strong><p>Repo, workflow và hướng xử lý lỗi được gắn với đúng workspace.</p></div>
      <button className="exit-button" onClick={onExit}>← Về màn hình đăng nhập</button>
    </aside>
    <main className="main-content">
      <header className="topbar"><div className="breadcrumbs">Workspaces <span>/</span> {workspace.name}</div><span className="preview-label">Dữ liệu mẫu · chưa kết nối GitHub / AI</span></header>
      <div className="page-content">
        <div className="page-heading"><div><span className="eyebrow">WORKSPACE / {workspace.name.toUpperCase()}</span><h1>{view === 'runs' ? 'CI/CD monitoring' : view === 'repositories' ? 'Repositories' : 'Lịch sử thao tác'}</h1><p>{view === 'audit' ? 'Các thao tác xem trước trong phiên này. Chưa phải audit từ server.' : workspace.description}</p></div><span className="scope-note">Xem trước luồng MVP</span></div>
        {view === 'runs' && <>
          <div className="metric-grid">{[['Tổng lần chạy mẫu', runs.length], ['Pass', runs.filter((run) => run.status === 'success').length], ['Fail', runs.filter((run) => run.status === 'failure').length], ['Đang chạy / chờ', runs.filter((run) => ['in_progress', 'queued'].includes(run.status)).length]].map(([label, value]) => <article className="metric-card" key={label}><span>{label}</span><strong>{value}</strong></article>)}</div>
          <section className="panel run-list" aria-label="Lịch sử CI/CD">
            <div className="panel-heading"><div><h2>Lịch sử các lần chạy</h2><p>Chọn một lần chạy để đọc log và xem hướng xử lý.</p></div></div>
            <div className="filters">
              <label>Repository<select value={repositoryId} onChange={(e) => { setRepositoryId(e.target.value); setPage(0) }}><option value="all">Tất cả repositories</option>{workspace.repositories.map((repo) => <option key={repo.id} value={repo.id}>{repo.name}</option>)}</select></label>
              <label>Kết quả<select value={status} onChange={(e) => { setStatus(e.target.value); setPage(0) }}><option value="all">Tất cả trạng thái</option>{Object.entries(statuses).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></label>
              <label>Branch<select value={branch} onChange={(e) => { setBranch(e.target.value); setPage(0) }}><option value="all">Tất cả branches</option>{[...new Set(runs.map((run) => run.branch))].sort().map((item) => <option key={item}>{item}</option>)}</select></label>
              <button className="text-button" onClick={resetFilters}>Xóa bộ lọc</button>
            </div>
            <div className="table-scroll"><table><thead><tr><th>Workflow / repository</th><th>Trạng thái</th><th>Branch / commit</th><th>Thời gian</th><th>Chi tiết</th></tr></thead><tbody>{filtered.slice(page * pageSize, (page + 1) * pageSize).map((run) => <tr key={run.key} className={selectedKey === run.key ? 'selected-row' : ''}><td><strong>{run.workflow}</strong><small>{repoName(run.repositoryId)} · {run.runId}</small></td><td><Status value={run.status} /></td><td>{run.branch}<small><code>{run.sha}</code>{run.pullRequest && ` · PR #${run.pullRequest.number}`}</small></td><td>{run.duration}<small>{dateLabel(run.startedAt)}</small></td><td><button className="run-open" onClick={() => openRun(run)}>Xem {run.runId} ↗</button></td></tr>)}</tbody></table></div>
            {!filtered.length && <div className="empty-state"><h3>Chưa có lần chạy phù hợp</h3><p>{runs.length ? 'Thử thay đổi bộ lọc.' : 'Workspace chưa có repository hoặc dữ liệu CI/CD.'}</p></div>}
            <div className="pagination"><span>{filtered.length} lần chạy mẫu</span><div><button disabled={!page} onClick={() => setPage(page - 1)}>Trước</button><span>Trang {page + 1} / {totalPages}</span><button disabled={page + 1 >= totalPages} onClick={() => setPage(page + 1)}>Sau</button></div></div>
          </section>
          {selected && <section className="panel run-detail" aria-label={`Chi tiết ${selected.runId}`}>
            <div className="panel-heading"><div><span className="eyebrow">RUN DETAIL · ATTEMPT {selected.attempt}</span><h2>{selected.workflow} <Status value={selected.status} /></h2><p>{repoName(selected.repositoryId)} · {selected.branch} · {selected.sha}</p></div><button className="text-button" onClick={() => { setSelectedKey(null); setDraft(null) }}>Đóng chi tiết</button></div>
            <div className="attribution"><span>Người kích hoạt: <strong>{selected.triggerActor}</strong></span><span>{selected.pullRequest ? `PR #${selected.pullRequest.number} · Tác giả PR: ${selected.pullRequest.author}` : 'Run không gắn PR trong dữ liệu mẫu'}</span></div>
            <div className="steps">{selected.steps.map((step) => <div key={step.name}><Status value={step.status} /><span>{step.name}</span></div>)}</div>
            <div className="detail-tabs"><button aria-pressed={tab === 'log'} onClick={() => setTab('log')}>Logs</button><button aria-pressed={tab === 'analysis'} onClick={() => setTab('analysis')}>Agent phân tích</button></div>
            {tab === 'log' ? <pre className="log-view" aria-label="Log mẫu">{selected.log.map((line, i) => <span key={i}><i>{String(i + 1).padStart(2, '0')}</i>{line}{'\n'}</span>)}</pre> : <div className="analysis-panel">
              <div className="analysis-heading"><div><h3>Đọc lỗi, hiểu bước tiếp theo</h3><p>Agent chưa chốt dịch vụ. Ưu tiên phương án miễn phí.</p></div><button className="primary-button" disabled={selected.status !== 'failure'} onClick={() => setAnalyzed((keys) => keys.includes(selected.key) ? keys : [...keys, selected.key])}>Xem phân tích mẫu</button></div>
              {selected.status !== 'failure' ? <p>Chọn run thất bại để xem luồng phân tích.</p> : analyzed.includes(selected.key) && diagnosis ? <>
                <span className="preview-label">Ví dụ soạn sẵn · không phải kết quả AI</span><h3>{kinds[diagnosis.kind]}</h3><p>{diagnosis.summary}</p><blockquote>{diagnosis.evidence}</blockquote>{diagnosis.location && <p>Vị trí được log chỉ ra: <code>{diagnosis.location}</code></p>}<ol>{diagnosis.suggestions.map((item) => <li key={item}>{item}</li>)}</ol>
                <p className="small-note">{diagnosis.kind === 'configuration' ? 'Sửa cấu hình trước khi thử lại.' : diagnosis.kind === 'transient' ? 'Chạy lại là lựa chọn của người dùng, không tự động thực hiện.' : 'Nhận định cần được người dùng xem lại trước khi đăng.'}</p>
                <div className="action-row"><button className="secondary-button" onClick={() => previewCommand(selected, 'create_issue')}>Soạn issue</button><button className="secondary-button" disabled={!selected.pullRequest} onClick={() => previewCommand(selected, 'comment_pr')}>Soạn comment PR</button></div>
              </> : <p className="empty-analysis">Chọn “Xem phân tích mẫu” để xem nhận định, dẫn chứng và đề xuất.</p>}
            </div>}
            <div className="action-row run-actions"><button className="secondary-button" onClick={() => previewCommand(selected, 'dispatch')}>Xem trước chạy mới</button><button className="secondary-button" disabled={selected.status !== 'failure'} onClick={() => previewCommand(selected, 'rerun')}>Xem trước chạy lại</button><button className="text-button" disabled>Artifact chưa kết nối</button><button className="text-button" disabled>Website chưa kết nối</button></div>
            {draft?.runKey === selected.key && <div className="command-preview"><div className="panel-heading"><h3>{actions[draft.action]} — bản nháp</h3><button className="text-button" onClick={() => setDraft(null)}>Đóng bản nháp</button></div><label>Nội dung yêu cầu<textarea value={draft.body} onChange={(event) => setDraft({ ...draft, body: event.target.value })} rows={8} /></label><div className="action-row"><button className="primary-button" disabled>Gửi GitHub — chưa kết nối</button><button className="secondary-button" onClick={async () => { try { await navigator.clipboard.writeText(draft.body); setNotice('Đã sao chép bản nháp.') } catch { setNotice('Không thể sao chép. Bạn có thể chọn nội dung và sao chép thủ công.') } }}>Sao chép</button></div><p className="small-note">Chưa gửi yêu cầu đến GitHub. Bản nháp và audit xem trước chỉ giữ trong phiên này.</p></div>}
            <p className="notice" role="status">{notice}</p>
          </section>}
        </>}
        {view === 'repositories' && <section className="repo-grid" aria-label="Repositories">{workspace.repositories.map((repo) => <article className="panel repo-card" key={repo.id}><span className="repo-icon" aria-hidden="true">⌘</span><h2>{repo.name}</h2><p>{repo.description}</p><span className="preview-label">Repository mẫu</span><button className="secondary-button" onClick={() => { setView('runs'); resetFilters(); setRepositoryId(repo.id); setSelectedKey(null); setDraft(null) }}>Xem các lần chạy →</button></article>)}{!workspace.repositories.length && <div className="panel empty-state"><h2>Chưa có repository</h2><p>Kết nối repository sẽ có ở giai đoạn tích hợp GitHub.</p></div>}</section>}
        {view === 'audit' && <section className="panel"><div className="panel-heading"><div><h2>Audit xem trước</h2><p>Truy vết thao tác và nguồn PR. Không suy diễn chất lượng code từ số lần CI fail.</p></div></div>{workspaceAudit.length ? <div className="table-scroll"><table><thead><tr><th>Thời gian</th><th>Người thao tác</th><th>Hành động / đích</th><th>Kết quả</th></tr></thead><tbody>{workspaceAudit.map((entry) => <tr key={entry.id}><td>{dateLabel(entry.at)}</td><td>{entry.actor}</td><td>{entry.action}<small>{entry.target}</small></td><td><span className="preview-label">Chỉ xem trước</span></td></tr>)}</tbody></table></div> : <div className="empty-state"><h3>Chưa có thao tác xem trước</h3><p>Mở một run rồi xem trước chạy workflow, issue hoặc comment để xem audit mẫu.</p></div>}</section>}
      </div>
    </main>
  </div>
}
