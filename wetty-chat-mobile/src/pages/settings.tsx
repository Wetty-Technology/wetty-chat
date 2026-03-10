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
import { FeatureGate } from '@/components/FeatureGate';

import { usePushNotifications } from '@/hooks/usePushNotifications';
import { t } from '@lingui/core/macro';

export default function Settings() {
  const [uidInput, setUidInput] = useState(String(getCurrentUserId()));
  const [presentToast] = useIonToast();
  const history = useHistory();
  const locale = useSelector(selectLocale);
  const { permission, isSubscribed, loading, subscribeToPush, unsubscribeFromPush } = usePushNotifications();

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
              <IonLabel><Trans>Language</Trans></IonLabel>
              <span slot="end">{{ 'en': 'English', 'zh-CN': '简体中文', 'zh-TW': '繁體中文' }[locale!] ?? t`Auto`}</span>
            </IonItem>
            <FeatureGate>
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
            </FeatureGate>

            <IonItem lines="none" style={{ marginTop: '16px' }}>
              <IonLabel color="medium"><h2>Push Notifications</h2></IonLabel>
            </IonItem>
            <IonItem>
              <IonLabel>
                <p>Permission: {permission}</p>
                <p>Status: {isSubscribed ? 'Subscribed' : 'Not Subscribed'}</p>
              </IonLabel>
            </IonItem>
            <IonItem lines="none">
              <IonButton onClick={subscribeToPush} disabled={loading || isSubscribed}>
                Subscribe
              </IonButton>
              <IonButton onClick={unsubscribeFromPush} disabled={loading || !isSubscribed} color="danger">
                Unsubscribe
              </IonButton>
            </IonItem>

          </IonList>
        </div>
      </IonContent>
    </IonPage >
  );
}
