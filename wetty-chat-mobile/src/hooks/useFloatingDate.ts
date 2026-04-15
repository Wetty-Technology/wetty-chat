import { useEffect, useRef, useState } from 'react';
import { FLOATING_DATE_HIDE_DELAY_MS, FLOATING_DATE_FADE_MS } from '@/constants/ui';

export function useFloatingDateVisibility(
  hasDate: boolean,
  isScrolling: boolean,
  hideDelay = FLOATING_DATE_HIDE_DELAY_MS,
  fadeMs = FLOATING_DATE_FADE_MS,
) {
  const [visible, setVisible] = useState(false);
  const [fading, setFading] = useState(false);
  const hideTimerRef = useRef<number | null>(null);
  const fadeTimerRef = useRef<number | null>(null);
  const immediateTimerRef = useRef<number | null>(null);

  useEffect(() => {
    if (isScrolling) {
      if (hideTimerRef.current) {
        window.clearTimeout(hideTimerRef.current);
        hideTimerRef.current = null;
      }
      if (fadeTimerRef.current) {
        window.clearTimeout(fadeTimerRef.current);
        fadeTimerRef.current = null;
      }
      if (immediateTimerRef.current) {
        window.clearTimeout(immediateTimerRef.current);
        immediateTimerRef.current = null;
      }
      immediateTimerRef.current = window.setTimeout(() => {
        setFading(false);
        setVisible(!!hasDate);
        immediateTimerRef.current = null;
      }, 0);
      return;
    }

    if (!hasDate) {
      if (immediateTimerRef.current) {
        window.clearTimeout(immediateTimerRef.current);
        immediateTimerRef.current = null;
      }
      immediateTimerRef.current = window.setTimeout(() => {
        setVisible(false);
        setFading(false);
        immediateTimerRef.current = null;
      }, 0);
      return;
    }

    if (hideTimerRef.current) {
      window.clearTimeout(hideTimerRef.current);
      hideTimerRef.current = null;
    }

    hideTimerRef.current = window.setTimeout(() => {
      setFading(true);
      fadeTimerRef.current = window.setTimeout(() => {
        setFading(false);
        setVisible(false);
        fadeTimerRef.current = null;
      }, fadeMs);
      hideTimerRef.current = null;
    }, hideDelay);

    return () => {
      if (hideTimerRef.current) {
        window.clearTimeout(hideTimerRef.current);
        hideTimerRef.current = null;
      }
      if (fadeTimerRef.current) {
        window.clearTimeout(fadeTimerRef.current);
        fadeTimerRef.current = null;
      }
      if (immediateTimerRef.current) {
        window.clearTimeout(immediateTimerRef.current);
        immediateTimerRef.current = null;
      }
    };
  }, [hasDate, isScrolling, hideDelay, fadeMs]);

  return { visible, fading };
}
