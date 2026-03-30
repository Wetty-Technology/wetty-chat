import { IonApp, IonToast } from '@ionic/react';
import { IonReactRouter } from '@ionic/react-router';
import { Redirect, useRouteMatch } from 'react-router-dom';
import { useDispatch } from 'react-redux';
import { useEffect } from 'react';
import type { AppDispatch } from '@/store/index';
import { fetchCurrentUser, setUser } from '@/store/userSlice';

import './app.scss';
import { getCurrentUserId } from './js/current-user';
import { t } from '@lingui/core/macro';
import MobileLayout from './layouts/MobileLayout';
import { AppUpdateProvider } from './hooks/AppUpdateProvider';
import { useIsDesktop } from './hooks/platformHooks';
import { useAppLifecycle } from './hooks/useAppLifecycle';
import { useAppUpdate } from './hooks/useAppUpdate';
import { usePushNotificationBootstrap } from './hooks/usePushNotifications';
import { DesktopSplitLayout } from './layouts/DesktopSplitLayout';
import OobePage from '@/pages/oobe';
import LandingPage from './pages/landing';
import { initWebSocket } from '@/api/ws';
import { syncStoredJwtToken } from '@/utils/jwtToken';
import { useDeviceToken } from './hooks/useDeviceToken';
import { appHistory } from '@/utils/navigationHistory';

const OOBE_STORAGE_KEY = 'oobe';

function hasCompletedOobe() {
  return localStorage.getItem(OOBE_STORAGE_KEY) !== null;
}

function AppRouter({ isDesktop }: { isDesktop: boolean }) {
  const isOobeRoute = useRouteMatch('/oobe');
  const isLandingRoute = useRouteMatch('/landing');

  if (isLandingRoute?.isExact) {
    return <LandingPage />;
  } else if (isOobeRoute?.isExact) {
    return <OobePage />;
  } else if (!hasCompletedOobe()) {
    return <Redirect to="/oobe" />;
  }

  return isDesktop ? <DesktopSplitLayout /> : <MobileLayout />;
}

function AppShell() {
  const dispatch = useDispatch<AppDispatch>();
  const isDesktop = useIsDesktop();
  const token = useDeviceToken(true);
  useAppLifecycle();
  usePushNotificationBootstrap();
  const { needRefresh, setNeedRefresh, updateServiceWorker } = useAppUpdate();
  const missingProdToken = import.meta.env.PROD && (!token || token.length === 0);

  useEffect(() => {
    syncStoredJwtToken();
    initWebSocket();
    if (import.meta.env.DEV) {
      dispatch(setUser({ uid: getCurrentUserId(), username: 'Development User', avatarUrl: null }));
    }
    dispatch(fetchCurrentUser());
  }, [dispatch]);

  if (missingProdToken) {
    return <h1>I'm a tea pot</h1>;
  }

  return (
    <IonApp>
      <IonToast
        isOpen={needRefresh}
        message={t`A new version of the app is available!`}
        position="bottom"
        duration={0}
        buttons={[
          {
            text: t`Update Now`,
            role: 'info',
            handler: () => updateServiceWorker(true),
          },
          {
            text: t`Dismiss`,
            role: 'cancel',
            handler: () => setNeedRefresh(false),
          },
        ]}
      />
      <div className="app-router-shell">
        <IonReactRouter history={appHistory}>
          <AppRouter isDesktop={isDesktop} />
        </IonReactRouter>
      </div>
    </IonApp>
  );
}

const App: React.FC = () => {
  return (
    <AppUpdateProvider>
      <AppShell />
    </AppUpdateProvider>
  );
};

export default App;
