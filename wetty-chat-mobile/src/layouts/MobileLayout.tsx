import { IonTabButton, IonIcon, IonLabel, IonTabs, IonRouterOutlet, IonTabBar } from "@ionic/react";
import { Trans } from "@lingui/react/macro";
import { chatbubbles, settings, flask } from "ionicons/icons";
import { useMemo } from "react";
import { Redirect, Route, useLocation } from "react-router-dom";

import ChatsPage from '@/pages/chats';
import { CreateChatPage } from '@/pages/create-chat';
import { ChatThreadPage } from '@/pages/chat-thread';
import { ChatSettingsPage } from '@/pages/chat-settings';
import { ChatMembersPage } from '@/pages/chat-members';
import SettingsPage from '@/pages/settings';
import LanguagePage from '@/pages/settings/language';
import { GroupDetailPage } from '@/pages/group-detail';
import NotFoundPage from '@/pages/not-found';
import ComponentDemoPage from '@/pages/component-demo';

import styles from './MobileLayout.module.scss';

const TAB_ROOT_PATHS = ['/', '/chats', '/settings', '/demo'];

const MobileLayout: React.FC = () => {
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
        <IonTabs className={`${isTabRoot ? '' : styles.tabBarHidden}`}>
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
            <IonTabBar slot="bottom">
                {tabBarButtons}
            </IonTabBar>
        </IonTabs>
    );
};

export default MobileLayout;
