import {
  IonApp,
  IonRouterOutlet,
  IonTabs,
  IonTabBar,
  IonTabButton,
  IonIcon,
  IonLabel,
  IonToast,
  setupIonicReact,
} from '@ionic/react';
import { IonReactRouter } from '@ionic/react-router';
import { Route, Redirect, useLocation } from 'react-router-dom';
import { chatbubbles, settings, flask } from 'ionicons/icons';
import { useSelector, useDispatch } from 'react-redux';
import { useEffect, useMemo } from 'react';
import type { RootState, AppDispatch } from '@/store/index';
import { fetchCurrentUser, setUser } from '@/store/userSlice';

import ChatsPage from '@/pages/chats';
import CreateChatPage from '@/pages/create-chat';
import ChatThreadPage from '@/pages/chat-thread';
import ChatSettingsPage from '@/pages/chat-settings';
import ChatMembersPage from '@/pages/chat-members';
import SettingsPage from '@/pages/settings';
import LanguagePage from '@/pages/settings/language';
import GroupDetailPage from '@/pages/group-detail';
import NotFoundPage from '@/pages/not-found';
import ComponentDemoPage from '@/pages/component-demo';

import './app.scss';
import { Trans } from '@lingui/react/macro';
import { getCurrentUserId } from './js/current-user';
import { useRegisterSW } from 'virtual:pwa-register/react';
import { t } from '@lingui/core/macro';
import { syncApp } from '@/api/sync';

setupIonicReact();

const TAB_ROOT_PATHS = ['/', '/chats', '/settings', '/demo'];

const TabsContainer: React.FC = () => {
  const location = useLocation();
  const isTabRoot = TAB_ROOT_PATHS.includes(location.pathname);

  const tabBarButtons = useMemo(() => {
    const buttons = [
      (
        <IonTabButton tab="chats" href="/chats" key="chats">
          <IonIcon icon={chatbubbles} />
          <IonLabel><Trans>Chats</Trans></IonLabel>
        </IonTabButton>
      ),
      (
        <IonTabButton tab="settings" href="/settings" key="settings">
          <IonIcon icon={settings} />
          <IonLabel><Trans>Settings</Trans></IonLabel>
        </IonTabButton>
      ),
    ];

    if (import.meta.env.DEV) {
      buttons.push(
        <IonTabButton tab="demo" href="/demo" key="demo">
          <IonIcon icon={flask} />
          <IonLabel>Demo</IonLabel>
        </IonTabButton>
      );
    }

    return buttons;
  }, []);

  return (
    <IonTabs className={isTabRoot ? '' : 'tab-bar-hidden'}>
      <IonRouterOutlet>
        <Route path="/chats" exact component={ChatsPage} />
        <Route path="/chats/new" exact component={CreateChatPage} />
        <Route path="/chats/chat/:id" exact component={ChatThreadPage} />
        <Route path="/chats/chat/:id/thread/:threadId" exact component={ChatThreadPage} />
        <Route path="/chats/chat/:id/settings" exact component={ChatSettingsPage} />
        <Route path="/chats/chat/:id/members" exact component={ChatMembersPage} />
        <Route path="/chats/chat/:id/details" exact component={GroupDetailPage} />
        <Route path="/demo" exact component={ComponentDemoPage} />
        <Route path="/settings/language" exact component={LanguagePage} />
        <Route path="/settings" exact component={SettingsPage} />
        <Redirect exact from="/" to="/chats" />
        <Route component={NotFoundPage} />
      </IonRouterOutlet>
      <IonTabBar slot="bottom" style={isTabRoot ? undefined : { display: 'none' }}>
        {tabBarButtons}
      </IonTabBar>
    </IonTabs>
  );
};

const App: React.FC = () => {
  const dispatch = useDispatch<AppDispatch>();
  const wsConnected = useSelector((state: RootState) => state.connection.wsConnected);

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
        <div className="ws-disconnected-banner">
          <Trans>Disconnected. Retrying…</Trans>
        </div>
      )}
      <IonReactRouter basename={import.meta.env.BASE_URL}>
        <TabsContainer />
      </IonReactRouter>
    </IonApp>
  );
};

export default App;
