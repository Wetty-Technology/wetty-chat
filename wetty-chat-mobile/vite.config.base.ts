import path from 'path';
import react from '@vitejs/plugin-react';
import { lingui } from '@lingui/vite-plugin';
import { VitePWA } from 'vite-plugin-pwa';
import { defineConfig } from 'vite';
import { patchCssModules } from 'vite-css-modules';

const SRC_DIR = path.resolve(__dirname, './src');

export default defineConfig({
  css: {
    modules: {
      localsConvention: "camelCase",
    }
  },
  plugins: [
    patchCssModules({
      generateSourceTypes: true,
      declarationMap: true,
    }),
    react({
      babel: {
        plugins: ["@lingui/babel-plugin-lingui-macro"],
      },
    }),
    lingui(),
    VitePWA({
      strategies: 'injectManifest',
      srcDir: 'src',
      filename: 'serviceWorker.ts',
      registerType: 'prompt',
      includeAssets: ['favicon.ico', 'apple-touch-icon.png', 'mask-icon.svg'],
      manifest: {
        name: 'Wetty Chat',
        short_name: 'W Chat',
        description: 'Wetty Chat',
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
      injectManifest: {
        maximumFileSizeToCacheInBytes: 5000000,
        globPatterns: ['**/*.{js,css,html,ico,png,svg,woff2,wasm}'],
      },
      devOptions: {
        enabled: true,
        type: 'module',
      }
    })
  ],
  resolve: {
    alias: {
      '@': SRC_DIR,
    },
  },
});
