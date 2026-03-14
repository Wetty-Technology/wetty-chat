import { useCallback, useEffect, useLayoutEffect, useRef, useState, type ReactNode } from 'react';
import styles from './VirtualScroll.module.scss';

interface VirtualScrollProps {
  totalItems: number;
  estimatedItemHeight: number;
  renderItem: (index: number) => ReactNode;
  overscan?: number;
  onLoadOlder?: () => void;
  onLoadNewer?: () => void;
  loadMoreThreshold?: number;
  loadingOlder?: boolean;
  prependedCount?: number;
  scrollToBottomRef?: React.MutableRefObject<(() => void) | null>;
  scrollToIndexRef?: React.MutableRefObject<((index: number, behavior?: ScrollBehavior) => void) | null>;
  bottomPadding?: number;
  windowKey?: number | string;
  initialScrollIndex?: number;
  onAtBottomChange?: (atBottom: boolean) => void;
  onScrollIdle?: () => void;
  header?: ReactNode;
}

function MeasuredItem({
  index,
  offset,
  onResize,
  children,
  invisible = false,
}: {
  index: number;
  offset: number;
  onResize: (index: number, height: number) => void;
  children: ReactNode;
  invisible?: boolean;
}) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver(() => {
      const h = el.getBoundingClientRect().height;
      if (h > 0) onResize(index, h);
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, [index, onResize]);

  return (
    <div
      ref={ref}
      className={styles.item}
      style={{
        transform: invisible ? `translateY(0px)` : `translateY(${Math.round(offset)}px)`,
        visibility: invisible ? 'hidden' : 'visible',
        pointerEvents: invisible ? 'none' : 'auto',
        zIndex: invisible ? -1 : undefined,
      }}
    >
      {children}
    </div>
  );
}

