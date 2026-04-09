/* Core CSS required for Ionic components to work properly */
import '@ionic/react/css/core.css';

/* Basic CSS for apps built with Ionic */
import '@ionic/react/css/normalize.css';
import '@ionic/react/css/structure.css';
import '@ionic/react/css/typography.css';

/* Optional CSS utils that can be commented out */
import '@ionic/react/css/padding.css';
import '@ionic/react/css/float-elements.css';
import '@ionic/react/css/text-alignment.css';
import '@ionic/react/css/text-transformation.css';
import '@ionic/react/css/flex-utils.css';
import '@ionic/react/css/display.css';
import '@ionic/react/css/palettes/dark.system.css';

import { createRoot } from 'react-dom/client';
import { Provider } from 'react-redux';
import { I18nProvider } from '@lingui/react';
import { activateDetectedLocale, i18n } from '@/i18n';
import { createStore, setStoreInstance } from '@/store/index';
import { initializeClientId } from '@/utils/clientId';
import { syncJwtTokenToIdb } from '@/utils/jwtToken';
import { kvDelete, kvGet, kvSet } from '@/utils/db';
import { hydrateSettings, type SettingsState } from '@/store/settingsSlice';
import { hydrateStickerPreferences } from '@/store/stickerPreferencesSlice';
import { installBootstrapRecoveryHandlers } from '@/bootstrapRecovery';
import App from './App';
import { setupIonicReact } from '@ionic/react';

setupIonicReact({
  mode: 'ios',
  swipeBackEnabled: false,
});

console.log(`Running in ${import.meta.env.MODE} mode, dev=${import.meta.env.DEV}`);
installBootstrapRecoveryHandlers();

async function bootstrap() {
  // Load persisted state from IndexedDB
  const [savedSettings, savedStickerPackOrder, savedAutoSort] = await Promise.all([
    kvGet<Partial<SettingsState>>('settings'),
    kvGet<unknown>('stickerPackOrder'),
    kvGet<unknown>('autoSortStickerPacks'),
    initializeClientId(),
    syncJwtTokenToIdb(),
  ]);

  const settings = hydrateSettings(savedSettings);
  const hydratedStickerPreferences = hydrateStickerPreferences(savedStickerPackOrder, savedAutoSort);

  if (hydratedStickerPreferences.clearPackOrder) {
    await kvDelete('stickerPackOrder');
  } else if (hydratedStickerPreferences.persistPackOrder) {
    await kvSet('stickerPackOrder', hydratedStickerPreferences.state.packOrder);
  }

  if (hydratedStickerPreferences.clearAutoSort) {
    await kvDelete('autoSortStickerPacks');
  } else if (hydratedStickerPreferences.persistAutoSort) {
    await kvSet('autoSortStickerPacks', hydratedStickerPreferences.state.autoSortEnabled);
  }

  await activateDetectedLocale(settings.locale);

  const store = createStore(settings, hydratedStickerPreferences.state);
  setStoreInstance(store);

  createRoot(document.getElementById('root')!).render(
    <Provider store={store}>
      <I18nProvider i18n={i18n}>
        <App />
      </I18nProvider>
    </Provider>,
  );
}

void bootstrap();
