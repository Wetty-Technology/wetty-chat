import { useCallback, useEffect, useLayoutEffect, useRef, useState, type ReactNode } from 'react';
import styles from './VirtualScroll.module.scss';

interface VirtualScrollProps {
  totalItems: number;
  estimatedItemHeight: number;
  renderItem: (index: number) => ReactNode;
  overscan?: number;
  onLoadMore?: () => void;
  loadMoreThreshold?: number;
  loading?: boolean;
  scrollToBottomRef?: React.MutableRefObject<(() => void) | null>;
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
  onLoadMore,
  loadMoreThreshold = 500,
  loading = false,
  scrollToBottomRef,
}: VirtualScrollProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [scrollTop, setScrollTop] = useState(0);
  const [containerHeight, setContainerHeight] = useState(0);
  const prevTotalRef = useRef(totalItems);
  const hasInitialScrolled = useRef(false);
  const heightCache = useRef(new Map<number, number>());
  const isAtBottomRef = useRef(true);
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

  // Scroll to bottom on initial mount
  useLayoutEffect(() => {
    if (hasInitialScrolled.current) return;
    const el = containerRef.current;
    if (!el) return;
    el.scrollTop = totalHeight - el.clientHeight;
    setScrollTop(el.scrollTop);
    setContainerHeight(el.clientHeight);
    hasInitialScrolled.current = true;
  }, [totalHeight]);

  // When totalItems grows (items prepended at top), adjust scrollTop
  useLayoutEffect(() => {
    const prev = prevTotalRef.current;
    if (totalItems > prev && hasInitialScrolled.current) {
      const added = totalItems - prev;
      const el = containerRef.current;
      if (el) {
        // Sum heights of the newly prepended items (indices 0..added-1)
        let addedHeight = 0;
        for (let i = 0; i < added; i++) {
          addedHeight += heightCache.current.get(i) ?? estimatedItemHeight;
        }
        el.scrollTop += addedHeight;
      }
    }
    // Auto-scroll to bottom when new messages appended and user was at bottom
    if (isAtBottomRef.current && totalItems > prev) {
      const el = containerRef.current;
      if (el) {
        requestAnimationFrame(() => {
          el.scrollTop = el.scrollHeight - el.clientHeight;
        });
      }
    }
    prevTotalRef.current = totalItems;
  }, [totalItems, estimatedItemHeight]);

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

  const handleResize = useCallback((index: number, height: number) => {
    const prev = heightCache.current.get(index);
    if (prev !== height) {
      heightCache.current.set(index, height);
      forceUpdate(c => c + 1);
    }
  }, []);

  const handleScroll = useCallback(() => {
    const el = containerRef.current;
    if (!el) return;
    setScrollTop(el.scrollTop);
    setContainerHeight(el.clientHeight);

    isAtBottomRef.current = el.scrollTop + el.clientHeight >= el.scrollHeight - 30;

    if (onLoadMore && el.scrollTop < loadMoreThreshold) {
      onLoadMore();
    }
  }, [onLoadMore, loadMoreThreshold]);

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
  const topPadding = loading ? loadingRowHeight : 0;

  const visibleItems: ReactNode[] = [];
  for (let i = startIndex; i <= endIndex; i++) {
    const offset = getItemOffset(i) + topPadding;
    visibleItems.push(
      <MeasuredItem key={i} index={i} offset={offset} onResize={handleResize}>
        {renderItem(i)}
      </MeasuredItem>,
    );
  }

  return (
    <div ref={containerRef} className={styles.container} onScroll={handleScroll}>
      <div className={styles.spacer} style={{ height: totalHeight + topPadding }}>
        {loading && (
          <div className={styles.loadingRow} style={{ height: loadingRowHeight }}>
            Loading…
          </div>
        )}
        {visibleItems}
      </div>
    </div>
  );
}
