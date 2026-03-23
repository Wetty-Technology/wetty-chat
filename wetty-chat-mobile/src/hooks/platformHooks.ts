import { isPlatform } from '@ionic/react';
import { useEffect, useState } from 'react';

const DESKTOP_QUERY = '(min-width: 900px)';

export function useIsDesktop(): boolean {
  const [isDesktop, setIsDesktop] = useState(() => window.matchMedia(DESKTOP_QUERY).matches);

  useEffect(() => {
    const mq = window.matchMedia(DESKTOP_QUERY);
    const handler = (e: MediaQueryListEvent) => setIsDesktop(e.matches);
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, []);

  return isDesktop;
}

const DARK_MODE_QUERY = '(prefers-color-scheme: dark)';

export function useIsDarkMode(): boolean {
  const [isDarkMode, setIsDarkMode] = useState(() => window.matchMedia(DARK_MODE_QUERY).matches);

  useEffect(() => {
    const mq = window.matchMedia(DARK_MODE_QUERY);
    const handler = (e: MediaQueryListEvent) => setIsDarkMode(e.matches);
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, []);

  return isDarkMode;
}

export function useIsPWA(): boolean {
  const [isPWA, setIsPWA] = useState(() => (typeof window !== 'undefined' ? isPlatform('pwa') : false));

  useEffect(() => {
    if (typeof window === 'undefined' || window.matchMedia == null) {
      return;
    }

    const mediaQuery = window.matchMedia('(display-mode: standalone)');
    const updateIsPWA = () => {
      setIsPWA(mediaQuery.matches || isPlatform('pwa'));
    };

    updateIsPWA();
    mediaQuery.addEventListener('change', updateIsPWA);

    return () => {
      mediaQuery.removeEventListener('change', updateIsPWA);
    };
  }, []);

  return isPWA;
}
