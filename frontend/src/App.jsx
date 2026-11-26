import { Routes, Route } from 'react-router-dom'
import BoardsIndex from './pages/BoardsIndex.jsx'
import BoardPage from './pages/BoardPage.jsx'

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<BoardsIndex />} />
      <Route path="/boards/:id" element={<BoardPage />} />
    </Routes>
  )
}
