import { useCallback, useEffect, useMemo, useState, type CSSProperties } from 'react';

const KEYBOARD_OPEN_HEIGHT_DIFF = 120;
const KEYBOARD_CLOSED_HEIGHT_DIFF = 20;

export function useKeyboardViewport(isDesktop: boolean) {
  const [composeFocused, setComposeFocused] = useState(false);
  const [baselineViewportHeight, setBaselineViewportHeight] = useState<number>(
    () => window.visualViewport?.height ?? window.innerHeight,
  );
  const [viewportHeight, setViewportHeight] = useState<number>(
    () => window.visualViewport?.height ?? window.innerHeight,
  );

  useEffect(() => {
    if (isDesktop) return;

    const visualViewport = window.visualViewport;
    const getViewportHeight = () => visualViewport?.height ?? window.innerHeight;
    const updateViewportMetrics = () => {
      const nextViewportHeight = getViewportHeight();
      setViewportHeight(nextViewportHeight);
      if (!composeFocused) {
        setBaselineViewportHeight((prev) => Math.max(prev, nextViewportHeight));
      }
    };

    const target = visualViewport ?? window;
    target.addEventListener('resize', updateViewportMetrics);
    // iOS fires visualViewport scroll events when the keyboard pushes the viewport.
    if (visualViewport) {
      visualViewport.addEventListener('scroll', updateViewportMetrics);
    }

    return () => {
      target.removeEventListener('resize', updateViewportMetrics);
      if (visualViewport) {
        visualViewport.removeEventListener('scroll', updateViewportMetrics);
      }
    };
  }, [composeFocused, isDesktop]);

  const handleComposeFocusChange = useCallback((focused: boolean) => {
    setComposeFocused(focused);
  }, []);

  const isKeyboardOpen =
    !isDesktop && composeFocused && baselineViewportHeight - viewportHeight > KEYBOARD_OPEN_HEIGHT_DIFF;
  const keyboardFullyClosed =
    !isDesktop && !composeFocused && baselineViewportHeight - viewportHeight < KEYBOARD_CLOSED_HEIGHT_DIFF;

  const pageStyle = useMemo<CSSProperties | undefined>(() => {
    if (!isKeyboardOpen) return undefined;
    return {
      height: `${viewportHeight}px`,
      top: `${window.visualViewport?.offsetTop ?? 0}px`,
    };
  }, [isKeyboardOpen, viewportHeight]);

  return {
    handleComposeFocusChange,
    isKeyboardOpen,
    keyboardFullyClosed,
    pageStyle,
  };
}
