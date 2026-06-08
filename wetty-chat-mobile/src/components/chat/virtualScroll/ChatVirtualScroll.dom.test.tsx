import { act, type MutableRefObject } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { MessageResponse } from '@/api/messages';
import { ChatVirtualScroll } from './ChatVirtualScroll';
import styles from './ChatVirtualScroll.module.scss';
import type { ChatRow, LoadController, VirtualScrollAnchor, VirtualScrollHandle } from './types';

vi.mock('@lingui/core/macro', () => ({
  t: (strings: TemplateStringsArray | string) => (typeof strings === 'string' ? strings : strings.join('')),
}));

vi.mock('@lingui/react/macro', () => ({
  Trans: ({ children }: { children: unknown }) => children,
}));

vi.mock('react-redux', () => ({
  useSelector: () => '14px',
}));

const ROW_HEIGHT = 76;
const VIEWPORT_HEIGHT = 320;

let currentRowCount = 0;
let currentViewportHeight = VIEWPORT_HEIGHT;
let wrapperHeightDelta = 0;
let scrollContainer: HTMLElement | null = null;
const rowIndexes = new WeakMap<Element, number>();
const resizeObservers = new Set<MockResizeObserver>();

class MockResizeObserver {
  private readonly elements = new Set<Element>();
  private readonly callback: ResizeObserverCallback;

  constructor(callback: ResizeObserverCallback) {
    this.callback = callback;
    resizeObservers.add(this);
  }

  observe(element: Element) {
    this.elements.add(element);
    const row = element.querySelector<HTMLElement>('[data-row-index]');
    if (row?.dataset.rowIndex) {
      rowIndexes.set(element, Number(row.dataset.rowIndex));
    }
  }

  disconnect() {
    this.elements.clear();
    resizeObservers.delete(this);
  }

  flush() {
    const entries = Array.from(this.elements, (target) => ({
      target,
      contentRect: target.getBoundingClientRect(),
    })) as ResizeObserverEntry[];
    this.callback(entries, this as unknown as ResizeObserver);
  }
}

function flushResizeObservers() {
  for (const observer of Array.from(resizeObservers)) {
    observer.flush();
  }
}

async function flushLayout(times = 1) {
  for (let index = 0; index < times; index += 1) {
    await act(async () => {
      flushResizeObservers();
      await Promise.resolve();
    });
  }
}

function message(id: string): MessageResponse {
  return {
    id,
    clientGeneratedId: `client-${id}`,
    chatId: '1',
    replyRootId: null,
    message: `message ${id}`,
    messageType: 'text',
    sender: { uid: 2, name: 'User', gender: 0 },
    createdAt: new Date(Number(id)).toISOString(),
    isEdited: false,
    isDeleted: false,
    hasAttachments: false,
  };
}

function rows(count: number): ChatRow[] {
  currentRowCount = count;
  return Array.from({ length: count }, (_, index) => {
    const id = String(index + 1);
    return {
      type: 'message',
      key: `msg:${id}`,
      messageId: id,
      clientGeneratedId: `client-${id}`,
      message: message(id),
      showName: true,
      showAvatar: true,
    };
  });
}

function renderVirtualScroll(
  root: Root,
  nextRows: ChatRow[],
  scrollApiRef: MutableRefObject<VirtualScrollHandle | null>,
  options: {
    initialAnchor?: VirtualScrollAnchor;
    loadOlder?: LoadController;
    loadNewer?: LoadController;
  } = {},
) {
  root.render(
    <ChatVirtualScroll
      rows={nextRows}
      renderRow={(row) =>
        row.type === 'message' ? (
          <div data-testid={row.key} data-row-index={Number(row.messageId) - 1}>
            {row.message.message}
          </div>
        ) : (
          <div data-testid={row.key}>{row.dateLabel}</div>
        )
      }
      initialAnchor={options.initialAnchor ?? { type: 'bottom', token: 1 }}
      scrollApiRef={scrollApiRef}
      loadOlder={options.loadOlder ?? { hasMore: false, onLoad: vi.fn() }}
      loadNewer={options.loadNewer ?? { hasMore: false, onLoad: vi.fn() }}
    />,
  );
}

function hasRowContentWrapper(element: Element) {
  return element.querySelector(`.${styles.rowContent}`) != null;
}

