import { IonContent, IonPage } from '@ionic/react';
import { useEffect, useMemo } from 'react';
import { useLocation } from 'react-router-dom';
import { resolveNotificationTarget } from '@/utils/notificationNavigation';
import { navigateToNotificationTarget } from '@/utils/notificationTargetNavigator';

interface PushOpenPageProps {
  isDesktop: boolean;
}

export default function PushOpenPage({ isDesktop }: PushOpenPageProps) {
  const location = useLocation();
  const target = useMemo(() => {
    const params = new URLSearchParams(location.search);

    return resolveNotificationTarget({
      chatId: params.get('chatId'),
      target: params.get('target'),
    });
  }, [location.search]);

  useEffect(() => {
    console.debug('[app] push-open route mounted', {
      target,
      isDesktop,
      search: location.search,
      pathname: location.pathname,
    });
    navigateToNotificationTarget(target, isDesktop);
  }, [isDesktop, location.pathname, location.search, target]);

  return (
    <IonPage>
      <IonContent fullscreen={true} />
    </IonPage>
  );
}
