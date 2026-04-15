import { useCallback, useEffect, useRef, useState } from 'react';

export function useNativeScrollActivity(
  containerRef: React.RefObject<HTMLElement | null>,
  graceMs = 1200,
  idleMs = 200,
) {
  const [active, setActive] = useState(false);
  const userUntilRef = useRef(0);
  const idleTimerRef = useRef<number | null>(null);

  const markIntent = useCallback(() => {
    userUntilRef.current = performance.now() + graceMs;
    setActive(true);
    if (idleTimerRef.current) {
      window.clearTimeout(idleTimerRef.current);
    }
    idleTimerRef.current = window.setTimeout(() => {
      setActive(false);
      idleTimerRef.current = null;
    }, idleMs);
  }, [graceMs, idleMs]);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;

    const onScroll = (e: Event) => {
      const now = performance.now();
      const isUser = (e as any).isTrusted || now <= userUntilRef.current;
      setActive(isUser);
      if (idleTimerRef.current) {
        window.clearTimeout(idleTimerRef.current);
      }
      idleTimerRef.current = window.setTimeout(() => {
        setActive(false);
        idleTimerRef.current = null;
      }, idleMs);
    };

    el.addEventListener('scroll', onScroll, { passive: true });
    return () => {
      el.removeEventListener('scroll', onScroll);
      if (idleTimerRef.current) {
        window.clearTimeout(idleTimerRef.current);
        idleTimerRef.current = null;
      }
    };
  }, [containerRef, idleMs]);

  useEffect(() => {
    return () => {
      if (idleTimerRef.current) {
        window.clearTimeout(idleTimerRef.current);
        idleTimerRef.current = null;
      }
    };
  }, []);

  return { active, markIntent };
}
