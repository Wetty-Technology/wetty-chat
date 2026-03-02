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
}

function MeasuredItem({
  index,
  offset,
  onResize,
  children,
}: {
  index: number;
  offset: number;
  onResize: (index: number, height: number) => void;
  children: ReactNode;
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
      style={{ transform: `translateY(${offset}px)` }}
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
}: VirtualScrollProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [scrollTop, setScrollTop] = useState(0);
  const [containerHeight, setContainerHeight] = useState(0);
  const prevTotalRef = useRef(totalItems);
  const prevPrependedCountRef = useRef(prependedCount);
  const hasInitialScrolled = useRef(false);
  const heightCache = useRef(new Map<number, number>());
  const isAtBottomRef = useRef(true);
  const pendingBottomScrollRef = useRef(false);
  const initialScrollIndexRef = useRef<number | undefined>(undefined);
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
      const offset = targetIdx * estimatedItemHeight;
      el.scrollTop = Math.max(0, offset - el.clientHeight / 2);
    } else {
      el.scrollTop = el.scrollHeight;
      pendingBottomScrollRef.current = true;
    }
    setScrollTop(el.scrollTop);
    setContainerHeight(el.clientHeight);
    hasInitialScrolled.current = true;
  }, [totalHeight]);

  // When items are prepended at top, adjust scrollTop to maintain position
  useLayoutEffect(() => {
    const newPrepended = prependedCount - prevPrependedCountRef.current;
    if (newPrepended > 0 && hasInitialScrolled.current) {
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
  }, [prependedCount, estimatedItemHeight]);

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
    prevTotalRef.current = 0;
    prevPrependedCountRef.current = 0;
    if (initialScrollIndex != null) {
      // Jump to target: let the useLayoutEffect handle scrolling
      hasInitialScrolled.current = false;
      isAtBottomRef.current = false;
      initialScrollIndexRef.current = initialScrollIndex;
    } else {
      // Normal window reset: scroll to bottom
      hasInitialScrolled.current = false;
      isAtBottomRef.current = true;
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
        }
      };
    }
  }, [scrollToBottomRef]);

  // Expose scrollToIndex for imperative use
  useEffect(() => {
    if (scrollToIndexRef) {
      scrollToIndexRef.current = (index: number, behavior: ScrollBehavior = 'auto') => {
        const el = containerRef.current;
        if (!el) return;
        const loadingRowH = loadingOlder ? 36 : 0;
        const offset = getItemOffset(index) + loadingRowH;
        el.scrollTo({ top: offset, behavior });
      };
    }
  }, [scrollToIndexRef, getItemOffset, loadingOlder]);

  const handleResize = useCallback((index: number, height: number) => {
    const prev = heightCache.current.get(index);
    if (prev !== height) {
      heightCache.current.set(index, height);
      forceUpdate(c => c + 1);

      // Re-adjust scroll for jump target after items are measured
      const targetIdx = initialScrollIndexRef.current;
      if (targetIdx != null) {
        requestAnimationFrame(() => {
          const el = containerRef.current;
          if (!el) return;
          const offset = getItemOffset(targetIdx);
          el.scrollTop = Math.max(0, offset - el.clientHeight / 2);
          // Clear after the target item itself is measured
          if (heightCache.current.has(targetIdx)) {
            initialScrollIndexRef.current = undefined;
          }
        });
      } else if (isAtBottomRef.current || pendingBottomScrollRef.current) {
        requestAnimationFrame(() => {
          const el = containerRef.current;
          if (!el) return;
          el.scrollTop = el.scrollHeight - el.clientHeight;
          // Once we've scrolled to true bottom, isAtBottomRef will stay true
          // via handleScroll, so we can stop forcing it
          pendingBottomScrollRef.current = false;
          isAtBottomRef.current = true;
        });
      }
    }
  }, [getItemOffset]);

  const handleScroll = useCallback(() => {
    const el = containerRef.current;
    if (!el) return;
    setScrollTop(el.scrollTop);
    setContainerHeight(el.clientHeight);

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
  const topPadding = loadingOlder ? loadingRowHeight : 0;

  const visibleItems: ReactNode[] = [];
  for (let i = startIndex; i <= endIndex; i++) {
    const offset = getItemOffset(i) + topPadding;
    visibleItems.push(
      <MeasuredItem key={`${windowKey}-${i}`} index={i} offset={offset} onResize={handleResize}>
        {renderItem(i)}
      </MeasuredItem>,
    );
  }

  return (
    <div ref={containerRef} className={styles.container} onScroll={handleScroll}>
      <div className={styles.spacer} style={{ height: totalHeight + topPadding + bottomPadding }}>
        {loadingOlder && (
          <div className={styles.loadingRow} style={{ height: loadingRowHeight }}>
            Loading…
          </div>
        )}
        {visibleItems}
      </div>
    </div>
  );
}
