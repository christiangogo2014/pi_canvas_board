// Thin fetch wrapper for the Rails JSON API.

async function request(path, options = {}) {
  const res = await fetch(path, {
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options,
  })
  if (!res.ok) {
    const body = await res.text().catch(() => '')
    throw new Error(`${options.method || 'GET'} ${path} → ${res.status} ${body}`)
  }
  const ct = res.headers.get('content-type') || ''
  return ct.includes('json') ? res.json() : res
}

export const api = {
  boards: () => request('/api/boards'),
  board: (id, q) => request(`/api/boards/${id}${q ? `?q=${encodeURIComponent(q)}` : ''}`),
  rescan: () => request('/api/rescan', { method: 'POST' }),
  reorderBoards: (order) =>
    request('/api/boards/reorder', { method: 'PATCH', body: JSON.stringify({ order }) }),

  sortBoard: (id, sort_field, sort_dir) =>
    request(`/api/boards/${id}/sort`, { method: 'PATCH', body: JSON.stringify({ sort_field, sort_dir }) }),
  updateBoard: (id, attrs) =>
    request(`/api/boards/${id}`, { method: 'PATCH', body: JSON.stringify({ board: attrs }) }),

  addColumn: (boardId, title) =>
    request(`/api/boards/${boardId}/columns`, { method: 'POST', body: JSON.stringify({ title }) }),
  renameColumn: (boardId, columnId, title) =>
    request(`/api/boards/${boardId}/columns/${columnId}`, { method: 'PATCH', body: JSON.stringify({ title }) }),
  deleteColumn: (boardId, columnId) =>
    request(`/api/boards/${boardId}/columns/${columnId}`, { method: 'DELETE' }),
  reorderColumn: (boardId, columnId, position) =>
    request(`/api/boards/${boardId}/columns/${columnId}/reorder`, { method: 'PATCH', body: JSON.stringify({ position }) }),

  moveCard: (boardId, piId, columnId, position) =>
    request(`/api/boards/${boardId}/sessions/${piId}/move`, {
      method: 'PATCH',
      body: JSON.stringify({ column_id: columnId, position }),
    }),

  // Manual task cards (no pi session behind them)
  addTask: (boardId, columnId, title) =>
    request(`/api/boards/${boardId}/tasks`, { method: 'POST', body: JSON.stringify({ column_id: columnId, title }) }),
  editTask: (taskId, title) =>
    request(`/api/tasks/${taskId}`, { method: 'PATCH', body: JSON.stringify({ title }) }),
  deleteTask: (taskId) =>
    request(`/api/tasks/${taskId}`, { method: 'DELETE' }),

  // Notes timeline (description / comments / attachments)
  notes: (boardId, piId) => request(`/api/boards/${boardId}/sessions/${piId}/notes`),
  addNote: (boardId, piId, kind, body) =>
    request(`/api/boards/${boardId}/sessions/${piId}/notes`, {
      method: 'POST', body: JSON.stringify({ kind, body }),
    }),
  uploadNote: (boardId, piId, file) => {
    const fd = new FormData()
    fd.append('file', file)
    return fetch(`/api/boards/${boardId}/sessions/${piId}/notes`, { method: 'POST', body: fd })
      .then(check)
  },
  editNote: (noteId, body) =>
    request(`/api/notes/${noteId}`, { method: 'PATCH', body: JSON.stringify({ body }) }),
  deleteNote: (noteId) => request(`/api/notes/${noteId}`, { method: 'DELETE' }),

  // Visual conversation navigator
  conversation: (boardId, piId) =>
    request(`/api/boards/${boardId}/sessions/${piId}/conversation`),
}

async function check(res) {
  if (!res.ok) throw new Error(`${res.status} ${await res.text().catch(() => '')}`)
  const ct = res.headers.get('content-type') || ''
  return ct.includes('json') ? res.json() : res
}
