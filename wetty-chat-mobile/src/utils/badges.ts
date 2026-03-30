import { getUnreadCount } from '@/api/chats';

type BadgeCapable = {
  setAppBadge?: (contents?: number) => Promise<void>;
  clearAppBadge?: () => Promise<void>;
};

export function setAppBadgeCount(target: BadgeCapable, count: number) {
  return target.setAppBadge?.(count);
}

export function clearAppBadgeCount(target: BadgeCapable) {
  return target.clearAppBadge?.();
}

let latestBadgeSyncRequestId = 0;

export async function syncAppBadgeCount(target: BadgeCapable | undefined = globalThis.navigator): Promise<void> {
  const requestId = ++latestBadgeSyncRequestId;

  try {
    const res = await getUnreadCount();
    if (requestId !== latestBadgeSyncRequestId) return;

    if (res.data.unreadCount > 0) {
      await setAppBadgeCount(target ?? {}, res.data.unreadCount);
      return;
    }

    await clearAppBadgeCount(target ?? {});
  } catch (error) {
    if (requestId !== latestBadgeSyncRequestId) return;
    console.error('Failed to sync app badge', error);
  }
}
