import { useState, useEffect, useCallback } from 'react';
import apiClient from '@/api/client';

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

export function usePushNotifications() {
    const [permission, setPermission] = useState<NotificationPermission>('default');
    const [isSubscribed, setIsSubscribed] = useState(false);
    const [loading, setLoading] = useState(false);

    useEffect(() => {
        if ('Notification' in window) {
            setPermission(Notification.permission);
        }

        // Check if already subscribed in SW
        if ('serviceWorker' in navigator && 'PushManager' in window) {
            navigator.serviceWorker.ready.then(async (registration) => {
                const subscription = await registration.pushManager.getSubscription();
                setIsSubscribed(!!subscription);
            });
        }
    }, []);

    const requestPermission = useCallback(async () => {
        if (!('Notification' in window)) {
            alert('This browser does not support desktop notification');
            return false;
        }
        const perm = await Notification.requestPermission();
        setPermission(perm);
        return perm === 'granted';
    }, []);

    const subscribeToPush = useCallback(async () => {
        setLoading(true);
        try {
            if (permission !== 'granted') {
                const granted = await requestPermission();
                if (!granted) {
                    throw new Error('Notification permission not granted');
                }
            }
            console.log('Permission granted');

            if (!('serviceWorker' in navigator)) {
                throw new Error('Service Worker not supported');
            }
            console.log('Service Worker supported');

            const registration = await navigator.serviceWorker.ready;
            console.log('Service Worker ready');

            // Get VAPID public key
            const vapidRes = await apiClient.get('/api/push/vapid-public-key');
            const publicKey = urlBase64ToUint8Array(vapidRes.data.public_key);

            // Subscribe to PushManager
            const subscription = await registration.pushManager.subscribe({
                userVisibleOnly: true,
                applicationServerKey: publicKey
            });

            // Extract keys and endpoint
            const p256dh = btoa(String.fromCharCode.apply(null, Array.from(new Uint8Array(subscription.getKey('p256dh')!))));
            const auth = btoa(String.fromCharCode.apply(null, Array.from(new Uint8Array(subscription.getKey('auth')!))));

            const p256dhUrlSafe = p256dh.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
            const authUrlSafe = auth.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

            // Send to backend
            try {
                await apiClient.post('/api/push/subscribe', {
                    endpoint: subscription.endpoint,
                    keys: {
                        p256dh: p256dhUrlSafe,
                        auth: authUrlSafe
                    }
                });
            } catch (backendError) {
                console.error('Backend subscription failed, rolling back browser subscription', backendError);
                await subscription.unsubscribe();
                throw backendError;
            }

            setIsSubscribed(true);
            return true;
        } catch (e) {
            console.error('Failed to subscribe to push', e);
            alert('Failed to subscribe: ' + e);
            return false;
        } finally {
            setLoading(false);
        }
    }, [permission, requestPermission]);

    const unsubscribeFromPush = useCallback(async () => {
        setLoading(true);
        try {
            if (!('serviceWorker' in navigator)) {
                throw new Error('Service Worker not supported');
            }
            const registration = await navigator.serviceWorker.ready;
            const subscription = await registration.pushManager.getSubscription();

            if (subscription) {
                // Attempt to notify backend
                try {
                    await apiClient.post('/api/push/unsubscribe', {
                        endpoint: subscription.endpoint
                    });
                } catch (err) {
                    console.warn('Failed to unsubscribe on backend, but proceeding to remove local subscription', err);
                }

                await subscription.unsubscribe();
            }

            setIsSubscribed(false);
            alert('Unsubscribed successfully');
        } catch (e) {
            console.error('Failed to unsubscribe', e);
            alert('Failed to unsubscribe: ' + e);
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
