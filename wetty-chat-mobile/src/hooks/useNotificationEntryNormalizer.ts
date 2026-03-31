import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { appHistory } from '@/utils/navigationHistory';
import { NOTIFICATION_QUERY_PARAM } from '@/utils/notificationNavigation';

const CHAT_ROUTE_PREFIX = '/chats/chat/';

function buildNormalizedTarget(location: ReturnType<typeof useLocation>): string {
  const params = new URLSearchParams(location.search);
  params.delete(NOTIFICATION_QUERY_PARAM);
  const search = params.toString();
  return `${location.pathname}${search ? `?${search}` : ''}${location.hash}`;
}

export function useNotificationEntryNormalizer(isDesktop: boolean): void {
  const location = useLocation();

  useEffect(() => {
    const params = new URLSearchParams(location.search);
    if (params.get(NOTIFICATION_QUERY_PARAM) !== '1') {
      return;
    }

    const target = buildNormalizedTarget(location);

    console.debug('[app] normalizing notification entry', {
      isDesktop,
      pathname: location.pathname,
      search: location.search,
      target,
    });

    if (isDesktop || !location.pathname.startsWith(CHAT_ROUTE_PREFIX)) {
      appHistory.replace(target);
      return;
    }

    appHistory.replace('/chats');
    window.setTimeout(() => {
      if (appHistory.location.pathname !== target) {
        appHistory.push(target);
      }
    }, 0);
  }, [isDesktop, location]);
}
