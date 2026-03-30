import {
  IonButton,
  IonContent,
  IonHeader,
  IonItem,
  IonLabel,
  IonList,
  IonNote,
  IonPage,
  IonText,
  IonTitle,
  IonToggle,
  IonToolbar,
  useIonToast,
} from '@ionic/react';
import { useHistory } from 'react-router-dom';
import { useSelector } from 'react-redux';
import type { RootState } from '@/store';
import { type PushNotificationErrorCode, usePushNotifications } from '@/hooks/usePushNotifications';
import { t } from '@lingui/core/macro';
import { UserAvatar } from '@/components/UserAvatar';
import './oobe.scss';

const OOBE_STORAGE_KEY = 'oobe';

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

export default function OobePage() {
  const history = useHistory();
  const { username, avatarUrl } = useSelector((state: RootState) => state.user);
  const [presentToast] = useIonToast();
  const { isSubscribed, loading, subscribeToPush, unsubscribeFromPush } = usePushNotifications();

  const handleToggle = async (enabled: boolean) => {
    if (enabled) {
      const result = await subscribeToPush();
      if (!result.ok) {
        presentToast({ message: getPushErrorMessage(result.code), duration: 3000, position: 'bottom' });
      }
      return;
    }

    const result = await unsubscribeFromPush();
    if (!result.ok) {
      presentToast({ message: getPushErrorMessage(result.code), duration: 3000, position: 'bottom' });
    }
  };

  const handleStart = () => {
    localStorage.setItem(OOBE_STORAGE_KEY, '1');
    history.replace('/chats');
  };

  return (
    <IonPage>
      <IonHeader translucent={true}>
        <IonToolbar>
          <IonTitle>欢迎</IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent fullscreen={true}>
        <div className="oobe-shell">
          <div className="oobe-card">
            <UserAvatar name={username ?? 'W'} avatarUrl={avatarUrl} size={88} className="oobe-avatar" />

            <IonText>
              <h1 className="oobe-title">欢迎，{username ?? 'Wetty 用户'}</h1>
            </IonText>

            <IonList inset={true}>
              <IonItem lines="none">
                <IonLabel>
                  <h2>是否开启通知</h2>
                  <IonNote color="medium">以后可以随时在设置里更改</IonNote>
                </IonLabel>
                <IonToggle
                  slot="end"
                  checked={isSubscribed}
                  disabled={loading}
                  onIonChange={(event) => {
                    handleToggle(event.detail.checked);
                  }}
                />
              </IonItem>
            </IonList>

            <IonButton expand="block" size="large" onClick={handleStart}>
              开始聊天
            </IonButton>
          </div>
        </div>
      </IonContent>
    </IonPage>
  );
}
