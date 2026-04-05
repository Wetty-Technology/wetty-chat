import { IonButtons, IonHeader, IonPage, IonToolbar } from '@ionic/react';
import { Trans } from '@lingui/react/macro';
import { useHistory } from 'react-router-dom';
import { addCircleOutline } from 'ionicons/icons';
import { ChatList } from '@/components/chat/ChatList';
import { HeaderActionMenu } from '@/components/HeaderActionMenu';
import { TitleWithConnectionStatus } from '@/components/TitleWithConnectionStatus';
import { useFeatureGate } from '@/hooks/useFeatureGate';

export default function Chats() {
  const isFeatureGateEnabled = useFeatureGate();
  const history = useHistory();
  const menuActions = [
    {
      id: 'join-via-code',
      label: <Trans>Join via Code</Trans>,
      onSelect: () => history.push('/chats/join'),
    },
    ...(isFeatureGateEnabled
      ? [
          {
            id: 'create-chat',
            label: <Trans>Create Chat</Trans>,
            onSelect: () => history.push('/chats/new'),
          },
        ]
      : []),
  ];

  return (
    <IonPage className="chats-page">
      <IonHeader>
        <IonToolbar>
          <TitleWithConnectionStatus>
            <Trans>Chats</Trans>
          </TitleWithConnectionStatus>
          <IonButtons slot="end">
            <HeaderActionMenu actions={menuActions} icon={addCircleOutline} />
          </IonButtons>
        </IonToolbar>
      </IonHeader>
      <ChatList
        onChatSelect={(chatId, resumeHash) => history.push({ pathname: `/chats/chat/${chatId}`, hash: resumeHash })}
        onThreadSelect={(chatId, threadRootId) => history.push(`/chats/chat/${chatId}/thread/${threadRootId}`)}
      />
    </IonPage>
  );
}
