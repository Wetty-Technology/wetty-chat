import type { LinguiConfig } from '@lingui/conf';
import { formatter } from '@lingui/format-po';

const config: LinguiConfig = {
  sourceLocale: 'en',
  locales: ['en', 'zh-CN', 'zh-TW'],
  catalogs: [
    {
      path: 'locales/{locale}/messages',
      include: ['src'],
    },
  ],
  format: formatter({
    lineNumbers: false,
  }),
};

export default config;
