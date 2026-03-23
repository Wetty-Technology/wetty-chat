import { IonButton, IonButtons, IonHeader, IonIcon, IonPage, IonToolbar } from '@ionic/react';
import { Trans } from '@lingui/react/macro';
import { useHistory } from 'react-router-dom';
import { createOutline } from 'ionicons/icons';
import { ChatList } from '@/components/chat/ChatList';
import { FeatureGate } from '@/components/FeatureGate';
import { TitleWithConnectionStatus } from '@/components/TitleWithConnectionStatus';

export default function Chats() {
  const history = useHistory();

  return (
    <IonPage className="chats-page">
      <IonHeader>
        <IonToolbar>
          <TitleWithConnectionStatus>
            <Trans>Chats</Trans>
          </TitleWithConnectionStatus>
          <IonButtons slot="end">
            <FeatureGate>
              <IonButton routerLink="/chats/new">
                <IonIcon slot="icon-only" icon={createOutline} />
              </IonButton>
            </FeatureGate>
          </IonButtons>
        </IonToolbar>
      </IonHeader>
      <ChatList onChatSelect={(chatId) => history.push(`/chats/chat/${chatId}`)} />
    </IonPage>
  );
}
