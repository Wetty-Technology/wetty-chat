import { type ReactNode, useCallback, useEffect, useMemo, useState } from 'react';
import {
  IonBadge,
  IonContent,
  IonIcon,
  IonItem,
  IonItemOption,
  IonItemOptions,
  IonItemSliding,
  IonLabel,
  IonList,
  IonRefresher,
  IonRefresherContent,
  type RefresherEventDetail,
} from '@ionic/react';
import { useDispatch, useSelector } from 'react-redux';
import { checkmarkDone, mailUnreadOutline, notificationsOffOutline } from 'ionicons/icons';
import { type ChatListEntry, getChats } from '@/api/chats';
import { selectAllChats, setChatLastReadMessageId, setChatsList, setChatUnreadCount } from '@/store/chatsSlice';
import { selectEffectiveLocale } from '@/store/settingsSlice';
import { Trans } from '@lingui/react/macro';
import { markChatAsUnread, markMessagesAsRead, type MessageResponse } from '@/api/messages';
import { t } from '@lingui/core/macro';
import { syncAppBadgeCount } from '@/utils/badges';
import { getChatDisplayName } from '@/utils/chatDisplay';
import { UserAvatar } from '@/components/UserAvatar';
import { formatMessagePreview, getNotificationPreviewLabels } from '@/utils/messagePreview';
import { buildChatThreadRouteState, type ChatThreadRouteState } from '@/types/chatThreadNavigation';
import { CHAT_LIST_REFRESH_MIN_DURATION_MS } from '@/constants/chatTiming';
import { getThreads } from '@/api/threads';
import { selectThreads, selectThreadsLoaded, selectTotalUnreadThreadCount, setThreadsList } from '@/store/threadsSlice';
import { selectTotalUnreadChatCount } from '@/store/chatsSlice';
import { ThreadsListInner } from '@/pages/threads';
import { type ChatListTab, ChatListSegment } from './ChatListSegment';
import { ThreadListRow } from '@/components/chat/ThreadListRow';
import styles from './ChatList.module.scss';

function formatLastActivity(isoString: string | null, locale: string): string {
  if (!isoString) return '';
  const date = new Date(isoString);
  const now = new Date();

  const isSameDay =
    date.getDate() === now.getDate() && date.getMonth() === now.getMonth() && date.getFullYear() === now.getFullYear();

  if (isSameDay) {
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const rtf = new Intl.RelativeTimeFormat(locale, { numeric: 'always' });

    if (diffMins < 60) {
      return rtf.format(-Math.max(1, diffMins), 'minute');
    } else {
      const diffHours = Math.floor(diffMins / 60);
      return rtf.format(-diffHours, 'hour');
    }
  }

  const isSameYear = date.getFullYear() === now.getFullYear();

  if (isSameYear) {
    return Intl.DateTimeFormat(locale, {
      month: 'short',
      day: 'numeric',
    }).format(date);
  } else {
    return Intl.DateTimeFormat(locale, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    }).format(date);
  }
}

function isChatMuted(chat: ChatListEntry): boolean {
  if (!chat.mutedUntil) return false;
  return new Date(chat.mutedUntil) > new Date();
}

function getMessagePreview(message: MessageResponse | null, locale: string): ReactNode {
  if (!message) return t`No messages yet`;

  const senderName = message.sender?.name || 'User';
  const previewText = formatMessagePreview(message, getNotificationPreviewLabels(locale));

  return (
    <>
      <span className={styles.chatsListPreviewSender}>{senderName}: </span>
      {previewText || t`New message`}
    </>
  );
}

type MergedItem =
  | { type: 'group'; chat: ChatListEntry; sortTime: number }
  | { type: 'thread'; thread: import('@/api/threads').ThreadListItem; sortTime: number };

interface ChatListProps {
  activeChatId?: string;
  activeThreadId?: string;
  onChatSelect: (chatId: string, routeState?: ChatThreadRouteState) => void;
  onThreadSelect?: (chatId: string, threadRootId: string) => void;
}

