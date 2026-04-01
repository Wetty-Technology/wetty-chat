import { type ReactNode, useCallback, useEffect, useState } from 'react';
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
import { chatbubbleEllipses, checkmarkDone, mailUnreadOutline, notificationsOffOutline } from 'ionicons/icons';
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
import {
  selectShouldShowThreadsRow,
  selectThreadsLoaded,
  selectTotalUnreadThreadCount,
  setThreadsList,
} from '@/store/threadsSlice';
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

interface ChatListProps {
  activeChatId?: string;
  isThreadsActive?: boolean;
  onChatSelect: (chatId: string, routeState?: ChatThreadRouteState) => void;
  onThreadsSelect?: () => void;
}

export function ChatList({ activeChatId, isThreadsActive, onChatSelect, onThreadsSelect }: ChatListProps) {
  const dispatch = useDispatch();
  const locale = useSelector(selectEffectiveLocale);
  const chats = useSelector(selectAllChats);
  const showThreadsRow = useSelector(selectShouldShowThreadsRow);
  const threadsLoaded = useSelector(selectThreadsLoaded);
  const unreadThreadCount = useSelector(selectTotalUnreadThreadCount);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

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

  useEffect(() => {
    if (!threadsLoaded) {
      void getThreads({ limit: 1 }).then((res) => {
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
    getChats()
      .then((res) => {
        const chatList = res.data.chats || [];
        dispatch(setChatsList(chatList));
        setError(null);
      })
      .catch((err: Error) => {
        setError(err.message || t`Failed to refresh chats`);
      })
      .finally(() => {
        const elapsed = Date.now() - startTime;
        const delay = Math.max(0, CHAT_LIST_REFRESH_MIN_DURATION_MS - elapsed);
        setTimeout(() => {
          event.detail.complete();
        }, delay);
      });
    void updateAppBadge();
  };

  return (
    <IonContent fullscreen>
      <IonRefresher slot="fixed" onIonRefresh={handleRefresh}>
        <IonRefresherContent />
      </IonRefresher>
      {error && (
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
      )}
      {loading && !error && (
        <IonList>
          <IonItem>
            <IonLabel>
              <Trans>Loading…</Trans>
            </IonLabel>
          </IonItem>
        </IonList>
      )}
      {!loading && !error && (
        <IonList>
          {showThreadsRow && onThreadsSelect && (
            <IonItem
              button
              detail={false}
              onClick={onThreadsSelect}
              className={`${styles.chatListItem} ${isThreadsActive ? styles.active : ''}`}
            >
              <span slot="start">
                <span className={styles.threadsRowIcon}>
                  <IonIcon icon={chatbubbleEllipses} />
                </span>
              </span>
              <IonLabel className={styles.chatsListLabel}>
                <h2 className={styles.chatsListTitle}>
                  <span className={styles.chatsListTitleText}>
                    <Trans>Threads</Trans>
                  </span>
                </h2>
                <p className={styles.chatsListPreview}>
                  {unreadThreadCount > 0 ? <Trans>Click to view new replies</Trans> : <Trans>No new replies</Trans>}
                </p>
              </IonLabel>
              <div slot="end" className={styles.chatsListEndSlot}>
                <div className={styles.chatsListBadge}>
                  {unreadThreadCount > 0 && (
                    <IonBadge mode="ios" color="primary">
                      {unreadThreadCount > 99 ? '99+' : unreadThreadCount}
                    </IonBadge>
                  )}
                </div>
              </div>
            </IonItem>
          )}
          {chats.length === 0 && (
            <IonItem>
              <IonLabel>
                <Trans>No chats yet</Trans>
              </IonLabel>
            </IonItem>
          )}
          {chats.map((chat) => (
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
                  <h2 className={styles.chatsListTitle}>
                    <span className={styles.chatsListTitleText}>{getChatDisplayName(chat.id, chat.name)}</span>
                    {isChatMuted(chat) ? (
                      <IonIcon
                        aria-hidden="true"
                        icon={notificationsOffOutline}
                        className={styles.chatsListMutedIcon}
                      />
                    ) : null}
                  </h2>
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
          ))}
        </IonList>
      )}
    </IonContent>
  );
}
