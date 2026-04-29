import path from 'path';
import { execSync } from 'child_process';
import react from '@vitejs/plugin-react';
import { lingui } from '@lingui/vite-plugin';
import { VitePWA } from 'vite-plugin-pwa';
import { defineConfig } from 'vite';
import { patchCssModules } from 'vite-css-modules';

const SRC_DIR = path.resolve(__dirname, './src');

type BaseConfigOptions = {
  assetBaseUrl?: string;
};

function getGitShortHash(): string | undefined {
  try {
    return execSync('git rev-parse --short HEAD').toString().trim() || undefined;
  } catch {
    return undefined;
  }
}

export function createBaseConfig(options: BaseConfigOptions = {}) {
  const assetBaseUrl = options.assetBaseUrl?.replace(/\/+$/, '');
  const resolvedAppVersion = process.env.CI_BUILD_VERSION?.trim() || getGitShortHash() || 'unknown';

  return defineConfig({
    define: {
      __API_BASE__: JSON.stringify('/_api'),
      __ASSET_BASE__: JSON.stringify(null),
      __APP_VERSION__: JSON.stringify(resolvedAppVersion),
      __AUTH_REDIRECT_URL__: JSON.stringify(null),
      __FEATURE_GATES_ENABLED__: JSON.stringify(false),
    },
    css: {
      modules: {
        localsConvention: 'camelCase',
      },
    },
    plugins: [
      patchCssModules({
        generateSourceTypes: true,
        declarationMap: true,
      }),
      react({
        babel: {
          plugins: ['@lingui/babel-plugin-lingui-macro'],
        },
      }),
      lingui(),
      VitePWA({
        strategies: 'injectManifest',
        srcDir: 'src',
        filename: 'serviceWorker.ts',
        registerType: 'prompt',
        // includeAssets: ['favicon.ico', 'apple-touch-icon.png', 'mask-icon.svg'],
        manifest: {
          name: '茶话',
          short_name: '茶话',
          description: '一边喝着茶，一边悠闲聊聊天吧。',
          theme_color: '#f7f7f7',
          background_color: '#f5f1e9',
          display: 'standalone',
          icons: [
            {
              src: '/icon/icon.svg',
              sizes: 'any',
              type: 'image/svg+xml',
              purpose: 'any',
            },
            {
              src: '/icon-maskable/icon.svg',
              sizes: 'any',
              type: 'image/svg+xml',
              purpose: 'maskable',
            },
            {
              src: '/icon/pwa-192x192.png',
              sizes: '192x192',
              type: 'image/png',
              purpose: 'any',
            },
            {
              src: '/icon/pwa-512x512.png',
              sizes: '512x512',
              type: 'image/png',
              purpose: 'any',
            },
            {
              src: '/icon-maskable/pwa-512x512.png',
              sizes: '512x512',
              type: 'image/png',
              purpose: 'maskable',
            },
          ],
        },
        injectManifest: {
          maximumFileSizeToCacheInBytes: 5000000,
          globPatterns: ['**/*.{js,css,html,ico,png,svg,woff2,wasm}'],
          ...(assetBaseUrl
            ? {
                modifyURLPrefix: {
                  'assets/': `${assetBaseUrl}/`,
                },
              }
            : {}),
        },
        devOptions: {
          enabled: true,
          type: 'module',
        },
      }),
    ],
    resolve: {
      alias: {
        '@': SRC_DIR,
      },
    },
  });
}

export default createBaseConfig();
