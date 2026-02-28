import path from 'path';
import react from '@vitejs/plugin-react';
import dotenv from 'dotenv';
import { defineConfig } from 'vite';

dotenv.config();

const SRC_DIR = path.resolve(__dirname, './src');

const API_PROXY_TARGET = process.env.API_PROXY_TARGET ?? 'http://localhost:3000';

console.log('API_PROXY_TARGET', API_PROXY_TARGET);

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
        target: API_PROXY_TARGET,
        ws: true,
        rewrite: (p) => p.replace(/^\/_api/, ''),
      },
      '^/_api/': {
        target: API_PROXY_TARGET,
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/_api/, ''),
      },
    },
  },
});
