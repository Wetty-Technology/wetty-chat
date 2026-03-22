import path from 'path';
import react from '@vitejs/plugin-react';
import { lingui } from '@lingui/vite-plugin';
import { VitePWA } from 'vite-plugin-pwa';
import { defineConfig } from 'vite';
import { patchCssModules } from 'vite-css-modules';

const SRC_DIR = path.resolve(__dirname, './src');

type BaseConfigOptions = {
  assetCdnOrigin?: string;
};

export function createBaseConfig(options: BaseConfigOptions = {}) {
  const assetCdnOrigin = options.assetCdnOrigin?.replace(/\/+$/, '');

  return defineConfig({
    define: {
      __API_BASE__: JSON.stringify(null),
      __AUTH_REDIRECT_URL__: JSON.stringify(null),
    },
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
          name: '茶话',
          short_name: '茶话',
          description: '一边喝茶一边聊天吧',
          theme_color: '#f7f7f7',
          background_color: '#fbf9e9',
          display: 'standalone',
          icons: [
            {
              src: 'pwa-192x192.png',
              sizes: '192x192',
              type: 'image/png',
            },
            {
              src: 'pwa-512x512.png',
              sizes: '512x512',
              type: 'image/png',
            },
            {
              src: 'maskable-icon-512x512.png',
              sizes: '512x512',
              type: 'image/png',
              purpose: 'maskable',
            }
          ]
        },
        injectManifest: {
          maximumFileSizeToCacheInBytes: 5000000,
          globPatterns: ['**/*.{js,css,html,ico,png,svg,woff2,wasm}'],
          ...(assetCdnOrigin ? {
            modifyURLPrefix: {
              'assets/': `${assetCdnOrigin}/assets/`,
            },
          } : {}),
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
}

export default createBaseConfig();
