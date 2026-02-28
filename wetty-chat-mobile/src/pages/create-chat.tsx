import { useState } from 'react';
import {
  IonPage,
  IonHeader,
  IonToolbar,
  IonTitle,
  IonContent,
  IonList,
  IonItem,
  IonLabel,
  IonInput,
  IonButton,
  IonBackButton,
  IonButtons,
  useIonAlert,
} from '@ionic/react';
import { useHistory } from 'react-router-dom';
import { createChat } from '@/api/chats';

export default function CreateChat() {
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
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            <IonBackButton defaultHref="/chats" text="" />
          </IonButtons>
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
    </IonPage>
  );
}
