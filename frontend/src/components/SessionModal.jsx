import { useCallback, useEffect, useState } from 'react'
import { Modal, Button, Nav } from 'react-bootstrap'
import { api } from '../api.js'
import { fmtDate } from '../fmt.js'
import NotesTimeline from './NotesTimeline.jsx'
import ConversationView from './ConversationView.jsx'

// Session card modal: session metadata + notes timeline (description,
// comments, attachments) and the visual conversation navigator.
export default function SessionModal({ session, boardId, onClose }) {
  const [view, setView] = useState('details') // details | conversation
  const [notes, setNotes] = useState(null)

  const loadNotes = useCallback(() => {
    if (!session) return
    api.notes(boardId, session.pi_id).then(setNotes).catch(alert)
  }, [boardId, session?.pi_id])

  useEffect(() => {
    setView('details')
    setNotes(null)
    if (session) loadNotes()
  }, [session?.pi_id, loadNotes])

  return (
    <Modal show={!!session} onHide={onClose} size="xl" fullscreen="xl-down" centered
           dialogClassName="session-modal">
      <Modal.Header closeButton>
        <Modal.Title className="d-flex align-items-center gap-3 flex-wrap">
          <span>{session?.name || session?.preview?.slice(0, 50)}</span>
          <Nav variant="pills" defaultActiveKey="details" activeKey={view}
               onSelect={(k) => setView(k)}>
            <Nav.Item>
              <Nav.Link eventKey="details"><i className="bi bi-sticky me-1" />Details</Nav.Link>
            </Nav.Item>
            <Nav.Item>
              <Nav.Link eventKey="conversation"><i className="bi bi-chat-square-text me-1" />Conversation</Nav.Link>
            </Nav.Item>
          </Nav>
        </Modal.Title>
      </Modal.Header>

      <Modal.Body>
        {session && view === 'details' && (
          <>
            <div className="d-flex flex-wrap gap-2 mb-3 small">
              <span className="badge text-bg-dark-subtle">{session.model || '—'}</span>
              <span className="badge text-bg-secondary-subtle" title="session id">
                <i className="bi bi-fingerprint me-1" />{session.pi_id.slice(0, 8)}
              </span>
              <span className="badge text-bg-secondary-subtle">
                <i className="bi bi-clock me-1" />updated {fmtDate(session.updated_at_session)}
              </span>
              <span className="badge text-bg-secondary-subtle">
                <i className="bi bi-coin me-1" />${session.cost?.toFixed(4)}
              </span>
              <Button size="sm" variant="outline-primary" className="ms-auto"
                      onClick={() => navigator.clipboard.writeText(`pi --session ${session.pi_id}`)}>
                <i className="bi bi-clipboard me-1" />Copy resume command
              </Button>
            </div>
            {session.preview && <p className="text-body-secondary small">{session.preview}</p>}
            {notes ? (
              <NotesTimeline boardId={boardId} session={session} notes={notes.notes} reload={loadNotes} />
            ) : (
              <div className="d-flex justify-content-center py-4"><div className="spinner-border spinner-border-sm text-secondary" /></div>
            )}
          </>
        )}

        {session && view === 'conversation' && (
          <ConversationView boardId={boardId} session={session} />
        )}
      </Modal.Body>
    </Modal>
  )
}
