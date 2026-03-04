import path from 'path';
import react from '@vitejs/plugin-react';
import { lingui } from '@lingui/vite-plugin';
import { VitePWA } from 'vite-plugin-pwa';
import dotenv from 'dotenv';
import { defineConfig } from 'vite';

dotenv.config();

const SRC_DIR = path.resolve(__dirname, './src');

const API_PROXY_TARGET = process.env.API_PROXY_TARGET ?? 'http://localhost:3000';

console.log('API_PROXY_TARGET', API_PROXY_TARGET);

export default defineConfig({
  plugins: [
    react({
      babel: {
        plugins: ["@lingui/babel-plugin-lingui-macro"],
      },
    }),
    lingui(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.ico', 'apple-touch-icon.png', 'mask-icon.svg'],
      manifest: {
        name: 'Wetty Chat',
        short_name: 'W Chat',
        description: 'Wetty Chat',
        start_url: 'https://wchat.i386.mov',
        theme_color: '#ffffff',
        background_color: '#ffffff',
        display: 'standalone',
        icons: [
          {
            src: 'appicon/icon-192.png',
            sizes: '192x192',
            type: 'image/png'
          },
          {
            src: 'appicon/icon-512.png',
            sizes: '512x512',
            type: 'image/png'
          }
        ]
      },
      workbox: {
        navigateFallbackDenylist: [/^\/_api/],
      }
    })
  ],
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