export function ChatList({ activeChatId, activeThreadId, onChatSelect, onThreadSelect }: ChatListProps) {
  const dispatch = useDispatch();
  const locale = useSelector(selectEffectiveLocale);
  const chats = useSelector(selectAllChats);
  const threads = useSelector(selectThreads);
  const threadsLoaded = useSelector(selectThreadsLoaded);
  const unreadThreadCount = useSelector(selectTotalUnreadThreadCount);
  const unreadChatCount = useSelector(selectTotalUnreadChatCount);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<ChatListTab>('all');

  const updateAppBadge = useCallback(async () => {
    await syncAppBadgeCount();
  }, []);

  useEffect(() => {
    void getChats()
      .then((res) => {
        const chatList = res.data.chats || [];
        dispatch(setChatsList(chatList));
        setError(null);
      })
      .catch((err: Error) => {
        setError(err.message || t`Failed to load chats`);
      })
      .finally(() => setLoading(false));
    void updateAppBadge();
  }, [dispatch, updateAppBadge]);

  // Load threads on mount so the "All" tab can interleave them
  useEffect(() => {
    if (!threadsLoaded) {
      void getThreads({ limit: 20 }).then((res) => {
        dispatch(setThreadsList({ threads: res.data.threads, nextCursor: res.data.nextCursor }));
      });
    }
  }, [threadsLoaded, dispatch]);

  const handleToggleRead = async (chat: ChatListEntry, slidingItem: HTMLIonItemSlidingElement | null) => {
    slidingItem?.close();
    if (!chat.lastMessage) return;

    if (chat.unreadCount > 0) {
      try {
        const res = await markMessagesAsRead(chat.id, chat.lastMessage.id);
        dispatch(setChatLastReadMessageId({ chatId: chat.id, lastReadMessageId: res.data.lastReadMessageId }));
        dispatch(setChatUnreadCount({ chatId: chat.id, unreadCount: res.data.unreadCount }));
        await updateAppBadge();
      } catch (err) {
        console.error('Failed to mark as read', err);
      }
    } else {
      try {
        dispatch(setChatUnreadCount({ chatId: chat.id, unreadCount: 1 }));
        const res = await markChatAsUnread(chat.id);
        dispatch(setChatLastReadMessageId({ chatId: chat.id, lastReadMessageId: res.data.lastReadMessageId }));
        dispatch(setChatUnreadCount({ chatId: chat.id, unreadCount: res.data.unreadCount }));
        await updateAppBadge();
      } catch (err) {
        console.error('Failed to mark as unread', err);
      }
    }
  };

  const handleRefresh = (event: CustomEvent<RefresherEventDetail>) => {
    const startTime = Date.now();
    const refreshChats = getChats()
      .then((res) => {
        const chatList = res.data.chats || [];
        dispatch(setChatsList(chatList));
        setError(null);
      })
      .catch((err: Error) => {
        setError(err.message || t`Failed to refresh chats`);
      });
    const refreshThreads = getThreads({ limit: 20 })
      .then((res) => {
        dispatch(setThreadsList({ threads: res.data.threads, nextCursor: res.data.nextCursor }));
      })
      .catch(() => {
        // threads refresh failure is non-critical
      });

    Promise.all([refreshChats, refreshThreads]).finally(() => {
      const elapsed = Date.now() - startTime;
      const delay = Math.max(0, CHAT_LIST_REFRESH_MIN_DURATION_MS - elapsed);
      setTimeout(() => {
        event.detail.complete();
      }, delay);
    });
    void updateAppBadge();
  };

  // Merged interleaved list for "All" tab
  const mergedItems = useMemo((): MergedItem[] => {
    const items: MergedItem[] = [];
    for (const chat of chats) {
      items.push({
        type: 'group',
        chat,
        sortTime: chat.lastMessageAt ? new Date(chat.lastMessageAt).getTime() : 0,
      });
    }
    for (const thread of threads) {
      items.push({
        type: 'thread',
        thread,
        sortTime: thread.lastReplyAt ? new Date(thread.lastReplyAt).getTime() : 0,
      });
    }
    items.sort((a, b) => b.sortTime - a.sortTime);
    return items;
  }, [chats, threads]);

  const handleThreadSelect = useCallback(
    (chatId: string, threadRootId: string) => {
      onThreadSelect?.(chatId, threadRootId);
    },
    [onThreadSelect],
  );

  const renderChatItem = (chat: ChatListEntry) => (
    <IonItemSliding key={chat.id}>
      <IonItemOptions
        side="start"
        onIonSwipe={(e) => {
          const slidingItem = (e.target as HTMLElement).closest('ion-item-sliding');
          handleToggleRead(chat, slidingItem as HTMLIonItemSlidingElement | null);
        }}
      >
        <IonItemOption
          color="primary"
          expandable
          onClick={(e) => {
            const slidingItem = (e.target as HTMLElement).closest('ion-item-sliding');
            handleToggleRead(chat, slidingItem as HTMLIonItemSlidingElement | null);
          }}
        >
          <IonIcon slot="top" icon={chat.unreadCount > 0 ? checkmarkDone : mailUnreadOutline} />
          {chat.unreadCount > 0 ? <Trans>Read</Trans> : <Trans>Unread</Trans>}
        </IonItemOption>
      </IonItemOptions>
      <IonItem
        id={chat.id}
        button
        detail={false}
        className={`${styles.chatListItem} ${activeChatId === chat.id ? styles.active : ''}`}
        onClick={() =>
          onChatSelect(
            chat.id,
            buildChatThreadRouteState({
              unreadCount: chat.unreadCount,
              lastReadMessageId: chat.lastReadMessageId,
            }),
          )
        }
      >
        <span slot="start">
          <UserAvatar
            name={getChatDisplayName(chat.id, chat.name)}
            avatarUrl={chat.avatar}
            size={48}
            className={styles.chatsListAvatar}
          />
        </span>
        <IonLabel className={styles.chatsListLabel}>
          <h3 className={styles.chatsListTitle}>
            <span className={styles.chatsListTitleText}>{getChatDisplayName(chat.id, chat.name)}</span>
            {isChatMuted(chat) ? (
              <IonIcon aria-hidden="true" icon={notificationsOffOutline} className={styles.chatsListMutedIcon} />
            ) : null}
          </h3>
          <p className={styles.chatsListPreview}>{getMessagePreview(chat.lastMessage, locale)}</p>
        </IonLabel>
        <div slot="end" className={styles.chatsListEndSlot}>
          <div className={styles.chatsListTime}>{formatLastActivity(chat.lastMessageAt, locale)}</div>
          <div className={styles.chatsListBadge}>
            {chat.unreadCount > 0 && (
              <IonBadge mode="ios" color={isChatMuted(chat) ? 'medium' : 'primary'}>
                {chat.unreadCount > 99 ? '99+' : chat.unreadCount}
              </IonBadge>
            )}
          </div>
        </div>
      </IonItem>
    </IonItemSliding>
  );

  const renderContent = () => {
    if (error) {
      return (
        <IonList>
          <IonItem>
            <IonLabel>
              <h3>
                <Trans>Error</Trans>
              </h3>
              <p>{error}</p>
            </IonLabel>
          </IonItem>
        </IonList>
      );
    }

    if (loading) {
      return (
        <IonList>
          <IonItem>
            <IonLabel>
              <Trans>Loading…</Trans>
            </IonLabel>
          </IonItem>
        </IonList>
      );
    }

    if (activeTab === 'threads') {
      return <ThreadsListInner activeThreadId={activeThreadId} onThreadSelect={handleThreadSelect} />;
    }

    if (activeTab === 'groups') {
      if (chats.length === 0) {
        return (
          <IonList>
            <IonItem>
              <IonLabel>
                <Trans>No chats yet</Trans>
              </IonLabel>
            </IonItem>
          </IonList>
        );
      }
      return <IonList>{chats.map(renderChatItem)}</IonList>;
    }

    // "all" tab — interleaved groups + threads
    if (mergedItems.length === 0) {
      return (
        <IonList>
          <IonItem>
            <IonLabel>
              <Trans>No chats yet</Trans>
            </IonLabel>
          </IonItem>
        </IonList>
      );
    }

    return (
      <IonList>
        {mergedItems.map((item) => {
          if (item.type === 'group') {
            return renderChatItem(item.chat);
          }
          return (
            <ThreadListRow
              key={`thread-${item.thread.threadRootMessage.id}`}
              thread={item.thread}
              locale={locale}
              isActive={activeThreadId === item.thread.threadRootMessage.id}
              onSelect={handleThreadSelect}
            />
          );
        })}
      </IonList>
    );
  };

  return (
    <IonContent fullscreen>
      <IonRefresher slot="fixed" onIonRefresh={handleRefresh}>
        <IonRefresherContent />
      </IonRefresher>
      <ChatListSegment
        value={activeTab}
        onChange={setActiveTab}
        allUnreadCount={unreadChatCount + unreadThreadCount}
        groupsUnreadCount={unreadChatCount}
        threadsUnreadCount={unreadThreadCount}
      />
      {renderContent()}
    </IonContent>
  );
}
