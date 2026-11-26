import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { Dropdown } from 'react-bootstrap'
import { DragDropContext, Droppable, Draggable } from '@hello-pangea/dnd'
import { api } from '../api.js'
import { subscribeToBoard } from '../cable.js'
import { CenteredSpinner } from './BoardsIndex.jsx'
import SessionCard from '../components/SessionCard.jsx'
import SessionModal from '../components/SessionModal.jsx'

export { fmtDate } from '../fmt.js'

export default function BoardPage() {
  const { id } = useParams()
  const [board, setBoard] = useState(null)
  const [error, setError] = useState(null)
  const [query, setQuery] = useState('')
  const [selected, setSelected] = useState(null)
  const debounceRef = useRef()

  const load = useCallback((q) => {
    api.board(id, q).then(setBoard).catch((e) => setError(e.message))
  }, [id])

  useEffect(() => { load() }, [load])

  // Live updates via ActionCable
  const projectDir = board?.project_dir
  useEffect(() => {
    if (!projectDir) return
    return subscribeToBoard(projectDir, () => load(query))
  }, [projectDir, load, query])

  // Debounced search
  useEffect(() => {
    clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => load(query), 300)
    return () => clearTimeout(debounceRef.current)
  }, [query, load])

  const columns = board?.columns || []

  const onDragEnd = useCallback(async (result) => {
    const { destination, draggableId, type } = result
    if (!destination) return

    if (type === 'COLUMN') {
      const from = columns.findIndex((c) => String(c.id) === draggableId)
      if (from === -1 || from === destination.index) return
      const next = [...columns]
      const [moved] = next.splice(from, 1)
      next.splice(destination.index, 0, moved)
      const reordered = next.map((c, i) => ({ ...c, position: i }))
      setBoard((prev) => ({ ...prev, columns: reordered })) // optimistic
      try {
        await Promise.all(reordered.map((c) => api.reorderColumn(id, c.id, c.position)))
      } catch (e) {
        setError(e.message)
        load(query)
      }
      return
    }

    const col = columns.find((c) => c.id === Number(destination.droppableId))
    if (!col) return
    // Optimistic local move
    setBoard((prev) => applyMove(prev, draggableId, col.id, destination.index))
    try {
      await api.moveCard(id, draggableId, col.id, destination.index)
    } catch (e) {
      setError(e.message)
      load(query)
    }
  }, [columns, id, load, query])

  const toggleSort = async (field) => {
    const dir = board.sort_field === field && board.sort_dir === 'desc' ? 'asc' : 'desc'
    setBoard({ ...board, sort_field: field, sort_dir: dir }) // optimistic
    try { await api.sortBoard(id, field, dir) } catch (e) { setError(e.message) }
  }

  if (error) return <div className="alert alert-danger m-4">{error}</div>
  if (!board) return <CenteredSpinner />

  return (
    <>
      <div className="board-header d-flex align-items-center flex-wrap gap-2 px-3 py-2 border-bottom">
        <Link to="/" className="btn btn-sm btn-ghost-secondary" title="All boards">
          <i className="bi bi-arrow-left" />
        </Link>
        <div className="me-auto">
          <span className="h5 mb-0 me-2">{board.name}</span>
          <span className="text-body-secondary small">{board.short_path}</span>
        </div>

        <div className="input-group input-group-sm" style={{ width: 240 }}>
          <span className="input-group-text bg-transparent"><i className="bi bi-search" /></span>
          <input className="form-control" placeholder="Search sessions…" value={query}
                 onChange={(e) => setQuery(e.target.value)} />
        </div>

        <Dropdown align="end">
          <Dropdown.Toggle size="sm" variant="outline-secondary" id="sort-dd">
            <i className="bi bi-sort-down me-1" />
            {board.sort_field === 'created_at_session' ? 'Created' : 'Updated'} {board.sort_dir === 'asc' ? '↑' : '↓'}
          </Dropdown.Toggle>
          <Dropdown.Menu>
            <Dropdown.Item active={board.sort_field === 'updated_at_session'} onClick={() => toggleSort('updated_at_session')}>
              Updated {board.sort_field === 'updated_at_session' && (board.sort_dir === 'asc' ? '↑' : '↓')}
            </Dropdown.Item>
            <Dropdown.Item active={board.sort_field === 'created_at_session'} onClick={() => toggleSort('created_at_session')}>
              Created {board.sort_field === 'created_at_session' && (board.sort_dir === 'asc' ? '↑' : '↓')}
            </Dropdown.Item>
          </Dropdown.Menu>
        </Dropdown>

        <button className="btn btn-sm btn-outline-secondary"
                onClick={async () => { await api.rescan().catch(alert); load(query) }}>
          <i className="bi bi-arrow-repeat" />
        </button>
      </div>

      <DragDropContext onDragEnd={onDragEnd}>
        <Droppable droppableId="board-columns" direction="horizontal" type="COLUMN">
          {(dropProv) => (
            <div className="kanban d-flex gap-3 p-3" ref={dropProv.innerRef} {...dropProv.droppableProps}>
              {columns.map((col, idx) => (
                <Draggable draggableId={String(col.id)} index={idx} key={col.id}>
                  {(prov) => (
                    <div ref={prov.innerRef} {...prov.draggableProps} className="flex-shrink-0">
                      <KanbanColumn
                        board={board}
                        column={col}
                        index={idx}
                        dragHandleProps={prov.dragHandleProps}
                        onCardClick={setSelected}
                        reload={() => load(query)}
                      />
                    </div>
                  )}
                </Draggable>
              ))}
              {dropProv.placeholder}
              <AddColumn board={board} onAdded={() => load(query)} />
            </div>
          )}
        </Droppable>
      </DragDropContext>

      <SessionModal session={selected} boardId={id} onClose={() => setSelected(null)} />
    </>
  )
}

