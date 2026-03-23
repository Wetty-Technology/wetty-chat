import { IonSpinner, IonTitle } from '@ionic/react';
import { Trans } from '@lingui/react/macro';
import { useSelector } from 'react-redux';
import type { ReactNode } from 'react';
import type { RootState } from '@/store';
import styles from './TitleWithConnectionStatus.module.scss';

interface TitleWithConnectionStatusProps {
  children: ReactNode;
}

export function TitleWithConnectionStatus({ children }: TitleWithConnectionStatusProps) {
  const wsConnected = useSelector((state: RootState) => state.connection.wsConnected);

  return (
    <IonTitle>
      {wsConnected ? (
        children
      ) : (
        <span className={styles.reconnecting} role="status" aria-live="polite">
          <IonSpinner name="lines-small" />
          <span>
            <Trans>Reconnecting...</Trans>
          </span>
        </span>
      )}
    </IonTitle>
  );
}