describe('ChatVirtualScroll realtime appends', () => {
  let host: HTMLDivElement;
  let root: Root;
  let originalClientHeight: PropertyDescriptor | undefined;
  let originalScrollHeight: PropertyDescriptor | undefined;
  let originalOffsetTop: PropertyDescriptor | undefined;
  let originalGetBoundingClientRect: typeof HTMLElement.prototype.getBoundingClientRect;
  let originalScrollTo: typeof HTMLElement.prototype.scrollTo;
  let consoleDebugSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    host = document.createElement('div');
    document.body.appendChild(host);
    root = createRoot(host);
    (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true;

    originalClientHeight = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'clientHeight');
    originalScrollHeight = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'scrollHeight');
    originalOffsetTop = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'offsetTop');
    originalGetBoundingClientRect = HTMLElement.prototype.getBoundingClientRect;
    originalScrollTo = HTMLElement.prototype.scrollTo;
    consoleDebugSpy = vi.spyOn(console, 'debug').mockImplementation(() => {});

    Object.defineProperty(HTMLElement.prototype, 'clientHeight', {
      configurable: true,
      get() {
        return currentViewportHeight;
      },
    });
    Object.defineProperty(HTMLElement.prototype, 'scrollHeight', {
      configurable: true,
      get() {
        return currentRowCount * ROW_HEIGHT;
      },
    });
    Object.defineProperty(HTMLElement.prototype, 'offsetTop', {
      configurable: true,
      get() {
        return (rowIndexes.get(this) ?? 0) * ROW_HEIGHT;
      },
    });
    HTMLElement.prototype.getBoundingClientRect = function getBoundingClientRect() {
      const index = rowIndexes.get(this);
      if (index != null) {
        const height = ROW_HEIGHT + (hasRowContentWrapper(this) ? wrapperHeightDelta : 0);
        const top = index * ROW_HEIGHT - (scrollContainer?.scrollTop ?? 0);
        return {
          x: 0,
          y: top,
          top,
          left: 0,
          right: 100,
          bottom: top + height,
          width: 100,
          height,
          toJSON: () => ({}),
        };
      }
      return {
        x: 0,
        y: 0,
        top: 0,
        left: 0,
        right: 100,
        bottom: currentViewportHeight,
        width: 100,
        height: currentViewportHeight,
        toJSON: () => ({}),
      };
    };
    HTMLElement.prototype.scrollTo = function scrollTo(options?: ScrollToOptions | number, y?: number) {
      if (typeof options === 'number') {
        this.scrollTop = y ?? 0;
        return;
      }
      this.scrollTop = options?.top ?? 0;
    };

    vi.stubGlobal('ResizeObserver', MockResizeObserver);
    vi.stubGlobal('requestAnimationFrame', (callback: FrameRequestCallback) => {
      callback(performance.now());
      return 1;
    });
    vi.stubGlobal('cancelAnimationFrame', vi.fn());
  });

  afterEach(() => {
    act(() => {
      root.unmount();
    });
    host.remove();
    scrollContainer = null;
    currentRowCount = 0;
    currentViewportHeight = VIEWPORT_HEIGHT;
    wrapperHeightDelta = 0;
    resizeObservers.clear();

    if (originalClientHeight) Object.defineProperty(HTMLElement.prototype, 'clientHeight', originalClientHeight);
    if (originalScrollHeight) Object.defineProperty(HTMLElement.prototype, 'scrollHeight', originalScrollHeight);
    if (originalOffsetTop) Object.defineProperty(HTMLElement.prototype, 'offsetTop', originalOffsetTop);
    HTMLElement.prototype.getBoundingClientRect = originalGetBoundingClientRect;
    HTMLElement.prototype.scrollTo = originalScrollTo;
    consoleDebugSpy.mockRestore();
    vi.unstubAllGlobals();
    vi.useRealTimers();
  });

  it('renders staged and mounted rows through the same row content wrapper', async () => {
    const scrollApiRef = { current: null } as MutableRefObject<VirtualScrollHandle | null>;

    await act(async () => {
      renderVirtualScroll(root, rows(40), scrollApiRef);
      await Promise.resolve();
    });
    scrollContainer = host.firstElementChild as HTMLElement;
    currentViewportHeight = VIEWPORT_HEIGHT + 1;
    await flushLayout();
    currentViewportHeight = VIEWPORT_HEIGHT;

    const stagedRows = Array.from(host.querySelectorAll(`.${styles.stagingItem}`));
    expect(stagedRows.length).toBeGreaterThan(0);
    expect(stagedRows.every(hasRowContentWrapper)).toBe(true);

    await flushLayout(8);

    const mountedRows = Array.from(host.querySelectorAll(`.${styles.flowItem}`));
    expect(mountedRows.length).toBeGreaterThan(0);
    expect(mountedRows.every(hasRowContentWrapper)).toBe(true);
  });

  it('keeps following the bottom when a websocket append arrives while a staging batch is pending', async () => {
    const scrollApiRef = { current: null } as MutableRefObject<VirtualScrollHandle | null>;

    await act(async () => {
      renderVirtualScroll(root, rows(40), scrollApiRef);
    });
    scrollContainer = host.firstElementChild as HTMLElement;
    currentViewportHeight = VIEWPORT_HEIGHT + 1;
    await flushLayout();
    currentViewportHeight = VIEWPORT_HEIGHT;
    await flushLayout(8);
    expect(host.querySelector('[data-testid="msg:40"]')).not.toBeNull();

    await act(async () => {
      scrollContainer!.scrollTop = 24 * ROW_HEIGHT;
      scrollContainer!.dispatchEvent(new Event('scroll', { bubbles: true }));
      await Promise.resolve();
    });
    await act(async () => {
      scrollApiRef.current?.scrollToBottom({ behavior: 'auto', source: 'test-pending-bottom' });
      await Promise.resolve();
    });

    await act(async () => {
      renderVirtualScroll(root, rows(41), scrollApiRef);
      await Promise.resolve();
    });

    expect(scrollContainer!.scrollTop).toBe(currentRowCount * ROW_HEIGHT - currentViewportHeight);
  });

  it('does not trigger loadOlder during bottom-open bootstrap settling', async () => {
    vi.useFakeTimers();
    let nextRafId = 1;
    const rafCallbacks = new Map<number, FrameRequestCallback>();
    vi.stubGlobal('requestAnimationFrame', (callback: FrameRequestCallback) => {
      const id = nextRafId;
      nextRafId += 1;
      rafCallbacks.set(id, callback);
      return id;
    });
    vi.stubGlobal('cancelAnimationFrame', (id: number) => {
      rafCallbacks.delete(id);
    });
    const loadOlder = { hasMore: true, loading: false, onLoad: vi.fn() };
    const scrollApiRef = { current: null } as MutableRefObject<VirtualScrollHandle | null>;

    await act(async () => {
      renderVirtualScroll(root, rows(40), scrollApiRef, { loadOlder });
      await Promise.resolve();
    });
    scrollContainer = host.firstElementChild as HTMLElement;

    currentViewportHeight = VIEWPORT_HEIGHT + 1;
    await flushLayout();
    currentViewportHeight = VIEWPORT_HEIGHT;
    await flushLayout(8);
    expect(rafCallbacks.size).toBeGreaterThan(0);

    await act(async () => {
      scrollContainer!.scrollTop = 0;
      scrollContainer!.dispatchEvent(new Event('scroll', { bubbles: true }));
      vi.runOnlyPendingTimers();
      await Promise.resolve();
    });

    expect(loadOlder.onLoad).not.toHaveBeenCalled();
  });

  it('does not correct mounted row height after wrapper-dependent staged measurement promotes', async () => {
    wrapperHeightDelta = 20;
    const scrollApiRef = { current: null } as MutableRefObject<VirtualScrollHandle | null>;

    await act(async () => {
      renderVirtualScroll(root, rows(40), scrollApiRef);
    });
    scrollContainer = host.firstElementChild as HTMLElement;

    await flushLayout();
    consoleDebugSpy.mockClear();
    await flushLayout(2);

    const mountedResizeCalls = consoleDebugSpy.mock.calls.filter((call: unknown[]) =>
      String(call[0]).includes('mounted-row-resize'),
    );
    expect(mountedResizeCalls).toHaveLength(0);
  });

  it('reserves estimated scroll height during bootstrap so the scrollbar does not appear after measurement', async () => {
    const scrollApiRef = { current: null } as MutableRefObject<VirtualScrollHandle | null>;

    await act(async () => {
      renderVirtualScroll(root, rows(40), scrollApiRef);
    });

    scrollContainer = host.firstElementChild as HTMLElement;
    const flowContent = scrollContainer.firstElementChild as HTMLElement;

    expect(flowContent.style.minHeight).toBe(`${40 * ROW_HEIGHT}px`);
  });
});
