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
import { useHistory } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { selectLocale } from '@/store/settingsSlice';
import { getCurrentUserId, setCurrentUserId } from '@/js/current-user';
import { Trans } from '@lingui/react/macro';

export default function Settings() {
  const [uidInput, setUidInput] = useState(String(getCurrentUserId()));
  const [presentToast] = useIonToast();
  const history = useHistory();
  const locale = useSelector(selectLocale);

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
          <IonTitle><Trans>Settings</Trans></IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent>
        <div style={{ padding: '16px' }}>
          <IonList>
            <IonItem button onClick={() => history.push('/settings/language')}>
              <IonLabel>Language</IonLabel>
              <span slot="end">{{ 'en': 'English', 'zh-CN': '简体中文' }[locale!] ?? 'Auto'}</span>
            </IonItem>
            <IonItem>
              <IonLabel position="stacked">User ID</IonLabel>
              <IonInput
                type="number"
                placeholder="e.g. 1"
                value={uidInput}
                onIonInput={(e) => setUidInput(e.detail.value ?? '')}
              />
            </IonItem>
            <IonItem>
              <IonButton onClick={handleSave}>
                Save
              </IonButton>
            </IonItem>
          </IonList>
        </div>
      </IonContent>
    </IonPage>
  );
}
