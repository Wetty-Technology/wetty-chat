import { useCallback, type ReactNode } from 'react';
import { useHistory } from 'react-router-dom';
import { Trans } from '@lingui/react/macro';
import { IonModal } from '@ionic/react';
import { ChatList } from '@/components/chat/ChatList';
import ChatThreadCore from '@/pages/chat-thread';
import ChatSettingsCore from '@/pages/chat-settings';
import ChatMembersCore from '@/pages/chat-members';
import GroupDetailCore from '@/pages/group-detail';
import CreateChatCore from '@/pages/create-chat';
import { useChatRoutes } from '@/hooks/useChatRoutes';
import type { BackAction } from '@/types/back-action';
import styles from './DesktopSplitLayout.module.scss';

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
  const { activeChatId, threadMatch, settingsMatch, membersMatch, detailsMatch, isNewChat } =
    useChatRoutes();

  const handleChatSelect = useCallback((chatId: string) => {
    history.replace(`/chats/chat/${chatId}`);
  }, [history]);

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
        <ChatList activeChatId={activeChatId} onChatSelect={handleChatSelect} />
      </div>
      <div className={styles.desktopSplitRight}>
        {/* Base layer: always render ChatThreadCore when a chat is selected */}
        {activeChatId && !isNewChat && (
          <div
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
