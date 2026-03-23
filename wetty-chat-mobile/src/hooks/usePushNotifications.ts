import { useCallback, useEffect, useState } from 'react';
import apiClient from '@/api/client';
import { initializeClientId } from '@/utils/clientId';

// Helper to convert base64 to Uint8Array for Web Push manager
function urlBase64ToUint8Array(base64String: string) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');

  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);

  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

export type PushNotificationErrorCode =
  | 'unsupported_browser'
  | 'permission_denied'
  | 'service_worker_unavailable'
  | 'subscribe_failed'
  | 'unsubscribe_failed'
  | 'backend_subscribe_failed';

export type PushNotificationResult = { ok: true } | { ok: false; code: PushNotificationErrorCode; message: string };

function success(): PushNotificationResult {
  return { ok: true };
}

function failure(code: PushNotificationErrorCode, message: string): PushNotificationResult {
  return { ok: false, code, message };
}

function getErrorMessage(error: unknown, fallback: string) {
  if (error instanceof Error && error.message) {
    return error.message;
  }

  if (typeof error === 'string' && error) {
    return error;
  }

  return fallback;
}

function checkPushSupport(): PushNotificationResult {
  if (!('Notification' in window) || !('serviceWorker' in navigator) || !('PushManager' in window)) {
    return failure('unsupported_browser', 'Push notifications are not supported in this browser');
  }

  return success();
}

function encodeSubscriptionKeys(subscription: PushSubscription) {
  const p256dh = btoa(String.fromCharCode.apply(null, Array.from(new Uint8Array(subscription.getKey('p256dh')!))));
  const auth = btoa(String.fromCharCode.apply(null, Array.from(new Uint8Array(subscription.getKey('auth')!))));
  return {
    p256dh: p256dh.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''),
    auth: auth.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''),
  };
}

function syncSubscriptionWithBackend(subscription: PushSubscription) {
  initializeClientId();
  const keys = encodeSubscriptionKeys(subscription);
  apiClient
    .post('/push/subscribe', {
      endpoint: subscription.endpoint,
      keys,
    })
    .catch((err) => {
      console.warn('Failed to sync push subscription with backend', err);
    });
}

export function usePushNotifications() {
  const [permission, setPermission] = useState<NotificationPermission>('default');
  const [isSubscribed, setIsSubscribed] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    initializeClientId();
    if ('Notification' in window) {
      setPermission(Notification.permission);
    }

    // Check if already subscribed in SW, and re-sync with backend
    if ('serviceWorker' in navigator && 'PushManager' in window) {
      navigator.serviceWorker.ready.then(async (registration) => {
        const subscription = await registration.pushManager.getSubscription();
        setIsSubscribed(!!subscription);
        if (subscription) {
          syncSubscriptionWithBackend(subscription);
        }
      });
    }
  }, []);

  const requestPermission = useCallback(async (): Promise<PushNotificationResult> => {
    const supportResult = checkPushSupport();
    if (!supportResult.ok) {
      return supportResult;
    }

    const perm = await Notification.requestPermission();
    setPermission(perm);

    if (perm !== 'granted') {
      return failure('permission_denied', 'Notification permission not granted');
    }

    return success();
  }, []);

  const subscribeToPush = useCallback(async () => {
    setLoading(true);
    try {
      const supportResult = checkPushSupport();
      if (!supportResult.ok) {
        return supportResult;
      }

      if (permission !== 'granted') {
        const permissionResult = await requestPermission();
        if (!permissionResult.ok) {
          return permissionResult;
        }
      }

      let registration: ServiceWorkerRegistration;
      try {
        registration = await navigator.serviceWorker.ready;
      } catch (error) {
        console.error('Service Worker ready failed', error);
        return failure('service_worker_unavailable', getErrorMessage(error, 'Service Worker unavailable'));
      }

      // Get VAPID public key
      const vapidRes = await apiClient.get('/push/vapid-public-key');
      const publicKey = urlBase64ToUint8Array(vapidRes.data.public_key);

      const existingSubscription = await registration.pushManager.getSubscription();
      const subscription =
        existingSubscription ??
        (await registration.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: publicKey,
        }));

      // Send to backend
      const keys = encodeSubscriptionKeys(subscription);
      try {
        await apiClient.post('/push/subscribe', {
          endpoint: subscription.endpoint,
          keys,
        });
      } catch (backendError) {
        console.error('Backend subscription failed, rolling back browser subscription', backendError);
        if (!existingSubscription) {
          await subscription.unsubscribe();
        }
        return failure('backend_subscribe_failed', getErrorMessage(backendError, 'Failed to subscribe on the server'));
      }

      setIsSubscribed(true);
      return success();
    } catch (e) {
      console.error('Failed to subscribe to push', e);
      return failure('subscribe_failed', getErrorMessage(e, 'Failed to subscribe to push notifications'));
    } finally {
      setLoading(false);
    }
  }, [permission, requestPermission]);

  const unsubscribeFromPush = useCallback(async () => {
    setLoading(true);
    try {
      const supportResult = checkPushSupport();
      if (!supportResult.ok) {
        return supportResult;
      }

      let registration: ServiceWorkerRegistration;
      try {
        registration = await navigator.serviceWorker.ready;
      } catch (error) {
        console.error('Service Worker ready failed', error);
        return failure('service_worker_unavailable', getErrorMessage(error, 'Service Worker unavailable'));
      }

      const subscription = await registration.pushManager.getSubscription();

      if (subscription) {
        // Attempt to notify backend
        try {
          await apiClient.post('/push/unsubscribe', {
            endpoint: subscription.endpoint,
          });
        } catch (err) {
          console.warn('Failed to unsubscribe on backend, but proceeding to remove local subscription', err);
        }

        await subscription.unsubscribe();
      }

      setIsSubscribed(false);
      return success();
    } catch (e) {
      console.error('Failed to unsubscribe', e);
      return failure('unsubscribe_failed', getErrorMessage(e, 'Failed to unsubscribe from push notifications'));
    } finally {
      setLoading(false);
    }
  }, []);

  return {
    permission,
    isSubscribed,
    loading,
    requestPermission,
    subscribeToPush,
    unsubscribeFromPush,
  };
}
