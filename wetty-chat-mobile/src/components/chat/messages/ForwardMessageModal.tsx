import { useCallback, useState } from 'react';
import {
  IonButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonModal,
  IonTitle,
  IonToolbar,
  useIonToast,
} from '@ionic/react';
import { Trans } from '@lingui/react/macro';
import { t } from '@lingui/core/macro';
import type { GroupSelectorItem } from '@/api/group';
import { GroupSelector } from '@/components/group-selector/GroupSelector';
import { forwardMessage, type MessageResponse } from '@/api/messages';

interface ForwardMessageModalProps {
  isOpen: boolean;
  onClose: () => void;
  message: MessageResponse;
  sourceChatId: string;
}

export function ForwardMessageModal({ isOpen, onClose, message, sourceChatId }: ForwardMessageModalProps) {
  const [presentToast] = useIonToast();
  const [forwarding, setForwarding] = useState(false);

  const showToast = useCallback(
    (msg: string, duration = 3000) => {
      presentToast({ message: msg, duration, position: 'bottom', cssClass: 'toast-center' });
    },
    [presentToast],
  );

  const handleSelect = useCallback(
    async (group: GroupSelectorItem) => {
      if (forwarding) return;
      setForwarding(true);
      try {
        await forwardMessage(group.id, message.id, {
          sourceChatId,
          clientGeneratedId: `cg_${Date.now()}_${Math.random().toString(36).slice(2)}`,
        });
        showToast(t`Message forwarded`, 2000);
        onClose();
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : t`Failed to forward message`;
        showToast(msg);
      } finally {
        setForwarding(false);
      }
    },
    [forwarding, message.id, onClose, showToast, sourceChatId],
  );

  return (
    <IonModal isOpen={isOpen} onDidDismiss={onClose} initialBreakpoint={0.5} breakpoints={[0, 0.5, 0.9]}>
      <IonHeader>
        <IonToolbar>
          <IonTitle>
            <Trans>Forward to</Trans>
          </IonTitle>
          <IonButtons slot="end">
            <IonButton onClick={onClose}>{t`Cancel`}</IonButton>
          </IonButtons>
        </IonToolbar>
      </IonHeader>
      <IonContent color="light">
        <GroupSelector scope="joined" onSelect={handleSelect} />
      </IonContent>
    </IonModal>
  );
}
