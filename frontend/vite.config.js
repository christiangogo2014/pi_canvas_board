import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5199,
    proxy: {
      '/api': { target: 'http://localhost:3049', changeOrigin: true },
      '/cable': { target: 'ws://localhost:3049', ws: true },
    },
  },
  build: { outDir: 'dist' },
})
