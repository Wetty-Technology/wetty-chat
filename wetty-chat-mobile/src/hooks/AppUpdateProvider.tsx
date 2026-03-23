import { type ReactNode, useEffect, useRef, useState } from 'react';
import { useRegisterSW } from 'virtual:pwa-register/react';
import { AppUpdateContext, type CheckForUpdateResult } from './appUpdateContext';

function waitForServiceWorkerUpdate(
  registration: ServiceWorkerRegistration,
  hasPendingUpdate: () => boolean,
  timeoutMs = 5000,
): Promise<boolean> {
  if (registration.waiting || hasPendingUpdate()) {
    return Promise.resolve(true);
  }

  return new Promise((resolve) => {
    let installingWorker: ServiceWorker | null = null;
    let timeoutId = 0;

    const finish = (foundUpdate: boolean) => {
      window.clearTimeout(timeoutId);
      registration.removeEventListener('updatefound', handleUpdateFound);
      installingWorker?.removeEventListener('statechange', handleStateChange);
      resolve(foundUpdate || hasPendingUpdate() || Boolean(registration.waiting));
    };

    const handleStateChange = () => {
      if (!installingWorker) {
        return;
      }

      if (installingWorker.state === 'installed') {
        finish(Boolean(navigator.serviceWorker.controller));
        return;
      }

      if (installingWorker.state === 'redundant') {
        finish(false);
      }
    };

    const watchInstallingWorker = (worker: ServiceWorker | null) => {
      if (!worker || worker === installingWorker) {
        return;
      }

      installingWorker?.removeEventListener('statechange', handleStateChange);
      installingWorker = worker;

      if (installingWorker.state === 'installed') {
        finish(Boolean(navigator.serviceWorker.controller));
        return;
      }

      installingWorker.addEventListener('statechange', handleStateChange);
    };

    const handleUpdateFound = () => {
      watchInstallingWorker(registration.installing);
    };

    timeoutId = window.setTimeout(() => finish(false), timeoutMs);
    registration.addEventListener('updatefound', handleUpdateFound);
    watchInstallingWorker(registration.installing);
  });
}

export function AppUpdateProvider({ children }: { children: ReactNode }) {
  const {
    needRefresh: [needRefresh, setNeedRefresh],
    updateServiceWorker,
  } = useRegisterSW({
    onRegistered(r: unknown) {
      console.log('SW Registered: ', r);
    },
    onRegisterError(error: unknown) {
      console.log('SW registration error', error);
    },
  });

  const [checkingForUpdate, setCheckingForUpdate] = useState(false);
  const needRefreshRef = useRef(needRefresh);

  useEffect(() => {
    needRefreshRef.current = needRefresh;
  }, [needRefresh]);

  const checkForUpdate = async (): Promise<CheckForUpdateResult> => {
    setCheckingForUpdate(true);

    try {
      if (!navigator.serviceWorker) {
        return 'no-service-worker';
      }

      const registration = await navigator.serviceWorker.getRegistration();
      if (!registration) {
        return 'no-service-worker';
      }

      if (registration.waiting || needRefreshRef.current) {
        return 'update-found';
      }

      const updateFoundPromise = waitForServiceWorkerUpdate(registration, () => needRefreshRef.current);

      await registration.update();

      return (await updateFoundPromise) ? 'update-found' : 'no-update';
    } catch {
      return 'failed';
    } finally {
      setCheckingForUpdate(false);
    }
  };

  return (
    <AppUpdateContext.Provider
      value={{
        needRefresh,
        setNeedRefresh,
        updateServiceWorker,
        checkingForUpdate,
        checkForUpdate,
      }}
    >
      {children}
    </AppUpdateContext.Provider>
  );
}