// Pure helpers --------------------------------------------------------------

function applyMove(board, piId, columnId, index) {
  const columns = board.columns.map((c) => ({ ...c, cards: [...c.cards] }))
  const from = columns.find((c) => c.cards.some((s) => s.pi_id === piId))
  const to = columns.find((c) => c.id === columnId)
  if (!from || !to) return board
  const i = from.cards.findIndex((s) => s.pi_id === piId)
  const [card] = from.cards.splice(i, 1)
  to.cards.splice(index, 0, card)
  return { ...board, columns }
}

function KanbanColumn({ board, column, index, dragHandleProps, onCardClick, reload }) {
  return (
    <div className="kanban-column">
      <div className="d-flex align-items-center justify-content-between px-2 pb-1"
           {...(dragHandleProps || {})}>
        <span className="fw-semibold small">
          <i className="bi bi-grip-vertical me-1 text-body-tertiary" style={{ cursor: 'grab' }} />
          {column.title}
        </span>
        <div className="d-flex align-items-center gap-2">
          <span className="badge text-bg-secondary">{column.cards.length}</span>
          <ColumnMenu board={board} column={column} index={index} reload={reload} />
        </div>
      </div>
      <Droppable droppableId={String(column.id)}>
        {(provided, snapshot) => (
          <div
            ref={provided.innerRef}
            {...provided.droppableProps}
            className={`card-list rounded-3 p-2 ${snapshot.isDraggingOver ? 'drag-over' : ''}`}
          >
            {column.cards.map((s, i) => (
              <Draggable draggableId={s.pi_id} index={i} key={s.pi_id}>
                {(prov) => (
                  <div ref={prov.innerRef} {...prov.draggableProps} {...prov.dragHandleProps}
                       onClick={() => onCardClick(s)}>
                    <SessionCard session={s} />
                  </div>
                )}
              </Draggable>
            ))}
            {provided.placeholder}
          </div>
        )}
      </Droppable>
    </div>
  )
}

function ColumnMenu({ board, column, index, reload }) {
  const [renaming, setRenaming] = useState(false)
  const [title, setTitle] = useState(column.title)

  const move = async (delta) => {
    const order = [...board.columns].sort((a, b) => a.position - b.position)
    const target = order[index + delta]
    if (!target) return
    await Promise.all([
      api.reorderColumn(board.id, column.id, target.position),
      api.reorderColumn(board.id, target.id, column.position),
    ]).catch(alert)
    reload()
  }

  return (
    <Dropdown align="end">
      <Dropdown.Toggle size="sm" variant="ghost-secondary" className="p-0 px-1 border-0">
        <i className="bi bi-three-dots" />
      </Dropdown.Toggle>
      <Dropdown.Menu>
        {renaming ? (
          <form className="px-2 py-1" onSubmit={async (e) => {
            e.preventDefault()
            await api.renameColumn(board.id, column.id, title).catch(alert)
            setRenaming(false); reload()
          }}>
            <input className="form-control form-control-sm mb-1" value={title} autoFocus
                   onChange={(e) => setTitle(e.target.value)} />
            <button className="btn btn-sm btn-primary w-100">Rename</button>
          </form>
        ) : (
          <>
            <Dropdown.Item onClick={() => setRenaming(true)}><i className="bi bi-pencil me-2" />Rename</Dropdown.Item>
            <Dropdown.Item disabled={index === 0} onClick={() => move(-1)}><i className="bi bi-arrow-left me-2" />Move left</Dropdown.Item>
            <Dropdown.Item disabled={false} onClick={() => move(1)}><i className="bi bi-arrow-right me-2" />Move right</Dropdown.Item>
            <Dropdown.Divider />
            <Dropdown.Item className="text-danger" onClick={async () => {
              if (!confirm(`Delete column "${column.title}"? Cards return to the first column.`)) return
              await api.deleteColumn(board.id, column.id).catch(alert)
              reload()
            }}>
              <i className="bi bi-trash me-2" />Delete
            </Dropdown.Item>
          </>
        )}
      </Dropdown.Menu>
    </Dropdown>
  )
}

function AddColumn({ board, onAdded }) {
  const [adding, setAdding] = useState(false)
  const [title, setTitle] = useState('')

  if (!adding) {
    return (
      <button className="kanban-column add-column flex-shrink-0 btn" onClick={() => setAdding(true)}>
        <i className="bi bi-plus-lg me-1" />Add column
      </button>
    )
  }
  return (
    <div className="kanban-column flex-shrink-0 p-2">
      <form onSubmit={async (e) => {
        e.preventDefault()
        if (!title.trim()) return
        await api.addColumn(board.id, title.trim()).catch(alert)
        setTitle(''); setAdding(false); onAdded()
      }}>
        <input className="form-control form-control-sm mb-2" autoFocus placeholder="Column name…"
               value={title} onChange={(e) => setTitle(e.target.value)} />
        <div className="d-flex gap-2">
          <button className="btn btn-sm btn-primary">Add</button>
          <button type="button" className="btn btn-sm btn-outline-secondary" onClick={() => setAdding(false)}>Cancel</button>
        </div>
      </form>
    </div>
  )
}
