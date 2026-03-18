import { useCallback, useRef, type ReactNode } from 'react';
import { matchPath, useHistory, useLocation } from 'react-router-dom';
import { Trans } from '@lingui/react/macro';
import { IonButton, IonButtons, IonHeader, IonIcon, IonModal, IonTitle, IonToolbar } from '@ionic/react';
import { createOutline, settings } from 'ionicons/icons';
import { ChatList } from '@/components/chat/ChatList';
import ChatThreadCore from '@/pages/chat-thread';
import ChatSettingsCore from '@/pages/chat-settings';
import ChatMembersCore from '@/pages/chat-members';
import GroupDetailCore from '@/pages/group-detail';
import CreateChatCore from '@/pages/create-chat';
import { SettingsCore } from '@/pages/settings';
import { LanguagePageCore } from '@/pages/settings/language';
import type { BackAction } from '@/types/back-action';
import styles from './DesktopSplitLayout.module.scss';
import { FeatureGate } from '@/components/FeatureGate';

interface DesktopRouteState {
  backgroundPath?: string;
}

interface DesktopRouteMatches {
  activeChatId: string | undefined;
  threadMatch: { id: string; threadId: string } | null;
  settingsMatch: { id: string } | null;
  membersMatch: { id: string } | null;
  detailsMatch: { id: string } | null;
  isNewChat: boolean;
  globalSettings: boolean;
  languageSettings: boolean;
}

function getDesktopRouteMatches(pathname: string): DesktopRouteMatches {
  const threadRaw = matchPath<{ id: string; threadId: string }>(pathname, {
    path: '/chats/chat/:id/thread/:threadId',
    exact: true,
  });
  const settingsRaw = matchPath<{ id: string }>(pathname, {
    path: '/chats/chat/:id/settings',
    exact: true,
  });
  const membersRaw = matchPath<{ id: string }>(pathname, {
    path: '/chats/chat/:id/members',
    exact: true,
  });
  const detailsRaw = matchPath<{ id: string }>(pathname, {
    path: '/chats/chat/:id/details',
    exact: true,
  });
  const chatRaw = matchPath<{ id: string }>(pathname, {
    path: '/chats/chat/:id',
    exact: true,
  });
  const newRaw = matchPath(pathname, {
    path: '/chats/new',
    exact: true,
  });
  const languageSettings = !!matchPath(pathname, {
    path: '/settings/language',
    exact: true,
  });
  const globalSettings = !!matchPath(pathname, {
    path: '/settings',
    exact: true,
  }) || languageSettings;

  return {
    activeChatId:
      threadRaw?.params.id ??
      settingsRaw?.params.id ??
      membersRaw?.params.id ??
      detailsRaw?.params.id ??
      chatRaw?.params.id ??
      undefined,
    threadMatch: threadRaw?.params ?? null,
    settingsMatch: settingsRaw?.params ?? null,
    membersMatch: membersRaw?.params ?? null,
    detailsMatch: detailsRaw?.params ?? null,
    isNewChat: !!newRaw,
    globalSettings,
    languageSettings,
  };
}

/** Deduplicates the settings / members modal pattern. */
function ChatModal({
  chatId,
  activeChatId,
  children,
}: {
  chatId: string | null;
  activeChatId: string | undefined;
  children: (chatId: string, backAction: BackAction) => ReactNode;
}) {
  const history = useHistory();
  return (
    <IonModal
      isOpen={chatId != null}
      onDidDismiss={() => history.push(`/chats/chat/${activeChatId}`)}
    >
      {chatId != null &&
        children(chatId, {
          type: 'close',
          onClose: () => history.push(`/chats/chat/${chatId}`),
        })}
    </IonModal>
  );
}

