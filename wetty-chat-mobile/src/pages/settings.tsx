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
  IonInput,
  IonButton,
  useIonToast,
} from '@ionic/react';
import { getCurrentUserId, setCurrentUserId } from '@/js/current-user';

export default function Settings() {
  const [uidInput, setUidInput] = useState(String(getCurrentUserId()));
  const [presentToast] = useIonToast();

  useEffect(() => {
    setUidInput(String(getCurrentUserId()));
  }, []);

  const handleSave = () => {
    const trimmed = uidInput.trim();
    const n = parseInt(trimmed, 10);
    if (!Number.isFinite(n) || n < 1) {
      presentToast({ message: 'Enter a valid User ID (integer ≥ 1)', duration: 3000 });
      return;
    }
    setCurrentUserId(n);
    window.location.reload();
  };

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonTitle>Settings</IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent>
        <div style={{ padding: '16px' }}>
          <IonList>
            <IonItem>
              <IonLabel position="stacked">User ID</IonLabel>
              <IonInput
                type="number"
                placeholder="e.g. 1"
                value={uidInput}
                onIonInput={(e) => setUidInput(e.detail.value ?? '')}
              />
            </IonItem>
          </IonList>
          <div style={{ marginTop: '16px' }}>
            <IonButton expand="block" onClick={handleSave}>
              Save
            </IonButton>
          </div>
          <IonList style={{ marginTop: '24px' }}>
            <IonItem button detail href="/demo/infinite-scroll">
              <IonLabel>Infinite Scroll + Virtuoso demo</IonLabel>
            </IonItem>
          </IonList>
        </div>
      </IonContent>
    </IonPage>
  );
}
