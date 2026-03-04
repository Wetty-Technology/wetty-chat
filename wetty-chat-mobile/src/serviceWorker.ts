/// <reference lib="webworker" />
import {
    cleanupOutdatedCaches,
    createHandlerBoundToURL,
    precacheAndRoute,
} from 'workbox-precaching';
import { NavigationRoute, registerRoute } from 'workbox-routing';

declare let self: ServiceWorkerGlobalScope;

self.addEventListener('message', (event) => {
    if (event.data && event.data.type === 'SKIP_WAITING') {
        self.skipWaiting();
    }
});

// self.__WB_MANIFEST is default injection point
precacheAndRoute(self.__WB_MANIFEST);

// clean old assets
cleanupOutdatedCaches();

// Catch routing to index.html for SPA
let allowlist: undefined | RegExp[];
if (import.meta.env.DEV) {
    allowlist = [/^\/$/];
}

// Workaround for dev server: only register navigation route if index.html is precached
const hasPrecachedIndex = self.__WB_MANIFEST.some(
    (entry) => (typeof entry === 'string' ? entry : entry.url) === 'index.html'
);

if (hasPrecachedIndex) {
    registerRoute(
        new NavigationRoute(createHandlerBoundToURL('index.html'), {
            allowlist,
            denylist: [/^\/_api/],
        })
    );
}

self.addEventListener('push', (event) => {
    if (event.data) {
        try {
            const payload = event.data.json();
            const title = payload.title || 'New Message';
            const body = payload.body;

            const promiseChain = self.registration.showNotification(title, {
                body: body,
                icon: '/appicon/icon-192.png',
                badge: '/appicon/icon-192.png', // Ideally should be a monochrome maskable icon
                data: payload
            });

            event.waitUntil(promiseChain);
        } catch (err) {
            console.error('Failed to parse push event payload', err);
        }
    }
});

self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    // Attempt to focus the app main window if it is open, else open it
    event.waitUntil(
        self.clients.matchAll({ type: 'window' }).then((clientList) => {
            for (const client of clientList) {
                if (client.url.startsWith(self.registration.scope) && 'focus' in client) {
                    return client.focus();
                }
            }
            if (self.clients.openWindow) {
                return self.clients.openWindow('/');
            }
        })
    );
});
