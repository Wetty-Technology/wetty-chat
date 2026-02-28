import {
  IonApp,
  IonRouterOutlet,
  IonTabs,
  IonTabBar,
  IonTabButton,
  IonIcon,
  IonLabel,
  setupIonicReact,
} from '@ionic/react';
import { IonReactRouter } from '@ionic/react-router';
import { Route, Redirect, Switch } from 'react-router-dom';
import { chatbubbles, settings } from 'ionicons/icons';
import { useSelector } from 'react-redux';
import type { RootState } from '@/store/index';

import ChatsPage from '@/pages/chats';
import CreateChatPage from '@/pages/create-chat';
import ChatThreadPage from '@/pages/chat-thread';
import ChatSettingsPage from '@/pages/chat-settings';
import ChatMembersPage from '@/pages/chat-members';
import SettingsPage from '@/pages/settings';
import GroupDetailPage from '@/pages/group-detail';
import NotFoundPage from '@/pages/not-found';

import './app.scss';

setupIonicReact();

const App: React.FC = () => {
  const wsConnected = useSelector((state: RootState) => state.connection.wsConnected);

  return (
    <IonApp>
      {!wsConnected && (
        <div className="ws-disconnected-banner">
          Disconnected. Retrying…
        </div>
      )}
      <IonReactRouter>
        <IonTabs>
          <IonRouterOutlet>
            <Route path="/chats" exact component={ChatsPage} />
            <Route path="/chats/new" exact component={CreateChatPage} />
            <Route path="/chats/chat/:id" exact component={ChatThreadPage} />
            <Route path="/chats/settings/:id" exact component={ChatSettingsPage} />
            <Route path="/chats/members/:id" exact component={ChatMembersPage} />
            <Route path="/chats/detail/:id" exact component={GroupDetailPage} />
            <Route path="/settings" exact component={SettingsPage} />
            <Redirect exact from="/" to="/chats" />
            <Route component={NotFoundPage} />
          </IonRouterOutlet>
          <IonTabBar slot="bottom">
            <IonTabButton tab="chats" href="/chats">
              <IonIcon icon={chatbubbles} />
              <IonLabel>Chats</IonLabel>
            </IonTabButton>
            <IonTabButton tab="settings" href="/settings">
              <IonIcon icon={settings} />
              <IonLabel>Settings</IonLabel>
            </IonTabButton>
          </IonTabBar>
        </IonTabs>
      </IonReactRouter>
    </IonApp>
  );
};

export default App;
