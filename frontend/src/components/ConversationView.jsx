import { useEffect, useMemo, useRef, useState } from 'react'
import { api } from '../api.js'
import { fmtDate } from '../fmt.js'

// Visual conversation navigator: renders the pi session tree as a chat
// thread. Branch points show chips to switch between alternatives; nodes on
// the session's active path get an accent border; an outline of user prompts
// enables jumping.

function buildTree(nodes) {
  const byId = new Map(nodes.map((n) => [n.id, n]))
  const children = new Map()
  for (const n of nodes) {
    const key = n.parent_id || '__root__'
    if (!children.has(key)) children.set(key, [])
    children.get(key).push(n)
  }
  for (const list of children.values()) list.sort((a, b) => (a.timestamp || '').localeCompare(b.timestamp || ''))
  return { byId, children }
}

// The displayed path: from root, at each branch point follow the selected
// child (defaults to the session's active child).
function computeVisiblePath(children, activeIds, overrides) {
  const path = []
  let cursor = children.get('__root__')?.[0]
  while (cursor) {
    path.push(cursor)
    const kids = children.get(cursor.id)
    if (!kids?.length) break
    let next = kids.find((k) => activeIds.has(k.id)) // default: session's active branch
    const override = overrides.get(cursor.id)
    if (override) next = kids.find((k) => k.id === override)
    if (!next) next = kids[0]
    cursor = next
  }
  return path
}

function Bubble({ node }) {
  const role = node.role
  if (role === 'event') {
    return (
      <div className="conv-event small text-body-secondary my-2">
        <i className="bi bi-arrow-repeat me-1" />{node.text}
      </div>
    )
  }

  const isUser = role === 'user'
  const isTool = role === 'toolResult'
  return (
    <div className={`conv-bubble conv-${role} ${node.active ? 'conv-active' : ''} ${isUser ? 'ms-auto' : ''}`}
         data-node-id={node.id}>
      <div className="conv-meta small text-body-secondary d-flex gap-2">
        <span className="fw-semibold">{isTool ? 'tool result' : role}</span>
        {node.model && <span>{node.model}</span>}
        <span className="ms-auto">{fmtDate(node.timestamp)}</span>
        {node.tokens > 0 && <span>{node.tokens.toLocaleString()} tok</span>}
        {node.cost > 0 && <span className="text-success">${node.cost.toFixed(4)}</span>}
      </div>
      {node.error && <div className="alert alert-danger py-1 px-2 my-1 small">{node.error}</div>}
      {node.text && <div className="conv-text small mt-1" style={{ whiteSpace: 'pre-wrap' }}>{node.text}</div>}
      {node.tool_calls?.map((tc, i) => (
        <details key={i} className="conv-tool small mt-1">
          <summary><i className="bi bi-terminal me-1" />{tc.name}</summary>
          <pre className="mb-0 p-2 text-body-secondary" style={{ fontSize: '.7rem', whiteSpace: 'pre-wrap' }}>{tc.arguments}</pre>
        </details>
      ))}
    </div>
  )
}

export default function ConversationView({ boardId, session }) {
  const [data, setData] = useState(null)
  const [error, setError] = useState(null)
  const [overrides, setOverrides] = useState(() => new Map())
  const [jumpId, setJumpId] = useState(null)
  const containerRef = useRef()

  useEffect(() => {
    let alive = true
    api.conversation(boardId, session.pi_id)
      .then((d) => { if (alive) setData(d) })
      .catch((e) => { if (alive) setError(e.message) })
    return () => { alive = false }
  }, [boardId, session.pi_id])

  // Scroll to the selected outline entry
  useEffect(() => {
    if (!jumpId || !data) return
    const el = containerRef.current?.querySelector(`[data-node-id="${jumpId}"]`)
    el?.scrollIntoView({ behavior: 'smooth', block: 'center' })
    el?.classList.add('conv-flash')
    setTimeout(() => el?.classList.remove('conv-flash'), 1200)
  }, [jumpId, data])

  const { children, activeIds } = useMemo(() => {
    if (!data) return { children: null, activeIds: null }
    const tree = buildTree(data.nodes)
    return { children: tree.children, activeIds: new Set(data.nodes.filter((n) => n.active).map((n) => n.id)) }
  }, [data])

  const visible = useMemo(
    () => (children ? computeVisiblePath(children, activeIds, overrides) : []),
    [children, activeIds, overrides])

  const userPrompts = useMemo(
    () => visible.filter((n) => n.role === 'user'),
    [visible])

  if (error) return <div className="alert alert-danger">{error}</div>
  if (!data) return <div className="d-flex justify-content-center py-4"><div className="spinner-border spinner-border-sm text-secondary" /></div>

  return (
    <div className="d-flex gap-3 conv-wrap" ref={containerRef}>
      {/* Outline: user prompts on the visible path */}
      <div className="conv-outline flex-shrink-0 border-end pe-2">
        <div className="small fw-semibold mb-2 text-body-secondary">Prompts ({userPrompts.length})</div>
        <ul className="list-unstyled mb-0">
          {userPrompts.map((n) => (
            <li key={n.id}>
              <button className="btn btn-sm btn-ghost-secondary text-start text-truncate d-block w-100 conv-outline-item"
                      onClick={() => setJumpId(n.id)}
                      title={n.text}>
                {n.text?.slice(0, 60) || '(empty prompt)'}
              </button>
            </li>
          ))}
        </ul>
      </div>

      {/* Thread */}
      <div className="conv-thread flex-grow-1">
        {visible.map((node) => {
          const kids = children.get(node.id)
          return (
            <div key={node.id}>
              <Bubble node={node} />
              {kids?.length > 1 && (
                <div className="conv-branches d-flex flex-wrap gap-1 my-2">
                  <span className="small text-body-secondary align-self-center">
                    <i className="bi bi-diagram-2 me-1" />Branch:
                  </span>
                  {kids.map((k) => (
                    <button key={k.id}
                            className={`btn btn-sm ${overrides.get(node.id) === k.id || (!overrides.has(node.id) && activeIds.has(k.id)) ? 'btn-primary' : 'btn-outline-secondary'} branch-chip`}
                            onClick={() => setOverrides(new Map(overrides).set(node.id, k.id))}>
                      {(k.text || k.role || 'node').slice(0, 40)}
                      {activeIds.has(k.id) && <i className="bi bi-check2 ms-1" title="session's active branch" />}
                    </button>
                  ))}
                </div>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}
