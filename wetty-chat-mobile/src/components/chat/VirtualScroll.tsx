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
  const spacerRef = useRef<HTMLDivElement>(null);
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
  const heightCache = useRef(new Map<number, number>());
  const isAtBottomRef = useRef(true);
  const prevLoadingOlderRef = useRef(loadingOlder);
  const initialScrollIndexRef = useRef<number | undefined>(undefined);
  const batchTimerRef = useRef<number | null>(null);
  const [, forceUpdate] = useState(0);

  // Phase state machine: MEASURING → READY
  const [phase, setPhase] = useState<'MEASURING' | 'READY'>('MEASURING');
  const phaseRef = useRef<'MEASURING' | 'READY'>('MEASURING');
  const safetyTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

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

  // transitionToReady: the critical MEASURING → READY transition
  const transitionToReady = useCallback(() => {
    const el = containerRef.current;
    const spacer = spacerRef.current;
    if (!el || !spacer) return;
    if (phaseRef.current === 'READY') return;

    // Clear safety timeout
    if (safetyTimeoutRef.current) {
      clearTimeout(safetyTimeoutRef.current);
      safetyTimeoutRef.current = null;
    }

    // Compute real totalHeight from fully-populated heightCache
    let realTotal = 0;
    for (let i = 0; i < totalItems; i++) {
      realTotal += heightCache.current.get(i) ?? estimatedItemHeight;
    }

    const currentTopPadding = (loadingOlder ? 36 : 0) + headerHeight;
    // Set spacer DOM height directly before React re-renders
    spacer.style.height = `${realTotal + currentTopPadding + bottomPadding}px`;

    // Set scroll position
    const targetIdx = initialScrollIndexRef.current;
    if (targetIdx != null) {
      const offset = getItemOffset(targetIdx) + currentTopPadding;
      el.scrollTop = Math.max(0, offset - el.clientHeight / 2);
      if (heightCache.current.has(targetIdx)) {
        initialScrollIndexRef.current = undefined;
      }
    } else {
      // Scroll to bottom
      el.scrollTop = el.scrollHeight - el.clientHeight;
      isAtBottomRef.current = true;
    }

    // Sync React state
    setScrollTop(el.scrollTop);
    setContainerHeight(el.clientHeight);

    // Transition phase
    phaseRef.current = 'READY';
    setPhase('READY');
  }, [totalItems, estimatedItemHeight, loadingOlder, headerHeight, bottomPadding, getItemOffset]);

  // Safety timeout: if MEASURING doesn't complete in 2s, transition anyway
  useEffect(() => {
    if (phase === 'MEASURING' && totalItems > 0) {
      safetyTimeoutRef.current = setTimeout(() => {
        if (phaseRef.current === 'MEASURING') {
          transitionToReady();
        }
      }, 2000);
      return () => {
        if (safetyTimeoutRef.current) {
          clearTimeout(safetyTimeoutRef.current);
          safetyTimeoutRef.current = null;
        }
      };
    }
  }, [phase, totalItems, transitionToReady]);

  // If totalItems is 0 during MEASURING, transition immediately
  useEffect(() => {
    if (phase === 'MEASURING' && totalItems === 0) {
      phaseRef.current = 'READY';
      setPhase('READY');
    }
  }, [phase, totalItems]);

  // After every render in READY phase, snap to bottom if we should be there
  useLayoutEffect(() => {
    if (phaseRef.current !== 'READY') return;
    const el = containerRef.current;
    if (!el) return;

    const targetIdx = initialScrollIndexRef.current;
    if (targetIdx != null) {
      const currentTopPadding = (loadingOlder ? 36 : 0) + headerHeight;
      const offset = getItemOffset(targetIdx) + currentTopPadding;
      el.scrollTop = Math.max(0, offset - el.clientHeight / 2);
      if (heightCache.current.has(targetIdx)) {
        initialScrollIndexRef.current = undefined;
      }
    } else if (isAtBottomRef.current) {
      const target = el.scrollHeight - el.clientHeight;
      if (Math.abs(el.scrollTop - target) > 1) {
        el.scrollTop = target;
      }
      if (!isAtBottomRef.current) {
        isAtBottomRef.current = true;
        onAtBottomChange?.(true);
      }
    }
  });

  // When items are prepended at top, adjust scrollTop to maintain position
  useLayoutEffect(() => {
    if (phaseRef.current !== 'READY') return;
    const newPrepended = prependedCount - prevPrependedCountRef.current;
    if (newPrepended > 0) {
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
    if (phaseRef.current !== 'READY') return;
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
    prevTotalRef.current = 0;
    prevPrependedCountRef.current = 0;
    if (initialScrollIndex != null) {
      isAtBottomRef.current = false;
      onAtBottomChange?.(false);
      initialScrollIndexRef.current = initialScrollIndex;
    } else {
      isAtBottomRef.current = true;
      onAtBottomChange?.(true);
    }
    // Reset to MEASURING phase
    phaseRef.current = 'MEASURING';
    setPhase('MEASURING');
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
    const prev = heightCache.current.get(index) ?? estimatedItemHeight;
    const isFirstMeasure = !heightCache.current.has(index);

    if (prev === height && !isFirstMeasure) return;

    heightCache.current.set(index, height);

    if (phaseRef.current === 'MEASURING') {
      // Check if all items measured
      if (heightCache.current.size >= totalItems) {
        transitionToReady();
      }
      return;
    }

    // READY phase: batched forceUpdate + scroll adjustment
    if (batchTimerRef.current == null) {
      batchTimerRef.current = requestAnimationFrame(() => {
        batchTimerRef.current = null;
        forceUpdate(c => c + 1);
      });
    }

    // For items above viewport when NOT at bottom, adjust scrollTop to maintain position
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
  }, [getItemOffset, estimatedItemHeight, loadingOlder, headerHeight, totalItems, transitionToReady]);

  const onScrollIdleRef = useRef(onScrollIdle);
  onScrollIdleRef.current = onScrollIdle;

  const handleScroll = useCallback(() => {
    if (phaseRef.current !== 'READY') return;
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

  const loadingRowHeight = 36;
  const topPadding = (loadingOlder ? loadingRowHeight : 0) + headerHeight;

  // MEASURING phase: render ALL items invisibly
  if (phase === 'MEASURING') {
    const measuringItems: ReactNode[] = [];
    for (let i = 0; i < totalItems; i++) {
      measuringItems.push(
        <MeasuredItem
          key={`${windowKey}-${i}`}
          index={i}
          offset={0}
          onResize={handleResize}
          invisible
        >
          {renderItem(i)}
        </MeasuredItem>
      );
    }

    return (
      <div ref={containerRef} className={styles.container} onScroll={handleScroll} style={{ opacity: 0 }}>
        <div ref={spacerRef} className={styles.spacer} style={{ height: totalItems * estimatedItemHeight + topPadding + bottomPadding }}>
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
          {measuringItems}
        </div>
      </div>
    );
  }

  // READY phase: compute visible range and render normally
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

  // Collect visible items + unmeasured items near viewport for pre-measurement
  const itemsToRender = new Set<number>();
  for (let i = startIndex; i <= endIndex; i++) {
    itemsToRender.add(i);
  }

  // Pre-measure unmeasured items near the viewport (e.g., newly prepended/appended)
  const maxPreMeasure = 20;
  let preMeasured = 0;
  for (let i = startIndex - 1; i >= 0 && preMeasured < maxPreMeasure; i--) {
    if (!heightCache.current.has(i)) {
      itemsToRender.add(i);
      preMeasured++;
    }
  }
  for (let i = endIndex + 1; i < totalItems && preMeasured < maxPreMeasure; i++) {
    if (!heightCache.current.has(i)) {
      itemsToRender.add(i);
      preMeasured++;
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
      <div ref={spacerRef} className={styles.spacer} style={{ height: totalHeight + topPadding + bottomPadding }}>
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
