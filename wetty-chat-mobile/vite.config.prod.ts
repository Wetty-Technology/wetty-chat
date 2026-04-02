import { defineConfig, mergeConfig } from 'vite';
import { createBaseConfig } from './vite.config.base';
import { execSync } from 'child_process';

const ASSET_URL = 'https://chahui.app';
const API_BASE_URL = `${ASSET_URL}/_api`;

let commitHash = 'unknown';
try {
  commitHash = execSync('git rev-parse --short HEAD').toString().trim();
} catch {
  // Ignore
}

export default mergeConfig(
  createBaseConfig({ assetCdnOrigin: ASSET_URL }),
  defineConfig({
    experimental: {
      renderBuiltUrl(filename, { type }) {
        if (type === 'public') {
          return `/${filename}`;
        }

        return `${ASSET_URL}/${filename}`;
      },
    },
    define: {
      __ASSET_BASE__: JSON.stringify(ASSET_URL),
      __API_BASE__: JSON.stringify(API_BASE_URL),
      __APP_VERSION__: JSON.stringify(commitHash),
      __FEATURE_GATES_ENABLED__: JSON.stringify(false),
    },
  }),
);
