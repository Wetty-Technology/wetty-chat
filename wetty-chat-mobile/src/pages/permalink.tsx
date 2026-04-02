import { IonContent, IonPage, useIonToast } from '@ionic/react';
import { useEffect, useMemo } from 'react';
import { useParams } from 'react-router-dom';
import { t } from '@lingui/core/macro';
import { getMessage } from '@/api/messages';
import { decodePermalink } from '@/utils/permalinkUrl';
import { navigateToNotificationTarget } from '@/utils/notificationTargetNavigator';

interface PermalinkPageProps {
  isDesktop: boolean;
}

export default function PermalinkPage({ isDesktop }: PermalinkPageProps) {
  const { encoded } = useParams<{ encoded: string }>();
  const [presentToast] = useIonToast();

  const decoded = useMemo(() => {
    try {
      return decodePermalink(encoded);
    } catch {
      return null;
    }
  }, [encoded]);

  useEffect(() => {
    if (!decoded) {
      presentToast({ message: t`Invalid link`, duration: 2000, color: 'danger' });
      navigateToNotificationTarget('/chats', isDesktop);
      return;
    }

    const { chatId, messageId } = decoded;

    getMessage(chatId, messageId)
      .then((res) => {
        const msg = res.data;
        const threadRootId = msg.replyRootId;
        const target = threadRootId
          ? `/chats/chat/${encodeURIComponent(chatId)}/thread/${threadRootId}`
          : `/chats/chat/${encodeURIComponent(chatId)}`;

        const resumeToken = `${messageId}:${Date.now()}:${Math.random().toString(36).slice(2)}`;
        const state = {
          resumeRequest: { messageId, token: resumeToken },
        };

        navigateToNotificationTarget(target, isDesktop, state);
      })
      .catch((err) => {
        // 401 is handled by the axios interceptor (auth redirect)
        if (err?.response?.status !== 401) {
          presentToast({
            message: err?.response?.status === 404 ? t`Message not found` : t`Failed to open link`,
            duration: 2000,
            color: 'danger',
          });
          navigateToNotificationTarget('/chats', isDesktop);
        }
      });
  }, [decoded, isDesktop, presentToast]);

  return (
    <IonPage>
      <IonContent fullscreen={true} />
    </IonPage>
  );
}
