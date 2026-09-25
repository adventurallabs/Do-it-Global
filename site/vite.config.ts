import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { resolve } from 'node:path'

const root = import.meta.dirname

// Two static pages, two entry bundles. Cloudflare Pages serves
// /palli/ from palli/index.html with no server code involved.
export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: {
    target: 'es2022',
    cssCodeSplit: true,
    chunkSizeWarningLimit: 1200,
    rollupOptions: {
      input: {
        main: resolve(root, 'index.html'),
        palli: resolve(root, 'palli/index.html'),
      },
    },
  },
})
