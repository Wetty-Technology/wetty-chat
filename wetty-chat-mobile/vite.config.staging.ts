import { defineConfig, mergeConfig } from 'vite';
import baseConfig from './vite.config.base';
import { execSync } from 'child_process';

let commitHash = 'unknown';
try {
  commitHash = execSync('git rev-parse --short HEAD').toString().trim();
} catch (e) {
  // Ignore
}

export default mergeConfig(baseConfig, defineConfig({
  define: {
    __APP_VERSION__: JSON.stringify(commitHash),
  },
}));
