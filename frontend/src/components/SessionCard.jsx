// Kanban card for both card kinds:
// - automated: a pi coding-agent session (robot icon)
// - manual: a user-created task (person icon), editable inline via double click
import { useState } from 'react'
import { fmtDate } from '../fmt.js'

export default function SessionCard({ session, onDelete, onEdit }) {
  const [editing, setEditing] = useState(false)
  const [title, setTitle] = useState(session.title || '')

  if (session.kind === 'manual') {
    const save = () => {
      setEditing(false)
      const next = title.trim()
      if (!next || next === session.title) return
      onEdit(session.pi_id, next)
    }
    return (
      <div className="session-card session-card-manual" onDoubleClick={() => setEditing(true)}>
        <div className="d-flex align-items-start gap-2">
          <i className="bi bi-person-arms-up text-body-secondary mt-1" title="Manual task" />
          <div className="fw-semibold text-wrap flex-grow-1">
            {editing ? (
              <form onSubmit={(e) => { e.preventDefault(); save() }}>
                <input className="form-control form-control-sm" value={title} autoFocus
                       onBlur={save}
                       onChange={(e) => setTitle(e.target.value)}
                       onKeyDown={(e) => { if (e.key === 'Escape') setEditing(false) }} />
              </form>
            ) : session.title}
          </div>
          <span className="badge text-bg-warning-subtle mt-1">Manual</span>
          <button className="btn btn-sm p-0 text-body-tertiary" title="Delete task"
                  onClick={(e) => { e.stopPropagation(); if (confirm('Delete this task?')) onDelete() }}>
            <i className="bi bi-x-lg small" />
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="session-card">
      <div className="fw-semibold text-wrap">
        <i className="bi bi-robot me-1 text-body-secondary" title="Automated task (pi session)" />
        {session.name || session.preview || session.pi_id.slice(0, 8)}
      </div>
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
