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

import { createRoot } from 'react-dom/client';
import { Provider } from 'react-redux';
import { I18nProvider } from '@lingui/react';
import { i18n, activateDetectedLocale } from '@/i18n';
import store from '@/store/index';
import App from './App';
import { initWebSocket } from '@/api/ws';

initWebSocket();
activateDetectedLocale();

createRoot(document.getElementById('root')!).render(
  <Provider store={store}>
    <I18nProvider i18n={i18n}>
      <App />
    </I18nProvider>
  </Provider>
);
