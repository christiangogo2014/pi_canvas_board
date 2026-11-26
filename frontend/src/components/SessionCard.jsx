import { fmtDate } from '../fmt.js'

export default function SessionCard({ session }) {
  return (
    <div className="session-card">
      <div className="fw-semibold text-wrap">{session.name || session.preview || session.pi_id.slice(0, 8)}</div>
      {session.name && session.preview && (
        <div className="text-body-secondary small text-truncate">{session.preview}</div>
      )}
      <div className="d-flex align-items-center gap-2 mt-2 card-meta small">
        <span className="badge text-bg-dark-subtle">{session.model || '—'}</span>
        <span className="text-body-secondary" title={fmtDate(session.updated_at_session)}>
          <i className="bi bi-clock me-1" />{fmtDate(session.updated_at_session)}
        </span>
        {session.cost > 0 && <span className="badge text-bg-success-subtle ms-auto">${session.cost.toFixed(4)}</span>}
      </div>
    </div>
  )
}
