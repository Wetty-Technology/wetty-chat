import { IonButtons, IonCard, IonCardContent, IonContent, IonHeader, IonPage, IonTitle, IonToolbar } from '@ionic/react';
import { Trans } from '@lingui/react/macro';
import { useHistory, useParams } from 'react-router-dom';
import { BackButton } from '@/components/BackButton';
import { InvitePreviewCard } from '@/components/invites/InvitePreviewCard';
import type { BackAction } from '@/types/back-action';
import styles from './invite-preview.module.scss';

interface InvitePreviewPageProps {
  inviteCode?: string;
  backAction?: BackAction;
}

export function InvitePreviewCore({ inviteCode: inviteCodeProp, backAction }: InvitePreviewPageProps) {
  const history = useHistory();
  const { inviteCode: inviteCodeParam } = useParams<{ inviteCode?: string }>();
  const inviteCode = inviteCodeProp ?? inviteCodeParam ?? '';

  if (!inviteCode) {
    return null;
  }

  return (
    <div className={`ion-page ${styles.page}`}>
      <IonHeader translucent={true}>
        <IonToolbar>
          <IonButtons slot="start">
            {backAction && <BackButton action={backAction} />}
          </IonButtons>
          <IonTitle>
            <Trans>Invite</Trans>
          </IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent>
        <IonCard className={styles.card}>
          <IonCardContent className={styles.cardContent}>
            <InvitePreviewCard
              inviteCode={inviteCode}
              onResolved={(chat) => history.replace(`/chats/chat/${chat.id}`)}
              onCancel={() => history.replace('/chats')}
            />
          </IonCardContent>
        </IonCard>
      </IonContent>
    </div>
  );
}

export default function InvitePreviewPage(props: InvitePreviewPageProps) {
  return (
    <IonPage>
      <InvitePreviewCore backAction={{ type: 'back', defaultHref: '/chats' }} {...props} />
    </IonPage>
  );
}
