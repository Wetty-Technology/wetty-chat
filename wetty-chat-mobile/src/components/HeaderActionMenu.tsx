import { type ReactNode, useState } from 'react';
import { IonButton, IonIcon, IonItem, IonList, IonPopover } from '@ionic/react';
import { t } from '@lingui/core/macro';
import styles from './HeaderActionMenu.module.scss';

export interface HeaderActionMenuItem {
  id: string;
  label: ReactNode;
  onSelect: () => void;
}

interface HeaderActionMenuProps {
  actions: HeaderActionMenuItem[];
  icon: string;
  triggerAriaLabel?: string;
}

export function HeaderActionMenu({ actions, icon, triggerAriaLabel = t`Open chat actions` }: HeaderActionMenuProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [triggerEvent, setTriggerEvent] = useState<Event | undefined>();
  const [pendingAction, setPendingAction] = useState<(() => void) | null>(null);

  const handleDismiss = () => {
    setIsOpen(false);
  };

  const handleActionSelect = (action: HeaderActionMenuItem) => {
    setPendingAction(() => action.onSelect);
    setIsOpen(false);
  };

  const handleDidDismiss = () => {
    const action = pendingAction;
    setPendingAction(null);
    setTriggerEvent(undefined);
    if (action) {
      action();
    }
  };

  return (
    <>
      <IonButton
        fill="clear"
        aria-label={triggerAriaLabel}
        className={styles.triggerButton}
        onClick={(event) => {
          setTriggerEvent(event.nativeEvent);
          setIsOpen(true);
        }}
      >
        <IonIcon slot="icon-only" icon={icon} />
      </IonButton>
      <IonPopover
        isOpen={isOpen}
        event={triggerEvent}
        onDidDismiss={handleDidDismiss}
        onWillDismiss={handleDismiss}
        alignment="end"
        side="bottom"
        className={styles.popover}
      >
        <IonList inset={false} lines="none" className={styles.menuList}>
          {actions.map((action) => (
            <IonItem
              key={action.id}
              button
              detail={false}
              className={styles.menuItem}
              onClick={() => handleActionSelect(action)}
            >
              {action.label}
            </IonItem>
          ))}
        </IonList>
      </IonPopover>
    </>
  );
}
