import { appHistory } from '@/utils/navigationHistory';

const DEFAULT_NOTIFICATION_TARGET = '/chats';
const THREAD_TARGET_RE = /^\/chats\/chat\/([^/]+)\/thread\/([^/]+)$/;

let pendingMobileNavigationIds: number[] = [];

function clearPendingMobileNavigation() {
  for (const id of pendingMobileNavigationIds) {
    window.clearTimeout(id);
  }
  pendingMobileNavigationIds = [];
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

  // For thread targets, build a 3-level back stack: /chats → /chats/chat/:id → /chats/chat/:id/thread/:threadId
  const threadMatch = THREAD_TARGET_RE.exec(target);
  if (threadMatch) {
    const chatPath = `/chats/chat/${threadMatch[1]}`;
    console.debug('[app] rebuilding mobile stack for thread notification target', { target, chatPath });
    appHistory.replace(DEFAULT_NOTIFICATION_TARGET);
    pendingMobileNavigationIds.push(
      window.setTimeout(() => {
        appHistory.push(chatPath);
        pendingMobileNavigationIds.push(
          window.setTimeout(() => {
            if (appHistory.location.pathname !== target) {
              appHistory.push(target);
            }
          }, 0),
        );
      }, 0),
    );
    return;
  }

  console.debug('[app] rebuilding mobile stack for notification target', { target });
  appHistory.replace(DEFAULT_NOTIFICATION_TARGET);
  pendingMobileNavigationIds.push(
    window.setTimeout(() => {
      if (appHistory.location.pathname !== target) {
        console.debug('[app] pushing mobile notification target after root replace', {
          currentPath: appHistory.location.pathname,
          target,
        });
        appHistory.push(target);
      }
    }, 0),
  );
}
