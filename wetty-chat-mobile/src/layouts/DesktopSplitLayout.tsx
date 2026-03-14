import { useCallback } from 'react';
import { useHistory, useRouteMatch } from 'react-router-dom';
import { Trans } from '@lingui/react/macro';
import { ChatList } from '@/components/chat/ChatList';
import ChatThread from '@/pages/chat-thread';
import ChatSettingsPage from '@/pages/chat-settings';
import ChatMembersPage from '@/pages/chat-members';
import GroupDetailPage from '@/pages/group-detail';
import CreateChatPage from '@/pages/create-chat';
import styles from './DesktopSplitLayout.module.scss';

export function DesktopSplitLayout() {
  const history = useHistory();

  // Match the most specific routes first
  const threadMatch = useRouteMatch<{ id: string; threadId: string }>('/chats/chat/:id/thread/:threadId');
  const settingsMatch = useRouteMatch<{ id: string }>('/chats/chat/:id/settings');
  const membersMatch = useRouteMatch<{ id: string }>('/chats/chat/:id/members');
  const detailsMatch = useRouteMatch<{ id: string }>('/chats/chat/:id/details');
  const chatMatch = useRouteMatch<{ id: string }>('/chats/chat/:id');
  const newMatch = useRouteMatch('/chats/new');

  const activeChatId =
    threadMatch?.params.id ??
    settingsMatch?.params.id ??
    membersMatch?.params.id ??
    detailsMatch?.params.id ??
    chatMatch?.params.id ??
    undefined;

  const handleChatSelect = useCallback((chatId: string) => {
    history.replace(`/chats/chat/${chatId}`);
  }, [history]);

  let rightPane: React.ReactNode;

  if (threadMatch?.isExact) {
    const { id, threadId } = threadMatch.params;
    rightPane = <ChatThread key={`${threadId}`} chatId={id} threadId={threadId} embedded />;
  } else if (settingsMatch?.isExact) {
    rightPane = <ChatSettingsPage key={settingsMatch.params.id} chatId={settingsMatch.params.id} embedded />;
  } else if (membersMatch?.isExact) {
    rightPane = <ChatMembersPage key={membersMatch.params.id} chatId={membersMatch.params.id} embedded />;
  } else if (detailsMatch?.isExact) {
    rightPane = <GroupDetailPage key={detailsMatch.params.id} chatId={detailsMatch.params.id} embedded />;
  } else if (chatMatch?.isExact) {
    rightPane = <ChatThread key={chatMatch.params.id} chatId={chatMatch.params.id} embedded />;
  } else if (newMatch) {
    rightPane = <CreateChatPage embedded />;
  } else {
    rightPane = (
      <div className={styles.desktopSplitPlaceholder}>
        <Trans>Select a chat</Trans>
      </div>
    );
  }

  return (
    <div className={styles.desktopSplitLayout}>
      <div className={styles.desktopSplitLeft}>
        <ChatList activeChatId={activeChatId} onChatSelect={handleChatSelect} />
      </div>
      <div className={styles.desktopSplitRight}>
        {rightPane}
      </div>
    </div>
  );
}
