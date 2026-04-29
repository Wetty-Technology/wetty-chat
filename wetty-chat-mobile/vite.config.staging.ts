import { defineConfig, mergeConfig } from 'vite';
import baseConfig from './vite.config.base';

export default mergeConfig(
  baseConfig,
  defineConfig({
    define: {
      __FEATURE_GATES_ENABLED__: JSON.stringify(true),
    },
  }),
);