export function DesktopSplitLayout() {
  const history = useHistory();
  const location = useLocation<DesktopRouteState | undefined>();
  const skipNextGlobalSettingsDismiss = useRef(false);
  const currentRoute = getDesktopRouteMatches(location.pathname);
  const backgroundPath = location.state?.backgroundPath ?? '/chats';
  const baseRoute = currentRoute.globalSettings
    ? getDesktopRouteMatches(backgroundPath)
    : currentRoute;
  const {
    activeChatId,
    threadMatch,
    settingsMatch,
    membersMatch,
    detailsMatch,
    isNewChat,
  } = baseRoute;
  const globalSettingsOpen = currentRoute.globalSettings;

  const handleChatSelect = useCallback((chatId: string) => {
    history.replace(`/chats/chat/${chatId}`);
  }, [history]);

  const openSettingsModal = useCallback(() => {
    history.push({
      pathname: '/settings',
      state: { backgroundPath: location.pathname },
    });
  }, [history, location.pathname]);

  const closeGlobalSettings = useCallback(() => {
    skipNextGlobalSettingsDismiss.current = true;
    history.replace(backgroundPath);
  }, [backgroundPath, history]);

  const handleGlobalSettingsDidDismiss = useCallback(() => {
    if (skipNextGlobalSettingsDismiss.current) {
      skipNextGlobalSettingsDismiss.current = false;
      return;
    }

    history.replace(backgroundPath);
  }, [backgroundPath, history]);

  const openLanguageSettings = useCallback(() => {
    history.push({
      pathname: '/settings/language',
      state: { backgroundPath },
    });
  }, [backgroundPath, history]);

  let subPageOverlay: ReactNode = null;
  
  if (threadMatch) {
    const { id, threadId } = threadMatch;
    subPageOverlay = (
      <ChatThreadCore
        key={threadId}
        chatId={id}
        threadId={threadId}
        backAction={{ type: 'callback', onBack: () => history.go(-1) }}
      />
    );
  } else if (detailsMatch) {
    const { id } = detailsMatch;
    subPageOverlay = (
      <GroupDetailCore
        key={id}
        chatId={id}
        backAction={{ type: 'callback', onBack: () => history.go(-1) }}
      />
    );
  }

  return (
    <div className={styles.desktopSplitLayout}>
      <div className={styles.desktopSplitLeft}>
        <IonHeader>
          <IonToolbar>
            <IonButtons slot="start">
              <IonButton onClick={openSettingsModal} aria-label="Open settings">
                <IonIcon slot="icon-only" icon={settings} />
              </IonButton>
            </IonButtons>
            <IonTitle><Trans>Chats</Trans></IonTitle>
            <IonButtons slot="end">
              <FeatureGate>
                <IonButton routerLink="/chats/new">
                  <IonIcon slot="icon-only" icon={createOutline} />
                </IonButton>
              </FeatureGate>
            </IonButtons>
          </IonToolbar>
        </IonHeader>
        <ChatList
          activeChatId={activeChatId}
          onChatSelect={handleChatSelect}
        />
      </div>
      <div className={styles.desktopSplitRight}>
        {/* Base layer: always render ChatThreadCore when a chat is selected */}
        {activeChatId && !isNewChat && (
          <div
            key={`chat-pane-${activeChatId}`}
            style={{ display: subPageOverlay ? 'none' : undefined }}
            className={styles.desktopSplitPane}
          >
            <ChatThreadCore key={activeChatId} chatId={activeChatId} />
          </div>
        )}

        {/* Overlay layer: sub-page (details, thread) */}
        {subPageOverlay && (
          <div className={styles.desktopSplitPane}>
            {subPageOverlay}
          </div>
        )}

        {/* Settings modal */}
        <ChatModal chatId={settingsMatch?.id ?? null} activeChatId={activeChatId}>
          {(chatId, backAction) => <ChatSettingsCore chatId={chatId} backAction={backAction} />}
        </ChatModal>

        {/* Members modal */}
        <ChatModal chatId={membersMatch?.id ?? null} activeChatId={activeChatId}>
          {(chatId, backAction) => <ChatMembersCore chatId={chatId} backAction={backAction} />}
        </ChatModal>

        {/* Global settings modal */}
        <IonModal isOpen={globalSettingsOpen} onDidDismiss={handleGlobalSettingsDidDismiss}>
          {currentRoute.languageSettings ? (
            <LanguagePageCore
              backAction={{ type: 'callback', onBack: () => history.push({
                pathname: '/settings',
                state: { backgroundPath },
              }) }}
            />
          ) : (
            <SettingsCore
              backAction={{ type: 'close', onClose: closeGlobalSettings }}
              onOpenLanguage={openLanguageSettings}
            />
          )}
        </IonModal>

        {/* Create chat page */}
        {isNewChat && (
          <div className={styles.desktopSplitPane}>
            <CreateChatCore
              backAction={{ type: 'close', onClose: () => history.replace('/chats') }}
            />
          </div>
        )}

        {/* Placeholder when no chat selected */}
        {!activeChatId && !isNewChat && (
          <div className={styles.desktopSplitPlaceholder}>
            <Trans>Select a chat</Trans>
          </div>
        )}
      </div>
    </div>
  );
}
