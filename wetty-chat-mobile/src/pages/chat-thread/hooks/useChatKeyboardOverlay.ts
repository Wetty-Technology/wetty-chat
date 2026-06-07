import { useCallback, useEffect, useRef, useState, type CSSProperties } from 'react';
import type { MessageResponse } from '@/api/messages';

const KEYBOARD_OPEN_HEIGHT_DIFF = 120;
const KEYBOARD_CLOSED_HEIGHT_DIFF = 20;

export interface ChatOverlayMessage {
  message: MessageResponse;
  sourceRect: DOMRect;
  interactionPos?: { x: number; y: number };
}

function getViewportHeight(): number {
  if (typeof window === 'undefined') return 0;
  return window.visualViewport?.height ?? window.innerHeight;
}

export function useChatKeyboardOverlay({
  isDesktop,
  blurComposeInput,
}: {
  isDesktop: boolean;
  blurComposeInput: () => void;
}) {
  const [composeFocused, setComposeFocused] = useState(false);
  const [baselineViewportHeight, setBaselineViewportHeight] = useState<number>(() => getViewportHeight());
  const [viewportHeight, setViewportHeight] = useState<number>(() => getViewportHeight());
  const [overlayMessage, setOverlayMessage] = useState<ChatOverlayMessage | null>(null);
  const deferredOverlayRef = useRef<ChatOverlayMessage | null>(null);

  useEffect(() => {
    if (isDesktop || typeof window === 'undefined') return;

    const visualViewport = window.visualViewport;
    const readViewportHeight = () => visualViewport?.height ?? window.innerHeight;
    const updateViewportMetrics = () => {
      const nextViewportHeight = readViewportHeight();
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

  useEffect(() => {
    if (!keyboardFullyClosed || !deferredOverlayRef.current) return;
    setOverlayMessage(deferredOverlayRef.current);
    deferredOverlayRef.current = null;
  }, [keyboardFullyClosed]);

  const handleMessageLongPress = useCallback(
    (message: MessageResponse, sourceRect: DOMRect, interactionPos?: { x: number; y: number }) => {
      if (isKeyboardOpen) {
        deferredOverlayRef.current = { message, sourceRect, interactionPos };
        blurComposeInput();
        return;
      }

      deferredOverlayRef.current = null;
      setOverlayMessage({ message, sourceRect, interactionPos });
    },
    [blurComposeInput, isKeyboardOpen],
  );

  const clearDeferredOverlay = useCallback(() => {
    deferredOverlayRef.current = null;
  }, []);

  const pageKeyboardStyle: CSSProperties | undefined = isKeyboardOpen
    ? {
        height: `${viewportHeight}px`,
        top: `${window.visualViewport?.offsetTop ?? 0}px`,
      }
    : undefined;

  return {
    overlayMessage,
    setOverlayMessage,
    isKeyboardOpen,
    pageKeyboardStyle,
    handleComposeFocusChange,
    handleMessageLongPress,
    clearDeferredOverlay,
  };
}
