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
  useIonToast,
  IonListHeader,
  IonIcon,
  IonNote,
} from '@ionic/react';
import { useHistory } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { selectLocale } from '@/store/settingsSlice';
import { setCurrentUserId } from '@/js/current-user';
import type { RootState } from '@/store/index';
import { Trans } from '@lingui/react/macro';
import { FeatureGate } from '@/components/FeatureGate';

import { usePushNotifications } from '@/hooks/usePushNotifications';
import { t } from '@lingui/core/macro';
import { language, codeWorking, notifications, informationCircle, logIn, logOut } from 'ionicons/icons';

export default function Settings() {
  const currentUid = useSelector((state: RootState) => state.user.uid);
  const [uidInput, setUidInput] = useState(String(currentUid || '1'));
  const [presentToast] = useIonToast();
  const history = useHistory();
  const locale = useSelector(selectLocale);
  const { permission, isSubscribed, loading, subscribeToPush, unsubscribeFromPush } = usePushNotifications();

  useEffect(() => {
    setUidInput(String(currentUid || '1'));
  }, [currentUid]);

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
      <IonContent color="light" className="ion-no-padding">
        <IonListHeader>
          <IonLabel><Trans>General</Trans></IonLabel>
        </IonListHeader>
        <IonList inset>
          <IonItem button detail={true} onClick={() => history.push('/settings/language')}>
            <IonIcon aria-hidden="true" icon={language} slot="start" color="primary" />
            <IonLabel><Trans>Language</Trans></IonLabel>
            <IonNote slot="end" color="medium">{{ 'en': 'English', 'zh-CN': '简体中文', 'zh-TW': '繁體中文' }[locale!] ?? t`Auto`}</IonNote>
          </IonItem>
        </IonList>

        <FeatureGate>
          <IonListHeader>
            <IonLabel>Developer</IonLabel>
          </IonListHeader>
          <IonList inset={true}>
            <IonItem>
              <IonIcon aria-hidden="true" icon={codeWorking} slot="start" color="medium" />
              <IonInput
                label="User ID"
                type="number"
                placeholder="e.g. 1"
                value={uidInput}
                onIonInput={(e) => setUidInput(e.detail.value ?? '')}
                className="ion-text-right"
              />
            </IonItem>
            <IonItem button onClick={handleSave} detail={false}>
              <IonLabel color="primary">Save</IonLabel>
            </IonItem>
          </IonList>
        </FeatureGate>

        <IonListHeader>
          <IonLabel>Push Notifications</IonLabel>
        </IonListHeader>
        <IonList inset={true}>
          <IonItem>
            <IonIcon aria-hidden="true" icon={notifications} slot="start" color="tertiary" />
            <IonLabel>Status</IonLabel>
            <IonNote slot="end" color="medium">{isSubscribed ? 'Subscribed' : 'Not Subscribed'}</IonNote>
          </IonItem>
          {permission !== 'granted' && (
            <IonItem>
              <IonLabel>Permission</IonLabel>
              <IonNote slot="end" color="medium">{permission}</IonNote>
            </IonItem>
          )}
          {!isSubscribed ? (
            <IonItem button detail={false} onClick={subscribeToPush} disabled={loading || isSubscribed}>
              <IonIcon aria-hidden="true" icon={logIn} slot="start" color="primary" />
              <IonLabel color="primary">Subscribe to Push</IonLabel>
            </IonItem>
          ) : (
            <IonItem button detail={false} onClick={unsubscribeFromPush} disabled={loading || !isSubscribed}>
              <IonIcon aria-hidden="true" icon={logOut} slot="start" color="danger" />
              <IonLabel color="danger">Unsubscribe</IonLabel>
            </IonItem>
          )}
        </IonList>

        <IonListHeader>
          <IonLabel>About</IonLabel>
        </IonListHeader>
        <IonList inset={true}>
          <IonItem>
            <IonIcon aria-hidden="true" icon={informationCircle} slot="start" color="secondary" />
            <IonLabel>Version</IonLabel>
            <IonNote slot="end" color="medium" style={{ fontFamily: 'monospace' }}>{__APP_VERSION__}</IonNote>
          </IonItem>
        </IonList>
      </IonContent>
    </IonPage>
  );
}