export function VirtualScroll({
  totalItems,
  estimatedItemHeight,
  renderItem,
  overscan = 5,
  onLoadOlder,
  onLoadNewer,
  loadMoreThreshold = 500,
  loadingOlder = false,
  prependedCount = 0,
  scrollToBottomRef,
  scrollToIndexRef,
  bottomPadding = 0,
  windowKey,
  initialScrollIndex,
  onAtBottomChange,
  onScrollIdle,
  header,
}: VirtualScrollProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const headerRef = useRef<HTMLDivElement>(null);
  const scrollIdleTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const isScrollIdleRef = useRef(true);
  const [headerHeight, setHeaderHeight] = useState(0);

  useEffect(() => {
    const el = headerRef.current;
    if (!el) {
      setHeaderHeight(0);
      return;
    }
    const ro = new ResizeObserver(() => {
      const h = el.getBoundingClientRect().height;
      if (h > 0) setHeaderHeight(h);
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, [header]);
  const [scrollTop, setScrollTop] = useState(0);
  const [containerHeight, setContainerHeight] = useState(0);
  const prevTotalRef = useRef(totalItems);
  const prevPrependedCountRef = useRef(prependedCount);
  const hasInitialScrolled = useRef(false);
  const heightCache = useRef(new Map<number, number>());
  const isAtBottomRef = useRef(true);
  const prevLoadingOlderRef = useRef(loadingOlder);
  const pendingBottomScrollRef = useRef(false);
  const initialScrollIndexRef = useRef<number | undefined>(undefined);
  const isStabilizedRef = useRef(false);
  const batchTimerRef = useRef<number | null>(null);
  const [, forceUpdate] = useState(0);

  const getHeight = useCallback((i: number) => {
    return heightCache.current.get(i) ?? estimatedItemHeight;
  }, [estimatedItemHeight]);

  const getItemOffset = useCallback((index: number) => {
    let offset = 0;
    for (let i = 0; i < index; i++) {
      offset += heightCache.current.get(i) ?? estimatedItemHeight;
    }
    return offset;
  }, [estimatedItemHeight]);

  const getTotalHeight = useCallback(() => {
    let total = 0;
    for (let i = 0; i < totalItems; i++) {
      total += heightCache.current.get(i) ?? estimatedItemHeight;
    }
    return total;
  }, [totalItems, estimatedItemHeight]);

  // Binary search: find the first index whose bottom edge is past scrollTop
  const findStartIndex = useCallback((scrollTop: number) => {
    let offset = 0;
    for (let i = 0; i < totalItems; i++) {
      const h = heightCache.current.get(i) ?? estimatedItemHeight;
      if (offset + h > scrollTop) return i;
      offset += h;
    }
    return totalItems - 1;
  }, [totalItems, estimatedItemHeight]);

  const totalHeight = getTotalHeight();

  // Scroll to bottom on initial mount, or to target index on jump
  useLayoutEffect(() => {
    if (hasInitialScrolled.current) return;
    const el = containerRef.current;
    if (!el) return;
    const targetIdx = initialScrollIndexRef.current;
    if (targetIdx != null) {
      const currentTopPadding = (loadingOlder ? 36 : 0) + headerHeight;
      const offset = targetIdx * estimatedItemHeight + currentTopPadding;
      el.scrollTop = Math.max(0, offset - el.clientHeight / 2);
    } else {
      el.scrollTop = el.scrollHeight;
      pendingBottomScrollRef.current = true;
    }
    setScrollTop(el.scrollTop);
    setContainerHeight(el.clientHeight);
    hasInitialScrolled.current = true;
    setTimeout(() => {
      if (!isStabilizedRef.current) {
        isStabilizedRef.current = true;
        forceUpdate(c => c + 1);
      }
    }, 500);
  }, [totalHeight, estimatedItemHeight, loadingOlder, headerHeight]);

  // After every render, snap to bottom if we should be there.
  // This replaces RAF-based bottom-scroll: useLayoutEffect sees the updated DOM.
  useLayoutEffect(() => {
    if (!hasInitialScrolled.current) return;
    const el = containerRef.current;
    if (!el) return;

    const targetIdx = initialScrollIndexRef.current;
    if (targetIdx != null) {
      const currentTopPadding = (loadingOlder ? 36 : 0) + headerHeight;
      const offset = getItemOffset(targetIdx) + currentTopPadding;
      el.scrollTop = Math.max(0, offset - el.clientHeight / 2);
      if (heightCache.current.has(targetIdx)) {
        initialScrollIndexRef.current = undefined;
        isStabilizedRef.current = true;
      }
    } else if (isAtBottomRef.current || pendingBottomScrollRef.current) {
      const target = el.scrollHeight - el.clientHeight;
      if (Math.abs(el.scrollTop - target) > 1) {
        el.scrollTop = target;
      }
      if (pendingBottomScrollRef.current) {
        pendingBottomScrollRef.current = false;
        isStabilizedRef.current = true;
      }
      if (!isAtBottomRef.current) {
        isAtBottomRef.current = true;
        onAtBottomChange?.(true);
      }
    }
  });

  // When items are prepended at top, adjust scrollTop to maintain position
  useLayoutEffect(() => {
    const newPrepended = prependedCount - prevPrependedCountRef.current;
    if (newPrepended > 0 && hasInitialScrolled.current) {
      if (heightCache.current.size > 0) {
        const newCache = new Map<number, number>();
        for (const [k, v] of heightCache.current.entries()) {
          newCache.set(k + newPrepended, v);
        }
        heightCache.current = newCache;
      }
      const el = containerRef.current;
      if (el) {
        let addedHeight = 0;
        for (let i = 0; i < newPrepended; i++) {
          addedHeight += heightCache.current.get(i) ?? estimatedItemHeight;
        }
        el.scrollTop += addedHeight;
      }
    }
    prevPrependedCountRef.current = prependedCount;

    // Compensate for loading bar appearing/disappearing
    if (prevLoadingOlderRef.current !== loadingOlder) {
      const el = containerRef.current;
      if (el) {
        const delta = loadingOlder ? 36 : -36;
        el.scrollTop += delta;
      }
      prevLoadingOlderRef.current = loadingOlder;
    }
  }, [prependedCount, estimatedItemHeight, loadingOlder]);

  // Auto-scroll to bottom when new messages appended and user was at bottom
  useLayoutEffect(() => {
    const prev = prevTotalRef.current;
    if (isAtBottomRef.current && totalItems > prev) {
      const el = containerRef.current;
      if (el) {
        requestAnimationFrame(() => {
          el.scrollTop = el.scrollHeight - el.clientHeight;
        });
      }
    }
    prevTotalRef.current = totalItems;
  }, [totalItems]);

  // Reset state when windowKey changes (new message window loaded)
  useEffect(() => {
    if (windowKey == null) return;
    heightCache.current = new Map();
    isStabilizedRef.current = false;
    prevTotalRef.current = 0;
    prevPrependedCountRef.current = 0;
    if (initialScrollIndex != null) {
      // Jump to target: let the useLayoutEffect handle scrolling
      hasInitialScrolled.current = false;
      isAtBottomRef.current = false;
      onAtBottomChange?.(false);
      initialScrollIndexRef.current = initialScrollIndex;
    } else {
      // Normal window reset: scroll to bottom
      hasInitialScrolled.current = false;
      isAtBottomRef.current = true;
      onAtBottomChange?.(true);
    }
    forceUpdate(c => c + 1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [windowKey]);

  // Expose scrollToBottom for imperative use
  useEffect(() => {
    if (scrollToBottomRef) {
      scrollToBottomRef.current = () => {
        const el = containerRef.current;
        if (el) {
          el.scrollTop = el.scrollHeight;
          if (!isAtBottomRef.current) {
            isAtBottomRef.current = true;
            onAtBottomChange?.(true);
          }
        }
      };
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [scrollToBottomRef]);

  // Expose scrollToIndex for imperative use
  useEffect(() => {
    if (scrollToIndexRef) {
      scrollToIndexRef.current = (index: number, behavior: ScrollBehavior = 'auto') => {
        const el = containerRef.current;
        if (!el) return;
        const currentTopPadding = (loadingOlder ? 36 : 0) + headerHeight;
        const offset = getItemOffset(index) + currentTopPadding;

        const targetAtBottom = offset + el.clientHeight >= el.scrollHeight - 30;
        if (isAtBottomRef.current !== targetAtBottom) {
          isAtBottomRef.current = targetAtBottom;
          onAtBottomChange?.(targetAtBottom);
        }

        el.scrollTo({ top: offset, behavior });
      };
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [scrollToIndexRef, getItemOffset, loadingOlder, headerHeight]);

  const handleResize = useCallback((index: number, height: number) => {
    const isFirstMeasure = !heightCache.current.has(index);
    const prev = heightCache.current.get(index) ?? estimatedItemHeight;

    if (prev !== height || isFirstMeasure) {
      heightCache.current.set(index, height);
      if (batchTimerRef.current == null) {
        batchTimerRef.current = requestAnimationFrame(() => {
          batchTimerRef.current = null;
          forceUpdate(c => c + 1);
        });
      }

      // For items above viewport when NOT at bottom, adjust scrollTop to maintain position.
      // When at bottom, the useLayoutEffect snap-to-bottom handles it after re-render.
      const el = containerRef.current;
      if (el && !isAtBottomRef.current) {
        const diff = height - prev;
        const currentTopPadding = (loadingOlder ? 36 : 0) + headerHeight;
        const itemOffset = getItemOffset(index) + currentTopPadding;

        if (itemOffset < el.scrollTop) {
          el.scrollTop += diff;
          setScrollTop(el.scrollTop);
        }
      }
    }
  }, [getItemOffset, estimatedItemHeight, loadingOlder, headerHeight]);

  const onScrollIdleRef = useRef(onScrollIdle);
  onScrollIdleRef.current = onScrollIdle;

  const handleScroll = useCallback(() => {
    const el = containerRef.current;
    if (!el) return;
    setScrollTop(el.scrollTop);
    setContainerHeight(el.clientHeight);

    isScrollIdleRef.current = false;
    if (scrollIdleTimerRef.current) clearTimeout(scrollIdleTimerRef.current);
    scrollIdleTimerRef.current = setTimeout(() => {
      isScrollIdleRef.current = true;
      onScrollIdleRef.current?.();
    }, 150);

    const wasAtBottom = isAtBottomRef.current;
    isAtBottomRef.current = el.scrollTop + el.clientHeight >= el.scrollHeight - 30;
    if (wasAtBottom !== isAtBottomRef.current) {
      onAtBottomChange?.(isAtBottomRef.current);
    }

    if (onLoadOlder && el.scrollTop < loadMoreThreshold) {
      onLoadOlder();
    }

    if (onLoadNewer && el.scrollHeight - el.scrollTop - el.clientHeight < loadMoreThreshold) {
      onLoadNewer();
    }
  }, [onLoadOlder, onLoadNewer, loadMoreThreshold, onAtBottomChange]);

  // Observe container resize
  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => {
      setContainerHeight(el.clientHeight);
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  // Compute visible range
  const startIndex = Math.max(0, findStartIndex(scrollTop) - overscan);
  const endOffset = scrollTop + containerHeight;
  let endIndex = startIndex;
  {
    let offset = getItemOffset(startIndex);
    for (let i = startIndex; i < totalItems; i++) {
      if (offset > endOffset) {
        endIndex = Math.min(totalItems - 1, i + overscan);
        break;
      }
      offset += getHeight(i);
      endIndex = i;
    }
    if (endIndex === totalItems - 1 || offset <= endOffset) {
      endIndex = Math.min(totalItems - 1, endIndex + overscan);
    }
  }

  const loadingRowHeight = 36;
  const topPadding = (loadingOlder ? loadingRowHeight : 0) + headerHeight;

  const itemsToRender = new Set<number>();
  for (let i = startIndex; i <= endIndex; i++) {
    itemsToRender.add(i);
  }

  if (isStabilizedRef.current) {
    let measuredCount = 0;
    const maxMeasure = 20;

    for (let i = startIndex - 1; i >= 0 && measuredCount < maxMeasure; i--) {
      if (!heightCache.current.has(i)) {
        itemsToRender.add(i);
        measuredCount++;
      }
    }

    for (let i = endIndex + 1; i < totalItems && measuredCount < maxMeasure; i++) {
      if (!heightCache.current.has(i)) {
        itemsToRender.add(i);
        measuredCount++;
      }
    }
  }

  const visibleItems: ReactNode[] = Array.from(itemsToRender).sort((a, b) => a - b).map(i => {
    const isVisible = i >= startIndex && i <= endIndex;
    const offset = isVisible ? getItemOffset(i) + topPadding : 0;
    return (
      <MeasuredItem 
        key={`${windowKey}-${i}`} 
        index={i} 
        offset={offset} 
        onResize={handleResize} 
        invisible={!isVisible}
      >
        {renderItem(i)}
      </MeasuredItem>
    );
  });

  return (
    <div ref={containerRef} className={styles.container} onScroll={handleScroll}>
      <div className={styles.spacer} style={{ height: totalHeight + topPadding + bottomPadding }}>
        {loadingOlder && (
          <div className={styles.loadingRow} style={{ height: loadingRowHeight }}>
            Loading…
          </div>
        )}
        {header && (
          <div ref={headerRef} style={{ position: 'absolute', top: loadingOlder ? loadingRowHeight : 0, left: 0, right: 0 }}>
            {header}
          </div>
        )}
        {visibleItems}
      </div>
    </div>
  );
}
