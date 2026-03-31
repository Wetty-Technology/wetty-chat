/// <reference lib="webworker" />
import { cleanupOutdatedCaches, createHandlerBoundToURL, precacheAndRoute } from 'workbox-precaching';
import { NavigationRoute, registerRoute } from 'workbox-routing';
import { getHighWaterMark, kvGet, setHighWaterMark } from './utils/db';
import { formatNotificationBody, getNotificationPreviewLabels, type PreviewMessage } from './utils/messagePreview';
import {
  buildNotificationNavigationData,
  buildNotificationLaunchUrl,
  extractNotificationNavigationData,
  type NotificationNavigationData,
  resolveNotificationTarget,
  type NotificationOpenMessage,
} from './utils/notificationNavigation';

declare let self: ServiceWorkerGlobalScope;

interface PushPayload {
  type?: 'newMessage';
  title?: string;
  body?: string;
  senderName?: string;
  messagePreview?: PreviewMessage;
  data?: NotificationNavigationData;
}

async function updateHighWaterMarkIdb(chatId: string, messageId: string): Promise<void> {
  try {
    const id = BigInt(messageId);
    const current = await getHighWaterMark(chatId);
    if (current == null || id > BigInt(current)) {
      await setHighWaterMark(chatId, messageId);
    }
  } catch {
    /* non-numeric id, ignore */
  }
}

async function isAlreadyNotified(chatId: string, messageId: string): Promise<boolean> {
  try {
    const id = BigInt(messageId);
    const mark = await getHighWaterMark(chatId);
    return mark != null && id <= BigInt(mark);
  } catch {
    return false;
  }
}

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  if (event.data && event.data.type === 'NOTIFIED') {
    const { chatId, messageId } = event.data;
    if (chatId && messageId) {
      event.waitUntil(updateHighWaterMarkIdb(String(chatId), String(messageId)));
    }
  }
});

const manifest = self.__WB_MANIFEST;
precacheAndRoute(manifest);

// clean old assets
cleanupOutdatedCaches();

// Catch routing to index.html for SPA
let allowlist: undefined | RegExp[];
if (import.meta.env.DEV) {
  allowlist = [/^\/$/];
}

// Workaround for dev server: only register navigation route if index.html is precached
const hasPrecachedIndex = manifest.some((entry) => (typeof entry === 'string' ? entry : entry.url) === 'index.html');

if (hasPrecachedIndex) {
  registerRoute(
    new NavigationRoute(createHandlerBoundToURL('index.html'), {
      allowlist,
      denylist: [/^\/_api/],
    }),
  );
}

self.addEventListener('push', (event) => {
  if (!event.data) return;

  event.waitUntil(
    (async () => {
      try {
        const payload = event.data!.json() as PushPayload;
        const title = payload.title || 'New Message';
        let body = payload.body ?? '';

        if (payload.messagePreview) {
          try {
            const locale = await kvGet<string>('effective_locale');
            body = formatNotificationBody(
              payload.senderName ?? 'Someone',
              payload.messagePreview,
              getNotificationPreviewLabels(locale),
            );
          } catch (err) {
            console.error('Failed to localize push preview, using legacy body', err);
          }
        }

        const notificationData = buildNotificationNavigationData({
          chatId: payload.data?.chatId,
          messageId: payload.data?.messageId,
          target: payload.data?.target,
        });
        const chatId = notificationData.chatId;
        const messageId = notificationData.messageId;

        if (chatId && messageId && (await isAlreadyNotified(String(chatId), String(messageId)))) {
          return;
        }

        if (chatId && messageId) {
          await updateHighWaterMarkIdb(String(chatId), String(messageId));
        }

        const tag = messageId ? `msg_${messageId}` : undefined;

        await self.registration.showNotification(title, {
          body,
          icon: '/icon/pwa-192x192.png',
          badge: '/icon/pwa-64x64.png',
          tag,
          data: notificationData,
        });
      } catch (err) {
        console.error('Failed to parse push event payload', err);
      }
    })(),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const notificationData = extractNotificationNavigationData(event.notification.data);
  const target = resolveNotificationTarget({
    chatId: notificationData.chatId,
    target: notificationData.target,
  });
  const launchUrl = buildNotificationLaunchUrl(self.registration.scope, target);
  const message: NotificationOpenMessage = {
    type: 'OPEN_NOTIFICATION_TARGET',
    chatId: notificationData.chatId,
    target,
  };

  console.debug('[sw] notificationclick', {
    scope: self.registration.scope,
    target,
    notificationData,
    rawNotificationData: event.notification.data,
  });

  // Attempt to focus the app main window if it is open, else open it
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      const appClients = clientList.filter((client) => client.url.startsWith(self.registration.scope));
      const preferredClient =
        appClients.find((client) => client.visibilityState === 'visible') ?? appClients[0];

      console.debug('[sw] notificationclick clients', {
        totalClients: clientList.length,
        appClients: appClients.map((client) => ({
          url: client.url,
          visibilityState: client.visibilityState,
          focused: client.focused,
        })),
        preferredClient: preferredClient
          ? {
              url: preferredClient.url,
              visibilityState: preferredClient.visibilityState,
              focused: preferredClient.focused,
            }
          : null,
      });

      if (preferredClient && 'focus' in preferredClient) {
        console.debug('[sw] posting notification target to existing client', {
          url: preferredClient.url,
          target,
        });
        preferredClient.postMessage(message);
        return preferredClient.focus();
      }

      if (self.clients.openWindow) {
        console.debug('[sw] opening new client window', { launchUrl });
        return self.clients.openWindow(launchUrl);
      }
    }),
  );
});
