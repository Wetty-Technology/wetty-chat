import { IonButtons, IonContent, IonHeader, IonPage, IonTitle, IonToolbar } from '@ionic/react';
import { Trans } from '@lingui/react/macro';
import { useCallback } from 'react';
import { useHistory, useParams } from 'react-router-dom';
import type { SavedMessageResponse } from '@/api/savedMessages';
import { BackButton } from '@/components/BackButton';
import { SavedMessageList } from '@/components/chat/saved/SavedMessageList';
import type { BackAction } from '@/types/back-action';
import { buildSavedMessageTarget } from '@/utils/savedMessages';

interface GroupSavedMessagesCoreProps {
  chatId?: string;
  backAction?: BackAction;
}

export function GroupSavedMessagesCore({ chatId: propChatId, backAction }: GroupSavedMessagesCoreProps) {
  const { id } = useParams<{ id: string }>();
  const chatId = propChatId ?? (id ? String(id) : '');
  const history = useHistory();

  const handleOpenMessage = useCallback(
    (saved: SavedMessageResponse) => {
      if (!saved.canLocateContext) {
        return;
      }
      history.replace(buildSavedMessageTarget(saved));
    },
    [history],
  );

  if (!chatId) {
    return null;
  }

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            <BackButton action={backAction ?? { type: 'back', defaultHref: `/chats/chat/${chatId}/group-info` }} />
          </IonButtons>
          <IonTitle>
            <Trans>Saved Messages</Trans>
          </IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent color="light" className="ion-no-padding">
        <SavedMessageList chatId={chatId} onOpenMessage={handleOpenMessage} />
      </IonContent>
    </IonPage>
  );
}

export function GroupSavedMessagesPage() {
  const { id } = useParams<{ id: string }>();
  return (
    <GroupSavedMessagesCore chatId={id} backAction={{ type: 'back', defaultHref: `/chats/chat/${id}/group-info` }} />
  );
}

export default GroupSavedMessagesCore;
