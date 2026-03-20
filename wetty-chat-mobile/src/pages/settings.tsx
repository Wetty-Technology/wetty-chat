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
  useIonToast,
  IonListHeader,
  IonIcon,
  IonNote,
  IonButtons,
  IonText,
} from '@ionic/react';
import { useHistory } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { setCurrentUserId } from '@/js/current-user';
import type { RootState } from '@/store/index';
import { Trans } from '@lingui/react/macro';
import { FeatureGate } from '@/components/FeatureGate';

import { usePushNotifications, type PushNotificationErrorCode } from '@/hooks/usePushNotifications';
import { t } from '@lingui/core/macro';
import { cog, codeWorking, notifications, logIn, logOut, refreshCircle } from 'ionicons/icons';
import { BackButton } from '@/components/BackButton';
import type { BackAction } from '@/types/back-action';

interface SettingsCoreProps {
  backAction?: BackAction;
  onOpenGeneral?: () => void;
}

function getPermissionLabel(permission: NotificationPermission) {
  switch (permission) {
    case 'granted':
      return t`Allowed`;
    case 'denied':
      return t`Blocked`;
    default:
      return t`Ask first`;
  }
}

function getPushErrorMessage(code: PushNotificationErrorCode) {
  switch (code) {
    case 'unsupported_browser':
      return t`Push notifications are not supported on this device`;
    case 'permission_denied':
      return t`Notification permission was not granted`;
    case 'service_worker_unavailable':
      return t`Push notifications are not available right now`;
    case 'backend_subscribe_failed':
      return t`Push notifications could not be enabled on the server`;
    case 'unsubscribe_failed':
      return t`Failed to turn off push notifications`;
    case 'subscribe_failed':
    default:
      return t`Failed to turn on push notifications`;
  }
}

export function SettingsCore({ backAction, onOpenGeneral }: SettingsCoreProps) {
  const currentUid = useSelector((state: RootState) => state.user.uid);
  const [uidInput, setUidInput] = useState(() => String(currentUid || '1'));
  const [presentToast] = useIonToast();
  const history = useHistory();
  const { permission, isSubscribed, loading, subscribeToPush, unsubscribeFromPush } = usePushNotifications();

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

  const handleOpenGeneral = () => {
    if (onOpenGeneral) {
      onOpenGeneral();
      return;
    }
    history.push('/settings/general');
  };

  const handleSubscribeToPush = async () => {
    const result = await subscribeToPush();
    if (result.ok) {
      presentToast({ message: t`Push notifications enabled`, duration: 2000, position: 'bottom' });
      return;
    }

    presentToast({ message: getPushErrorMessage(result.code), duration: 3000, position: 'bottom' });
  };

  const handleUnsubscribeFromPush = async () => {
    const result = await unsubscribeFromPush();
    if (result.ok) {
      presentToast({ message: t`Push notifications turned off`, duration: 2000, position: 'bottom' });
      return;
    }

    presentToast({ message: getPushErrorMessage(result.code), duration: 3000, position: 'bottom' });
  };

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            {backAction && <BackButton action={backAction} />}
          </IonButtons>
          <IonTitle><Trans>Settings</Trans></IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent color="light" className="ion-no-padding">
        <IonListHeader>
          <IonLabel><Trans>General</Trans></IonLabel>
        </IonListHeader>
        <IonList inset>
          <IonItem button detail={true} onClick={handleOpenGeneral}>
            <IonIcon aria-hidden="true" icon={cog} slot="start" color="primary" />
            <IonLabel><Trans>General</Trans></IonLabel>
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
          <IonLabel><Trans>Push Notifications</Trans></IonLabel>
        </IonListHeader>
        <IonList inset={true}>
          <IonItem>
            <IonIcon aria-hidden="true" icon={notifications} slot="start" color="tertiary" />
            <IonLabel><Trans>Status</Trans></IonLabel>
            <IonNote slot="end" color="medium">
              {isSubscribed ? t`Subscribed` : t`Not subscribed`}
            </IonNote>
          </IonItem>
          {permission !== 'granted' && (
            <IonItem>
              <IonLabel><Trans>Permission</Trans></IonLabel>
              <IonNote slot="end" color="medium">{getPermissionLabel(permission)}</IonNote>
            </IonItem>
          )}
          {!isSubscribed ? (
            <IonItem button detail={false} onClick={handleSubscribeToPush} disabled={loading || isSubscribed}>
              <IonIcon aria-hidden="true" icon={logIn} slot="start" color="primary" />
              <IonLabel color="primary"><Trans>Turn On Push Notifications</Trans></IonLabel>
            </IonItem>
          ) : (
            <IonItem button detail={false} onClick={handleUnsubscribeFromPush} disabled={loading || !isSubscribed}>
              <IonIcon aria-hidden="true" icon={logOut} slot="start" color="danger" />
              <IonLabel color="danger"><Trans>Turn Off Push Notifications</Trans></IonLabel>
            </IonItem>
          )}
        </IonList>

        <IonListHeader>
          <IonLabel><Trans>About</Trans></IonLabel>
        </IonListHeader>
        <IonList inset={true}>
          <IonItem button detail={false} onClick={async () => {
            try {
              if (navigator.serviceWorker) {
                const reg = await navigator.serviceWorker.getRegistration();
                if (reg) {
                  await reg.update();
                  presentToast({ message: t`Update check complete`, duration: 2000 });
                  return;
                }
              }
              presentToast({ message: t`No service worker registered`, duration: 2000 });
            } catch {
              presentToast({ message: t`Update check failed`, duration: 2000 });
            }
          }}>
            <IonIcon aria-hidden="true" icon={refreshCircle} slot="start" color="secondary" />
            <IonLabel color="primary"><Trans>Check for Update</Trans></IonLabel>
          </IonItem>
        </IonList>
        <IonText
          color="medium"
          className="ion-text-center ion-padding-bottom"
          style={{ display: 'block', fontSize: '0.875rem'}}
        >
          {__APP_VERSION__}
        </IonText>
      </IonContent>
    </IonPage>
  );
}

export default function Settings() {
  return <SettingsCore />;
}
