import { useState, useEffect, type ReactNode } from 'react';
import {
  IonPage,
  IonHeader,
  IonToolbar,
  IonTitle,
  IonContent,
  IonList,
  IonItem,
  IonLabel,
  IonButtons,
  IonButton,
  IonIcon,
  IonRefresher,
  IonRefresherContent,
  IonBadge,
  IonItemSliding,
  IonItemOptions,
  IonItemOption,
  type RefresherEventDetail,
} from '@ionic/react';
import { useHistory } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { createOutline, mailUnreadOutline, checkmarkDone } from 'ionicons/icons';
import { getChats, getUnreadCount, type ChatListItem } from '@/api/chats';
import { setChatsList, selectAllChats, markChatAsRead, setChatMeta } from '@/store/chatsSlice';
import { selectEffectiveLocale } from '@/store/settingsSlice';
import './chats.scss';
import { Trans } from '@lingui/react/macro';
import { FeatureGate } from '@/components/FeatureGate';
import { type MessageResponse, markMessagesAsRead } from '@/api/messages';
import { t } from '@lingui/core/macro';

function formatLastActivity(isoString: string | null, locale: string): string {
  if (!isoString) return '';
  const date = new Date(isoString);
  const now = new Date();

  const isSameDay =
    date.getDate() === now.getDate() &&
    date.getMonth() === now.getMonth() &&
    date.getFullYear() === now.getFullYear();

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

function chatDisplayName(chat: ChatListItem): string {
  if (chat.name && chat.name.trim()) return chat.name;
  return t`Chat ${chat.id}`;
}

function getMessagePreview(message: MessageResponse | null): ReactNode {
  if (!message) return t`No messages yet`;
  if (message.is_deleted) return t`[Deleted]`;

  const senderName = message.sender?.name || 'User';
  let previewText = t`New message`;

  switch (message.message_type) {
    case 'text':
      previewText = message.message || t`Text message`;
      break;
  }

  return (
    <>
      <span className="chats-list-preview-sender">{senderName}: </span>
      {previewText}
    </>
  );
}

export default function Chats() {
  const history = useHistory();
  const dispatch = useDispatch();
  const locale = useSelector(selectEffectiveLocale);
  const chats = useSelector(selectAllChats);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadChats = () => {
    setLoading(true);
    getChats()
      .then((res) => {
        const chatList = res.data.chats || [];
        dispatch(setChatsList(chatList));
        setError(null);
      })
      .catch((err: Error) => {
        setError(err.message || t`Failed to load chats`);
      })
      .finally(() => setLoading(false));
  };

  const updateAppBadge = async () => {
    try {
      const res = await getUnreadCount();
      if (res.data.unread_count > 0) {
        if ('setAppBadge' in navigator) {
          // @ts-ignore
          navigator.setAppBadge(res.data.unread_count).catch(console.error);
        }
      } else {
        if ('clearAppBadge' in navigator) {
          // @ts-ignore
          navigator.clearAppBadge().catch(console.error);
        }
      }
    } catch (error) {
      console.error(error);
    }
  };

  useEffect(() => {
    loadChats();
    updateAppBadge();
  }, []);

  const handleToggleRead = async (chat: ChatListItem, slidingItem: HTMLIonItemSlidingElement | null) => {
    slidingItem?.close();
    if (!chat.last_message) return;

    if (chat.unread_count > 0) {
      dispatch(markChatAsRead({ chatId: chat.id }));
      try {
        await markMessagesAsRead(chat.id, chat.last_message.id);
        updateAppBadge();
      } catch (err) {
        console.error('Failed to mark as read', err);
      }
    } else {
      try {
        const prevId = (BigInt(chat.last_message.id) - 1n).toString();
        dispatch(setChatMeta({ chatId: chat.id, meta: { unread_count: 1 } }));
        await markMessagesAsRead(chat.id, prevId);
        updateAppBadge();
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
        const delay = Math.max(0, 500 - elapsed);
        setTimeout(() => {
          event.detail.complete();
        }, delay);
      });
  };

  return (
    <IonPage className="chats-page">
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
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
          <IonList className="chats-list">
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
                    <IonIcon
                      slot="top"
                      icon={chat.unread_count > 0 ? checkmarkDone : mailUnreadOutline}
                    />
                    {chat.unread_count > 0 ? (
                      <Trans>Read</Trans>
                    ) : (
                      <Trans>Unread</Trans>
                    )}
                  </IonItemOption>
                </IonItemOptions>
                <IonItem
                  id={chat.id}
                  button
                  detail={false}
                  onClick={() => history.push(`/chats/chat/${chat.id}`)}
                >
                  <div slot="start" className="chats-list-avatar">
                    {chat.name && chat.name.trim() ? chat.name.trim().charAt(0).toUpperCase() : '?'}
                  </div>
                  <IonLabel className="chats-list-label">
                    <h2>{chatDisplayName(chat)}</h2>
                    <p className="chats-list-preview">{getMessagePreview(chat.last_message)}</p>
                  </IonLabel>
                  <div slot="end" className="chats-list-end-slot">
                    <div className="chats-list-time">
                      {formatLastActivity(chat.last_message_at, locale)}
                    </div>
                    <div className="chats-list-badge">
                      {chat.unread_count > 0 && (
                        <IonBadge mode="ios" color="primary">
                          {chat.unread_count > 99 ? '99+' : chat.unread_count}
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
    </IonPage>
  );
}
