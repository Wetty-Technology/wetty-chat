import { IonBackButton, IonButton, IonIcon } from '@ionic/react';
import { arrowBack, close } from 'ionicons/icons';
import type { BackAction } from '@/types/back-action';

interface BackButtonProps {
  action: BackAction;
}

export function BackButton({ action }: BackButtonProps) {
  if (action.type === 'back') {
    return <IonBackButton defaultHref={action.defaultHref} text="" />;
  }
  if (action.type === 'callback') {
    return (
      <IonButton fill="clear" onClick={action.onBack}>
        <IonIcon slot="icon-only" icon={arrowBack} />
      </IonButton>
    );
  }
  return (
    <IonButton fill="clear" onClick={action.onClose}>
      <IonIcon slot="icon-only" icon={close} />
    </IonButton>
  );
}
