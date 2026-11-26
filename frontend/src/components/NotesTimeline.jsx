import { useRef, useState } from 'react'
import { api } from '../api.js'
import { fmtDate } from '../fmt.js'

const kindIcon = { description: 'bi-file-earmark-text', comment: 'bi-chat-left-text', attachment: 'bi-paperclip' }

// One-per-session description, editable in place.
function Description({ notes, boardId, piId, reload }) {
  const note = notes.find((n) => n.kind === 'description')
  const [editing, setEditing] = useState(false)
  const [body, setBody] = useState('')

  const start = () => { setBody(note?.body || ''); setEditing(true) }
  const save = async () => {
    if (note) await api.editNote(note.id, body)
    else await api.addNote(boardId, piId, 'description', body)
    setEditing(false); reload()
  }

  return (
    <div className="mb-3">
      <div className="d-flex justify-content-between align-items-center mb-1">
        <span className="small fw-semibold"><i className="bi bi-file-earmark-text me-1" />Description</span>
        {!editing && (
          <button className="btn btn-sm btn-ghost-secondary p-0 px-1" onClick={start}>
            <i className="bi bi-pencil" /> {note ? 'Edit' : 'Add'}
          </button>
        )}
      </div>
      {editing ? (
        <form onSubmit={(e) => { e.preventDefault(); save() }}>
          <textarea className="form-control form-control-sm mb-2" rows={4} value={body}
                    onChange={(e) => setBody(e.target.value)} autoFocus
                    placeholder="What was this session about? Key decisions, outcome…" />
          <div className="d-flex gap-2">
            <button className="btn btn-sm btn-primary">Save</button>
            <button type="button" className="btn btn-sm btn-outline-secondary" onClick={() => setEditing(false)}>Cancel</button>
          </div>
        </form>
      ) : note ? (
        <div className="small" style={{ whiteSpace: 'pre-wrap' }}>{note.body}</div>
      ) : (
        <div className="small text-body-secondary fst-italic">No description yet — capture the conclusion here.</div>
      )}
    </div>
  )
}

// Add-comment form + attachments upload.
function AddRow({ boardId, piId, reload }) {
  const [body, setBody] = useState('')
  const fileRef = useRef()

  return (
    <div className="mt-3">
      <form onSubmit={async (e) => {
        e.preventDefault()
        if (!body.trim()) return
        await api.addNote(boardId, piId, 'comment', body.trim()).catch(alert)
        setBody(''); reload()
      }}>
        <textarea className="form-control form-control-sm mb-2" rows={2} value={body}
                  onChange={(e) => setBody(e.target.value)}
                  placeholder="Add a comment or decision to the timeline…" />
        <div className="d-flex gap-2">
          <button className="btn btn-sm btn-primary"><i className="bi bi-chat-left-text me-1" />Comment</button>
          <button type="button" className="btn btn-sm btn-outline-secondary"
                  onClick={() => fileRef.current?.click()}>
            <i className="bi bi-paperclip me-1" />Attach
          </button>
          <input ref={fileRef} type="file" hidden onChange={async (e) => {
            const f = e.target.files?.[0]
            if (!f) return
            await api.uploadNote(boardId, piId, f).catch(alert)
            e.target.value = ''
            reload()
          }} />
        </div>
      </form>
    </div>
  )
}

// Vertical timeline of all notes (description, comments, attachments).
export default function NotesTimeline({ boardId, session, notes, reload }) {
  const timeline = notes.filter((n) => n.kind !== 'description')
  const piId = session.pi_id

  return (
    <>
      <Description notes={notes} boardId={boardId} piId={piId} reload={reload} />
      <div className="mb-2 small fw-semibold"><i className="bi bi-clock-history me-1" />Timeline</div>
      {timeline.length === 0 && (
        <div className="small text-body-secondary fst-italic mb-2">No comments or attachments yet.</div>
      )}
      <ol className="notes-timeline list-unstyled">
        {timeline.map((n) => (
          <li key={n.id} className="note-item">
            <div className="note-icon"><i className={`bi ${kindIcon[n.kind] || 'bi-dot'}`} /></div>
            <div className="flex-grow-1">
              {n.kind === 'attachment' ? (
                <a href={n.attachment_url} download className="small">
                  <i className="bi bi-download me-1" />{n.attachment_filename}
                </a>
              ) : (
                <div className="small text-wrap" style={{ whiteSpace: 'pre-wrap' }}>{n.body}</div>
              )}
              <div className="d-flex align-items-center gap-2 mt-1">
                <span className="text-body-secondary" style={{ fontSize: '.7rem' }}>{fmtDate(n.created_at)}</span>
                <button className="btn btn-sm btn-ghost-secondary p-0 px-1"
                        onClick={async () => {
                          const next = prompt('Edit note', n.body)
                          if (next == null || next === n.body) return
                          await api.editNote(n.id, next).catch(alert); reload()
                        }}>
                  <i className="bi bi-pencil" style={{ fontSize: '.7rem' }} />
                </button>
                <button className="btn btn-sm btn-ghost-danger p-0 px-1"
                        onClick={async () => {
                          if (!confirm('Delete this note?')) return
                          await api.deleteNote(n.id).catch(alert); reload()
                        }}>
                  <i className="bi bi-trash" style={{ fontSize: '.7rem' }} />
                </button>
              </div>
            </div>
          </li>
        ))}
      </ol>
      <AddRow boardId={boardId} piId={piId} reload={reload} />
    </>
  )
}
