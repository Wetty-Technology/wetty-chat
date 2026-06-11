import { IonButton, IonButtons, IonHeader, IonIcon, IonProgressBar, IonTitle, IonToolbar } from '@ionic/react';
import { informationCircleOutline, notifications, notificationsOffOutline, people } from 'ionicons/icons';
import { BackButton } from '@/components/BackButton';
import type { BackAction } from '@/types/back-action';

interface ChatThreadHeaderProps {
  backAction?: BackAction;
  chatId: string;
  chatName: string;
  isMuted: boolean;
  threadId?: string;
  threadSubscribed: boolean | null;
  threadArchived: boolean;
  threadSubLoading: boolean;
  wsConnected: boolean;
  onOpenMembers: () => void;
  onOpenGroupInfo: () => void;
  onToggleThreadSubscription: () => void;
}

export function ChatThreadHeader({
  backAction,
  chatName,
  isMuted,
  threadId,
  threadSubscribed,
  threadArchived,
  threadSubLoading,
  wsConnected,
  onOpenMembers,
  onOpenGroupInfo,
  onToggleThreadSubscription,
}: ChatThreadHeaderProps) {
  return (
    <IonHeader>
      <IonToolbar>
        <IonButtons slot="start">{backAction && <BackButton action={backAction} />}</IonButtons>
        <IonTitle>
          <span className="chat-thread-title">
            <span>{chatName}</span>
            {isMuted && !threadId ? (
              <IonIcon aria-hidden="true" icon={notificationsOffOutline} className="chat-thread-title__icon" />
            ) : null}
          </span>
        </IonTitle>
        <IonButtons slot="end">
          {threadId ? (
            threadSubscribed != null && (
              <IonButton
                onClick={onToggleThreadSubscription}
                disabled={threadSubLoading}
                color={threadSubscribed && !threadArchived ? undefined : 'medium'}
              >
                <IonIcon
                  slot="icon-only"
                  icon={threadSubscribed && !threadArchived ? notifications : notificationsOffOutline}
                />
              </IonButton>
            )
          ) : (
            <>
              <IonButton onClick={onOpenMembers}>
                <IonIcon slot="icon-only" icon={people} />
              </IonButton>
              <IonButton onClick={onOpenGroupInfo}>
                <IonIcon slot="icon-only" icon={informationCircleOutline} />
              </IonButton>
            </>
          )}
        </IonButtons>
        {!wsConnected && <IonProgressBar type="indeterminate" />}
      </IonToolbar>
    </IonHeader>
  );
}
