import { useState } from 'react';
import {
  IonButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonInput,
  IonItem,
  IonLabel,
  IonList,
  IonPage,
  IonTitle,
  IonToolbar,
  useIonAlert,
} from '@ionic/react';
import { useHistory } from 'react-router-dom';
import { createChat } from '@/api/chats';
import { BackButton } from '@/components/BackButton';
import type { BackAction } from '@/types/back-action';

interface CreateChatCoreProps {
  backAction?: BackAction;
}

export default function CreateChatCore({ backAction }: CreateChatCoreProps) {
  const history = useHistory();
  const [presentAlert] = useIonAlert();
  const [name, setName] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = () => {
    const trimmed = name.trim() || undefined;
    setSubmitting(true);
    createChat({ name: trimmed })
      .then(() => {
        history.replace('/chats');
      })
      .catch((err: { message?: string }) => {
        presentAlert({
          header: 'Error',
          message: err?.message ?? 'Failed to create chat',
          buttons: ['OK'],
        });
      })
      .finally(() => {
        setSubmitting(false);
      });
  };

  return (
    <div className="ion-page">
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">{backAction && <BackButton action={backAction} />}</IonButtons>
          <IonTitle>New Chat</IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent>
        <div style={{ padding: '16px' }}>
          <IonList>
            <IonItem>
              <IonLabel position="stacked">Chat name</IonLabel>
              <IonInput
                type="text"
                placeholder="Optional"
                value={name}
                onIonInput={(e) => setName(e.detail.value ?? '')}
                clearInput
              />
            </IonItem>
          </IonList>
          <div style={{ marginTop: '16px' }}>
            <IonButton expand="block" disabled={submitting} onClick={handleSubmit}>
              {submitting ? 'Creating...' : 'Create'}
            </IonButton>
          </div>
        </div>
      </IonContent>
    </div>
  );
}

export function CreateChatPage() {
  return (
    <IonPage>
      <CreateChatCore backAction={{ type: 'back', defaultHref: '/chats' }} />
    </IonPage>
  );
}
