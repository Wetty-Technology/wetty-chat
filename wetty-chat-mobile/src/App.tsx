import {
  IonApp,
  IonToast,
  setupIonicReact,
} from '@ionic/react';
import { IonReactRouter } from '@ionic/react-router';
import { Redirect, useLocation, useRouteMatch } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { useEffect } from 'react';
import type { AppDispatch, RootState } from '@/store/index';
import { fetchCurrentUser, setUser } from '@/store/userSlice';

import './app.scss';
import { Trans } from '@lingui/react/macro';
import { getCurrentUserId } from './js/current-user';
import { useRegisterSW } from 'virtual:pwa-register/react';
import { t } from '@lingui/core/macro';
import { syncApp } from '@/api/sync';
import MobileLayout from './layouts/MobileLayout';
import { useIsDesktop } from './hooks/useIsDesktop';
import { DesktopSplitLayout } from './layouts/DesktopSplitLayout';
import OobePage from '@/pages/oobe';
import LandingPage from './pages/landing';

setupIonicReact({
  mode: 'ios',
});

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

const App: React.FC = () => {
  const dispatch = useDispatch<AppDispatch>();
  const wsConnected = useSelector((state: RootState) => state.connection.wsConnected);
  const isDesktop = useIsDesktop();

  const {
    needRefresh: [needRefresh, setNeedRefresh],
    updateServiceWorker,
  } = useRegisterSW({
    onRegistered(r: any) {
      console.log('SW Registered: ', r);
    },
    onRegisterError(error: any) {
      console.log('SW registration error', error);
    },
  });

  useEffect(() => {
    if (import.meta.env.DEV) {
      dispatch(setUser({ uid: getCurrentUserId(), username: 'Development User', avatar_url: null }));
    }
    dispatch(fetchCurrentUser());
  }, [dispatch]);

  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        syncApp();
      }
    };
    const handleOnline = () => {
      syncApp();
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    window.addEventListener('online', handleOnline);

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      window.removeEventListener('online', handleOnline);
    };
  }, []);

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
            handler: () => updateServiceWorker(true)
          },
          {
            text: t`Dismiss`,
            role: 'cancel',
            handler: () => setNeedRefresh(false)
          }
        ]}
      />
      {!wsConnected && (
        <div className="ws-disconnected-banner" role="status" aria-live="polite">
          <Trans>Disconnected. Retrying…</Trans>
        </div>
      )}
      <div className="app-router-shell">
        <IonReactRouter basename={import.meta.env.BASE_URL}>
          <AppRouter isDesktop={isDesktop} />
        </IonReactRouter>
      </div>
    </IonApp>
  );
};

export default App;
