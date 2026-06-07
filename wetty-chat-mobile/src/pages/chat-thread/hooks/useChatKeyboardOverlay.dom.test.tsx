import { act } from 'react';
import { useEffect } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, describe, expect, it, vi, type Mock } from 'vitest';
import type { MessageResponse } from '@/api/messages';
import { useChatKeyboardOverlay } from './useChatKeyboardOverlay';

function message(id: string): MessageResponse {
  return {
    id,
    clientGeneratedId: `client-${id}`,
    chatId: '1',
    replyRootId: null,
    message: `message ${id}`,
    messageType: 'text',
    sender: { uid: 1, name: 'User', gender: 0 },
    createdAt: new Date(Number(id)).toISOString(),
    isEdited: false,
    isDeleted: false,
    hasAttachments: false,
  };
}

type HookResult = ReturnType<typeof useChatKeyboardOverlay>;

class MockVisualViewport extends EventTarget {
  height = 800;
  offsetTop = 0;
}

describe('useChatKeyboardOverlay', () => {
  let host: HTMLDivElement;
  let root: Root;
  let visualViewport: MockVisualViewport;
  let hook: HookResult | null;
  let blurComposeInput: Mock<() => void>;
  let originalVisualViewport: PropertyDescriptor | undefined;
  let originalInnerHeight: PropertyDescriptor | undefined;

  function renderHook(isDesktop = false) {
    function Harness() {
      const value = useChatKeyboardOverlay({ isDesktop, blurComposeInput });
      useEffect(() => {
        hook = value;
      }, [value]);
      return null;
    }

    act(() => {
      root.render(<Harness />);
    });
  }

  beforeEach(() => {
    host = document.createElement('div');
    document.body.appendChild(host);
    root = createRoot(host);
    (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
    hook = null;
    blurComposeInput = vi.fn<() => void>(() => undefined);
    visualViewport = new MockVisualViewport();
    originalVisualViewport = Object.getOwnPropertyDescriptor(window, 'visualViewport');
    originalInnerHeight = Object.getOwnPropertyDescriptor(window, 'innerHeight');
    Object.defineProperty(window, 'visualViewport', { configurable: true, value: visualViewport });
    Object.defineProperty(window, 'innerHeight', { configurable: true, value: 800 });
  });

  afterEach(() => {
    act(() => {
      root.unmount();
    });
    host.remove();
    if (originalVisualViewport) {
      Object.defineProperty(window, 'visualViewport', originalVisualViewport);
    }
    if (originalInnerHeight) {
      Object.defineProperty(window, 'innerHeight', originalInnerHeight);
    }
  });

  it('detects keyboard-open visual viewport shrink and exposes page style', () => {
    renderHook();

    act(() => {
      hook!.handleComposeFocusChange(true);
    });
    act(() => {
      visualViewport.height = 500;
      visualViewport.offsetTop = 12;
      visualViewport.dispatchEvent(new Event('resize'));
    });

    expect(hook!.isKeyboardOpen).toBe(true);
    expect(hook!.pageKeyboardStyle).toEqual({ height: '500px', top: '12px' });
  });

  it('defers long-press overlay until keyboard is closed', () => {
    renderHook();
    const pressedMessage = message('10');
    const sourceRect = new DOMRect(1, 2, 3, 4);
    const interactionPos = { x: 9, y: 10 };

    act(() => {
      hook!.handleComposeFocusChange(true);
    });
    act(() => {
      visualViewport.height = 500;
      visualViewport.dispatchEvent(new Event('resize'));
    });
    act(() => {
      hook!.handleMessageLongPress(pressedMessage, sourceRect, interactionPos);
    });

    expect(blurComposeInput).toHaveBeenCalledTimes(1);
    expect(hook!.overlayMessage).toBeNull();

    act(() => {
      hook!.handleComposeFocusChange(false);
    });
    act(() => {
      visualViewport.height = 800;
      visualViewport.offsetTop = 0;
      visualViewport.dispatchEvent(new Event('resize'));
    });

    expect(hook!.overlayMessage).toEqual({ message: pressedMessage, sourceRect, interactionPos });
  });

  it('shows long-press overlay immediately when keyboard is not open', () => {
    renderHook();
    const pressedMessage = message('11');
    const sourceRect = new DOMRect(1, 2, 3, 4);

    act(() => {
      hook!.handleMessageLongPress(pressedMessage, sourceRect);
    });

    expect(blurComposeInput).not.toHaveBeenCalled();
    expect(hook!.overlayMessage).toEqual({ message: pressedMessage, sourceRect, interactionPos: undefined });
  });
});
