import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Form } from 'react-bootstrap'
import { DragDropContext, Droppable, Draggable } from '@hello-pangea/dnd'
import { api } from '../api.js'

// Board tile: link + separate drag handle (so clicks still navigate).
function BoardTile({ board, dragHandleProps }) {
  return (
    <Link to={`/boards/${board.id}`} className="text-decoration-none">
      <div className={`board-tile card h-100 ${board.archived ? 'archived' : ''}`}>
        <div className="card-body">
          <span className="board-tile-grip text-body-tertiary" title="Drag to reorder"
                {...(dragHandleProps || {})}>
            <i className="bi bi-grip-vertical" />
          </span>
          <h5 className="card-title mb-1">
            {board.name}
            {board.archived && <span className="badge text-bg-secondary ms-2">Archived</span>}
          </h5>
          <div className="text-body-secondary small">
            <i className="bi bi-folder2-open me-1" />
            {board.short_path}
          </div>
        </div>
      </div>
    </Link>
  )
}

export default function BoardsIndex() {
  const [boards, setBoards] = useState(null)
  const [busy, setBusy] = useState(false)
  const [query, setQuery] = useState('')
  const [showArchived, setShowArchived] = useState(false)

  const load = () => api.boards().then(setBoards)
  useEffect(() => { load() }, [])

  const onDragEnd = async (result) => {
    if (!result.destination || !boards) return
    const list = filtered
    const dragged = list[result.source.index]
    const target = list[result.destination.index]
    if (!dragged || !target || dragged.id === target.id) return
    // Reorder the full list by id (works even while a filter is active)
    const next = boards.filter((b) => b.id !== dragged.id)
    next.splice(boards.findIndex((b) => b.id === target.id), 0, dragged)
    const reordered = next.map((b, i) => ({ ...b, position: i }))
    setBoards(reordered) // optimistic
    try {
      await api.reorderBoards(reordered.map((b) => b.id))
    } catch (e) {
      alert(e.message)
      load()
    }
  }

  if (!boards) return <CenteredSpinner />

  const filtered = boards.filter((b) =>
    (showArchived || !b.archived) &&
    (b.name.toLowerCase().includes(query.toLowerCase()) ||
     b.project_path.toLowerCase().includes(query.toLowerCase())))

  return (
    <div className="container py-4">
      <header className="d-flex align-items-center justify-content-between mb-4">
        <div>
          <h1 className="h3 mb-0"><i className="bi bi-kanban me-2" />π Kanban Board</h1>
          <div className="text-body-secondary small">
            {filtered.length} project board{filtered.length === 1 ? '' : 's'}
          </div>
        </div>
        <div className="d-flex gap-2 align-items-center">
          <Form.Check type="switch" id="show-archived" label="Show archived"
                      checked={showArchived}
                      onChange={(e) => setShowArchived(e.target.checked)} />
          <input
            className="form-control form-control-sm"
            style={{ width: 220 }}
            placeholder="Filter boards…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          <button className="btn btn-sm btn-outline-secondary" disabled={busy}
                  onClick={async () => { setBusy(true); await api.rescan().catch(alert); await load(); setBusy(false) }}>
            <i className="bi bi-arrow-repeat me-1" />Rescan
          </button>
        </div>
      </header>

      {filtered.length === 0
        ? <p className="text-body-secondary">No boards match.</p>
        : (
          <DragDropContext onDragEnd={onDragEnd}>
            <Droppable droppableId="board-grid" direction="horizontal">
              {(dropProv) => (
                <div className="board-grid" ref={dropProv.innerRef} {...dropProv.droppableProps}>
                  {filtered.map((b, idx) => (
                    <Draggable draggableId={String(b.id)} index={idx} key={b.id}>
                      {(prov) => (
                        <div ref={prov.innerRef} {...prov.draggableProps} className="board-grid-item">
                          <BoardTile board={b} dragHandleProps={prov.dragHandleProps} />
                          {prov.placeholder}
                        </div>
                      )}
                    </Draggable>
                  ))}
                  {dropProv.placeholder}
                </div>
              )}
            </Droppable>
          </DragDropContext>
        )}
    </div>
  )
}

export function CenteredSpinner() {
  return (
    <div className="d-flex justify-content-center py-5">
      <div className="spinner-border text-secondary" role="status" />
    </div>
  )
}
