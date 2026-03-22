import { IonText, useIonToast } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { useEffect, useRef } from 'react';
import { useDeviceToken } from '@/hooks/useDeviceToken';
import styles from './AppVersionItem.module.scss';

const TAP_RESET_TIMEOUT_MS = 2000;
const REQUIRED_TAP_COUNT = 5;

export function AppVersionItem() {
  const jwtToken = useDeviceToken();
  const [presentToast] = useIonToast();
  const tapCountRef = useRef(0);
  const timeoutIdRef = useRef<number | null>(null);

  useEffect(() => {
    return () => {
      if (timeoutIdRef.current !== null) {
        window.clearTimeout(timeoutIdRef.current);
      }
    };
  }, []);

  const resetTapSequence = () => {
    tapCountRef.current = 0;
    if (timeoutIdRef.current !== null) {
      window.clearTimeout(timeoutIdRef.current);
      timeoutIdRef.current = null;
    }
  };

  const scheduleTapReset = () => {
    if (timeoutIdRef.current !== null) {
      window.clearTimeout(timeoutIdRef.current);
    }

    timeoutIdRef.current = window.setTimeout(() => {
      tapCountRef.current = 0;
      timeoutIdRef.current = null;
    }, TAP_RESET_TIMEOUT_MS);
  };

  const handleVersionClick = () => {
    tapCountRef.current += 1;

    if (tapCountRef.current >= REQUIRED_TAP_COUNT) {
      presentToast({
        message: jwtToken || t`No JWT token available`,
        duration: 4000,
        position: 'bottom',
      });
      resetTapSequence();
      return;
    }

    scheduleTapReset();
  };

  return (
    <IonText
      color="medium"
      className={`${styles.version} ion-text-center ion-padding-bottom`}
      onClick={handleVersionClick}
    >
      {__APP_VERSION__}
    </IonText>
  );
}
