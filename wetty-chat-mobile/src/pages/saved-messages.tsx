import { IonButtons, IonContent, IonHeader, IonPage, IonTitle, IonToolbar } from '@ionic/react';
import { Trans } from '@lingui/react/macro';
import { useCallback } from 'react';
import { useHistory } from 'react-router-dom';
import type { SavedMessageResponse } from '@/api/savedMessages';
import { BackButton } from '@/components/BackButton';
import { SavedMessageList } from '@/components/chat/saved/SavedMessageList';
import type { BackAction } from '@/types/back-action';
import { buildSavedMessageTarget } from '@/utils/savedMessages';

interface SavedMessagesCoreProps {
  backAction?: BackAction;
}

export function SavedMessagesCore({ backAction }: SavedMessagesCoreProps) {
  const history = useHistory();

  const handleOpenMessage = useCallback(
    (saved: SavedMessageResponse) => {
      if (!saved.canLocateContext) {
        return;
      }
      history.push(buildSavedMessageTarget(saved));
    },
    [history],
  );

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            <BackButton action={backAction ?? { type: 'back', defaultHref: '/settings' }} />
          </IonButtons>
          <IonTitle>
            <Trans>Saved Messages</Trans>
          </IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent color="light" className="ion-no-padding">
        <SavedMessageList onOpenMessage={handleOpenMessage} />
      </IonContent>
    </IonPage>
  );
}

export default function SavedMessagesPage() {
  return <SavedMessagesCore backAction={{ type: 'back', defaultHref: '/settings' }} />;
}
