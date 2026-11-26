import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api.js'

// Human label for a board card in the index grid.
function BoardTile({ board }) {
  return (
    <Link to={`/boards/${board.id}`} className="text-decoration-none">
      <div className="board-tile card h-100">
        <div className="card-body">
          <h5 className="card-title mb-1">{board.name}</h5>
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

  const load = () => api.boards().then(setBoards)
  useEffect(() => { load() }, [])

  if (!boards) return <CenteredSpinner />

  const filtered = boards.filter((b) =>
    b.name.toLowerCase().includes(query.toLowerCase()) ||
    b.project_path.toLowerCase().includes(query.toLowerCase()))

  return (
    <div className="container py-4">
      <header className="d-flex align-items-center justify-content-between mb-4">
        <div>
          <h1 className="h3 mb-0"><i className="bi bi-kanban me-2" />π Kanban Board</h1>
          <div className="text-body-secondary small">{boards.length} project boards</div>
        </div>
        <div className="d-flex gap-2">
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
          <div className="row row-cols-2 row-cols-md-3 row-cols-lg-4 g-3">
            {filtered.map((b) => (
              <div className="col" key={b.id}><BoardTile board={b} /></div>
            ))}
          </div>
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
