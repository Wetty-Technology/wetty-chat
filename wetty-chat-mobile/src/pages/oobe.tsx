import {
  IonAvatar,
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
} from '@ionic/react';
import { useHistory } from 'react-router-dom';
import { useSelector } from 'react-redux';
import type { RootState } from '@/store';
import { usePushNotifications } from '@/hooks/usePushNotifications';
import './oobe.scss';

const OOBE_STORAGE_KEY = 'oobe';

function getInitial(name: string | null) {
  return (name?.trim().charAt(0) || 'W').toUpperCase();
}

export default function OobePage() {
  const history = useHistory();
  const { username, avatar_url } = useSelector((state: RootState) => state.user);
  const { isSubscribed, loading, subscribeToPush, unsubscribeFromPush } = usePushNotifications();

  const handleToggle = async (enabled: boolean) => {
    if (enabled) {
      await subscribeToPush();
      return;
    }
    await unsubscribeFromPush();
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
            <IonAvatar className="oobe-avatar">
              {avatar_url ? (
                <img src={avatar_url} alt={username ?? 'User avatar'} />
              ) : (
                <div className="oobe-avatar__fallback">{getInitial(username)}</div>
              )}
            </IonAvatar>

            <IonText>
              <h1 className="oobe-title">欢迎，{username ?? 'Wetty 用户'}</h1>
            </IonText>

            <IonList inset={true}>
              <IonItem lines="none">
                <IonLabel>
                  <h2>是否开启通知</h2>
                  <IonNote color="medium">后面可以随时在设置里更改</IonNote>
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
