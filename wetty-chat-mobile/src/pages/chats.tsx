import { IonButtons, IonHeader, IonPage, IonToolbar } from '@ionic/react';
import { Trans } from '@lingui/react/macro';
import { useHistory } from 'react-router-dom';
import { createOutline } from 'ionicons/icons';
import { ChatList } from '@/components/chat/ChatList';
import { HeaderActionMenu } from '@/components/HeaderActionMenu';
import { TitleWithConnectionStatus } from '@/components/TitleWithConnectionStatus';

export default function Chats() {
  const history = useHistory();
  const menuActions = [
    {
      id: 'create-chat',
      label: <Trans>Create Chat</Trans>,
      onSelect: () => history.push('/chats/new'),
    },
    {
      id: 'join-via-code',
      label: <Trans>Join via Code</Trans>,
      onSelect: () => history.push('/chats/join'),
    },
  ];

  return (
    <IonPage className="chats-page">
      <IonHeader>
        <IonToolbar>
          <TitleWithConnectionStatus>
            <Trans>Chats</Trans>
          </TitleWithConnectionStatus>
          <IonButtons slot="end">
            <HeaderActionMenu actions={menuActions} icon={createOutline} />
          </IonButtons>
        </IonToolbar>
      </IonHeader>
      <ChatList onChatSelect={(chatId) => history.push(`/chats/chat/${chatId}`)} />
    </IonPage>
  );
}
