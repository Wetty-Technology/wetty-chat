export const NOTIFICATION_BOOTSTRAP_PATH = '/push-open';
const DEFAULT_NOTIFICATION_TARGET = '/chats';
const INTERNAL_TARGET_PATTERN = /^\/(?:chats|settings|demo)(?:\/|$)/;

export interface NotificationNavigationData {
  chatId?: string;
  messageId?: string;
  target?: string;
}

export interface NotificationOpenMessage {
  type: 'OPEN_NOTIFICATION_TARGET';
  chatId?: string;
  target?: string;
}

function normalizeNotificationTarget(target: string | null | undefined): string | null {
  if (typeof target !== 'string') {
    return null;
  }

  const trimmed = target.trim();
  if (!trimmed.startsWith('/') || trimmed.startsWith(NOTIFICATION_BOOTSTRAP_PATH)) {
    return null;
  }

  return INTERNAL_TARGET_PATTERN.test(trimmed) ? trimmed : null;
}

export function buildNotificationChatTarget(chatId: string | null | undefined): string | null {
  if (typeof chatId !== 'string') {
    return null;
  }

  const trimmed = chatId.trim();
  if (!trimmed) {
    return null;
  }

  return `/chats/chat/${encodeURIComponent(trimmed)}`;
}

export function resolveNotificationTarget({
  chatId,
  target,
}: {
  chatId?: string | null;
  target?: string | null;
}): string {
  return buildNotificationChatTarget(chatId) ?? normalizeNotificationTarget(target) ?? DEFAULT_NOTIFICATION_TARGET;
}

export function buildNotificationLaunchUrl(scope: string, target: string): string {
  const launchUrl = new URL('push-open', scope);
  launchUrl.searchParams.set('target', target);
  return launchUrl.toString();
}

export function buildNotificationNavigationData({
  chatId,
  messageId,
  target,
}: NotificationNavigationData): NotificationNavigationData {
  return {
    ...(chatId ? { chatId } : {}),
    ...(messageId ? { messageId } : {}),
    ...(target ? { target } : {}),
  };
}

export function extractNotificationNavigationData(data: unknown): NotificationNavigationData {
  if (!data || typeof data !== 'object') {
    console.warn('[notification] invalid notification data payload', { data });
    return {};
  }

  const candidate = data as NotificationNavigationData;
  const hasChatId = 'chatId' in candidate;
  const hasMessageId = 'messageId' in candidate;
  const hasTarget = 'target' in candidate;

  if (hasChatId && typeof candidate.chatId !== 'string') {
    console.warn('[notification] invalid chatId in notification payload', { data });
    return {};
  }

  if (hasMessageId && typeof candidate.messageId !== 'string') {
    console.warn('[notification] invalid messageId in notification payload', { data });
    return {};
  }

  if (hasTarget && typeof candidate.target !== 'string') {
    console.warn('[notification] invalid target in notification payload', { data });
    return {};
  }

  return {
    chatId: candidate.chatId,
    messageId: candidate.messageId,
    target: candidate.target,
  };
}
