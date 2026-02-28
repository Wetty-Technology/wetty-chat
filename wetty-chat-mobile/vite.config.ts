import path from 'path';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

const SRC_DIR = path.resolve(__dirname, './src');

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': SRC_DIR,
    },
  },
  server: {
    host: true,
    proxy: {
      // WebSocket: must be more specific than /_api/ so it matches first
      '/_api/ws': {
        target: 'http://localhost:3000',
        ws: true,
        rewrite: (p) => p.replace(/^\/_api/, ''),
      },
      '^/_api/': {
        target: 'http://localhost:3000',
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/_api/, ''),
      },
    },
  },
});
