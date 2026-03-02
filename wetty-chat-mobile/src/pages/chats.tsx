import { useState, useEffect } from 'react';
import {
  IonPage,
  IonHeader,
  IonToolbar,
  IonTitle,
  IonContent,
  IonList,
  IonItem,
  IonLabel,
  IonItemSliding,
  IonItemOptions,
  IonItemOption,
  IonButtons,
  IonButton,
  IonIcon,
  useIonAlert,
} from '@ionic/react';
import { useHistory } from 'react-router-dom';
import { createOutline } from 'ionicons/icons';
import { getChats, type ChatListItem } from '@/api/chats';
import './chats.scss';
import { Trans } from '@lingui/react/macro';

function formatLastActivity(isoString: string | null): string {
  if (!isoString) return '';
  const date = new Date(isoString);
  return Intl.DateTimeFormat('en', {
    month: 'short',
    year: 'numeric',
    day: 'numeric',
  }).format(date);
}

function chatDisplayName(chat: ChatListItem): string {
  if (chat.name && chat.name.trim()) return chat.name;
  return `Chat ${chat.id}`;
}

export default function Chats() {
  const history = useHistory();
  const [presentAlert] = useIonAlert();
  const [chats, setChats] = useState<ChatListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadChats = () => {
    setLoading(true);
    getChats()
      .then((res) => {
        setChats(res.data.chats || []);
        setError(null);
      })
      .catch((err: Error) => {
        setError(err.message || 'Failed to load chats');
        setChats([]);
      })
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    loadChats();
  }, []);

  const handleUnread = () => presentAlert({ header: 'Unread', buttons: ['OK'] });
  const handlePin = () => presentAlert({ header: 'Pin', buttons: ['OK'] });
  const handleMore = () => presentAlert({ header: 'More', buttons: ['OK'] });
  const handleArchive = () => presentAlert({ header: 'Archive', buttons: ['OK'] });

  return (
    <IonPage className="chats-page">
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            <IonButton>Edit</IonButton>
          </IonButtons>
          <IonTitle><Trans>Chats</Trans></IonTitle>
          <IonButtons slot="end">
            <IonButton routerLink="/chats/new">
              <IonIcon slot="icon-only" icon={createOutline} />
            </IonButton>
          </IonButtons>
        </IonToolbar>
      </IonHeader>
      <IonContent fullscreen>
        {error && (
          <IonList>
            <IonItem>
              <IonLabel>
                <h3>Error</h3>
                <p>{error}</p>
              </IonLabel>
            </IonItem>
          </IonList>
        )}
        {loading && !error && (
          <IonList>
            <IonItem>
              <IonLabel><Trans>Loading…</Trans></IonLabel>
            </IonItem>
          </IonList>
        )}
        {!loading && !error && (
          <IonList className="chats-list">
            {chats.length === 0 && (
              <IonItem>
                <IonLabel>No chats yet</IonLabel>
              </IonItem>
            )}
            {chats.map((chat) => (
              <IonItemSliding key={chat.id}>
                <IonItemOptions side="start">
                  <IonItemOption color="primary" onClick={handleUnread}>
                    Unread
                  </IonItemOption>
                  <IonItemOption color="medium" onClick={handlePin}>
                    Pin
                  </IonItemOption>
                </IonItemOptions>

                <IonItem
                  button
                  detail={false}
                  onClick={() => history.push(`/chats/chat/${chat.id}`, { chatName: chatDisplayName(chat) })}
                >
                  <div slot="start" className="chats-list-avatar">
                    {chat.name && chat.name.trim() ? chat.name.trim().charAt(0).toUpperCase() : '?'}
                  </div>
                  <IonLabel>
                    <h2>{chatDisplayName(chat)}</h2>
                    <p>Last activity</p>
                  </IonLabel>
                  <IonLabel slot="end" className="chats-list-time">
                    {formatLastActivity(chat.last_message_at)}
                  </IonLabel>
                </IonItem>

                <IonItemOptions side="end">
                  <IonItemOption color="medium" onClick={handleMore}>
                    More
                  </IonItemOption>
                  <IonItemOption color="tertiary" onClick={handleArchive}>
                    Archive
                  </IonItemOption>
                </IonItemOptions>
              </IonItemSliding>
            ))}
          </IonList>
        )}
      </IonContent>
    </IonPage>
  );
}
