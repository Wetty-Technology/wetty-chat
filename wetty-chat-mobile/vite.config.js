import path from 'path';
import react from '@vitejs/plugin-react';

const SRC_DIR = path.resolve(__dirname, './src');
const PUBLIC_DIR = path.resolve(__dirname, './public');
const BUILD_DIR = path.resolve(__dirname, './www');
export default async () => {
  return {
    plugins: [
      react(),
    ],
    root: SRC_DIR,
    base: '',
    publicDir: PUBLIC_DIR,
    build: {
      outDir: BUILD_DIR,
      assetsInlineLimit: 0,
      emptyOutDir: true,
      rollupOptions: {
        treeshake: false,
      },
    },
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
          rewrite: (path) => path.replace(/^\/_api/, ''),
        },
        '^/_api/': {
          target: 'http://localhost:3000',
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/_api/, ''),
        },
      },
    },

  };
}
