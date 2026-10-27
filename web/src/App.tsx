import './App.css'

const metrics = [
  { label: 'Workflows', value: '—', symbol: '⌘' },
  { label: 'Succeeded', value: '—', symbol: '✓' },
  { label: 'Failed', value: '—', symbol: '!' },
]

function App() {
  return (
    <div className="app-shell">
      <aside className="sidebar">
        <a className="brand" href="#overview" aria-label="Vista CI overview">
          <span className="brand-mark">V</span>
          <span>Vista <strong>CI</strong></span>
        </a>

        <div className="nav-label">WORKSPACE</div>
        <nav className="side-nav" aria-label="Main navigation">
          <a className="nav-item active" href="#overview"><span>▦</span> Overview</a>
          <span className="nav-item disabled"><span>⌘</span> Pipelines</span>
          <span className="nav-item disabled"><span>↗</span> Deployments</span>
        </nav>

        <div className="sidebar-project">
          <div className="nav-label">CURRENT PROJECT</div>
          <div className="project-row"><span className="project-dot" /> Vista demo</div>
          <div className="project-note">Waiting for Firebase setup</div>
        </div>

        <div className="sidebar-footer">CI/CD visibility, in one place.</div>
      </aside>

      <main className="main-content" id="overview">
        <header className="topbar">
          <div className="breadcrumbs">Workspace <span>/</span> Overview</div>
          <div className="avatar" aria-label="User profile">K</div>
        </header>

        <div className="page-content">
          <section className="page-heading">
            <div>
              <div className="eyebrow">MONITORING</div>
              <h1>Pipeline overview</h1>
              <p>Track workflow runs and deployments from one dashboard.</p>
            </div>
            <div className="connection-pill"><span /> Firebase not connected</div>
          </section>

          <section className="metric-grid" aria-label="Pipeline summary">
            {metrics.map((metric) => (
              <article className="metric-card" key={metric.label}>
                <div className="metric-top"><span>{metric.label}</span><span className="metric-symbol">{metric.symbol}</span></div>
                <div className="metric-value">{metric.value}</div>
                <div className="metric-caption">Connect a data source to view results</div>
              </article>
            ))}
          </section>

          <section className="content-grid">
            <article className="panel recent-panel">
              <div className="panel-heading">
                <div><h2>Recent runs</h2><p>Your latest workflow activity</p></div>
                <button className="text-button" type="button" disabled>View all <span>→</span></button>
              </div>
              <div className="empty-state">
                <div className="empty-icon">◷</div>
                <h3>No pipeline runs yet</h3>
                <p>Once your repository is connected, recent runs will appear here.</p>
              </div>
            </article>

            <article className="panel setup-panel">
              <div className="panel-heading"><div><h2>Get started</h2><p>Set up your monitoring workspace</p></div></div>
              <div className="setup-step"><span className="step-number">01</span><div><strong>Connect Firebase</strong><p>Create a Firebase project and add both apps.</p></div></div>
              <div className="setup-step"><span className="step-number">02</span><div><strong>Connect a repository</strong><p>Choose the GitHub Actions workflows to follow.</p></div></div>
              <div className="setup-step"><span className="step-number">03</span><div><strong>Enable notifications</strong><p>Get updates when a run succeeds or fails.</p></div></div>
            </article>
          </section>
        </div>
      </main>
    </div>
  )
}

export default App
