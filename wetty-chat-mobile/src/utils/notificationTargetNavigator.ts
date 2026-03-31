import { appHistory } from '@/utils/navigationHistory';

const DEFAULT_NOTIFICATION_TARGET = '/chats';

let pendingMobileNavigationId: number | null = null;

function clearPendingMobileNavigation() {
  if (pendingMobileNavigationId != null) {
    window.clearTimeout(pendingMobileNavigationId);
    pendingMobileNavigationId = null;
  }
}

export function navigateToNotificationTarget(target: string, isDesktop: boolean): void {
  clearPendingMobileNavigation();
  const currentPath = appHistory.location.pathname;

  console.debug('[app] navigateToNotificationTarget', {
    target,
    isDesktop,
    currentPath,
    historyLength: window.history.length,
  });

  if (currentPath === target) {
    console.debug('[app] notification target already active');
    return;
  }

  if (isDesktop) {
    console.debug('[app] replacing desktop route', { target });
    appHistory.replace(target);
    return;
  }

  if (target === DEFAULT_NOTIFICATION_TARGET) {
    console.debug('[app] replacing mobile route with chats root');
    appHistory.replace(DEFAULT_NOTIFICATION_TARGET);
    return;
  }

  console.debug('[app] rebuilding mobile stack for notification target', { target });
  appHistory.replace(DEFAULT_NOTIFICATION_TARGET);
  pendingMobileNavigationId = window.setTimeout(() => {
    pendingMobileNavigationId = null;
    if (appHistory.location.pathname !== target) {
      console.debug('[app] pushing mobile notification target after root replace', {
        currentPath: appHistory.location.pathname,
        target,
      });
      appHistory.push(target);
    }
  }, 0);
}
