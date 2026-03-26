import { type ReactNode, useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { t } from '@lingui/core/macro';
import { HeightCache } from './virtualScroll/heightCache';
import { MeasuredRow } from './virtualScroll/MeasuredRow';
import { FenwickTree } from './virtualScroll/fenwick';
import { useStagingBatch } from './virtualScroll/useStagingBatch';
import type {
  BatchDirection,
  ChatRow,
  ChatVirtualScrollProps,
  LayoutIntent,
  MountedWindow,
  MutationType,
  PendingBatch,
  Phase,
} from './virtualScroll/types';
import {
  AT_BOTTOM_THRESHOLD_PX,
  BOOTSTRAP_BOTTOM_SEED,
  BOOTSTRAP_HEIGHT_MULTIPLIER,
  BOOTSTRAP_ITEM_RADIUS,
  EDGE_EPSILON_PX,
  EDGE_REARM_PX,
  RECENTER_ROW_THRESHOLD,
  SCROLL_IDLE_MS,
  STAGING_BATCH_SIZE,
  WINDOW_CAP,
  WINDOW_OVERSCAN,
} from './virtualScroll/types';
import styles from './ChatVirtualScroll.module.scss';

function arraysEqual(a: string[], b: string[]): boolean {
  return a.length === b.length && a.every((value, index) => value === b[index]);
}

function isPrefix(prefix: string[], full: string[]): boolean {
  if (prefix.length > full.length) return false;
  return prefix.every((value, index) => full[index] === value);
}

function isSuffix(suffix: string[], full: string[]): boolean {
  if (suffix.length > full.length) return false;
  const offset = full.length - suffix.length;
  return suffix.every((value, index) => full[offset + index] === value);
}

function classifyKeyMutation(prev: string[], next: string[]): MutationType {
  const prevMsgs = prev.filter((key) => key.startsWith('msg:'));
  const nextMsgs = next.filter((key) => key.startsWith('msg:'));

  if (arraysEqual(prevMsgs, nextMsgs)) return 'none';
  if (prevMsgs.length === 0 || nextMsgs.length === 0 || nextMsgs.length < prevMsgs.length) return 'reset';
  if (isSuffix(prevMsgs, nextMsgs)) return 'prepend';
  if (isPrefix(prevMsgs, nextMsgs)) return 'append';
  return 'reset';
}

const debugVirtualScroll = import.meta.env.DEV;
const EDGE_HINT_HEIGHT = 36;

function logVirtualScroll(event: string, details?: Record<string, unknown>) {
  if (!debugVirtualScroll) return;
  if (details) {
    console.log(`[ChatVirtualScroll] ${event}`, details);
    return;
  }

  console.log(`[ChatVirtualScroll] ${event}`);
}

function formatAnchorForLog(anchor: ChatVirtualScrollProps['initialAnchor']) {
  if (anchor.type === 'bottom') {
    return { type: 'bottom', token: anchor.token };
  }

  return { type: 'item', key: anchor.key, token: anchor.token };
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function roundScrollValue(value: number): number {
  return Math.round(value);
}

function hasMeaningfulScrollDelta(current: number, next: number): boolean {
  return Math.abs(next - current) >= 1;
}

function scrollDirection(from: number, to: number): 'up' | 'down' | 'none' {
  if (to > from) return 'down';
  if (to < from) return 'up';
  return 'none';
}

function normalizeRange(start: number, end: number, maxIndex: number): MountedWindow | null {
  if (maxIndex < 0) return null;
  const nextStart = clamp(Math.min(start, end), 0, maxIndex);
  const nextEnd = clamp(Math.max(start, end), 0, maxIndex);
  return nextStart <= nextEnd ? { start: nextStart, end: nextEnd } : null;
}

function rangesEqual(left: MountedWindow | null, right: MountedWindow | null): boolean {
  if (!left && !right) return true;
  if (!left || !right) return false;
  return left.start === right.start && left.end === right.end;
}

function unionRanges(left: MountedWindow | null, right: MountedWindow | null): MountedWindow | null {
  if (!left) return right;
  if (!right) return left;
  return { start: Math.min(left.start, right.start), end: Math.max(left.end, right.end) };
}

function capRange(range: MountedWindow, maxIndex: number): MountedWindow {
  const size = range.end - range.start + 1;
  if (size <= WINDOW_CAP || maxIndex < 0) return range;

  const center = Math.floor((range.start + range.end) / 2);
  const halfCap = Math.floor(WINDOW_CAP / 2);
  const maxStart = Math.max(0, maxIndex - WINDOW_CAP + 1);
  const start = clamp(center - halfCap, 0, maxStart);
  return { start, end: Math.min(maxIndex, start + WINDOW_CAP - 1) };
}

function estimateRowHeight(row: ChatRow): number {
  if (row.type === 'date') return 32;

  const { message } = row;
  if (message.is_deleted) return 48;

  let estimate = message.attachments?.length ? 220 : 76;
  if (message.reply_to_message) {
    estimate += 26;
  }

  return Math.min(estimate, 320);
}

function visiblePrefixHeight(rowTop: number, rowHeight: number, viewportTop: number): number {
  return clamp(viewportTop - rowTop, 0, Math.max(0, rowHeight));
}

function rangeSize(range: MountedWindow | null): number {
  if (!range) return 0;
  return range.end - range.start + 1;
}

export function ChatVirtualScroll({
  rows,
  renderRow,
  initialAnchor,
  scrollApiRef,
  loadOlder,
  loadNewer,
  header,
  bottomPadding = 0,
  onAtBottomChange,
}: ChatVirtualScrollProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const headerRef = useRef<HTMLDivElement>(null);
  const rowRefsMap = useRef(new Map<string, HTMLDivElement>());
  const heightCacheRef = useRef(new HeightCache());
  const treeRef = useRef(new FenwickTree(0));
  const treeKeysRef = useRef<string[]>([]);
  const mountedRef = useRef<MountedWindow | null>(null);

  const layoutIntentRef = useRef<LayoutIntent | null>(null);
  const isAtBottomRef = useRef(true);
  const initialAnchorRef = useRef(initialAnchor);
  initialAnchorRef.current = initialAnchor;

  const pendingScrollKeyRef = useRef<string | null>(null);
  const pendingScrollBehaviorRef = useRef<ScrollBehavior>('auto');
  const pendingScrollToBottomRef = useRef(false);
  const pendingPrependRestoreRef = useRef<{ key: string; offsetTop: number } | null>(null);
  const pendingPrependCompensationRef = useRef<number | null>(null);
  const pendingLayoutAnchorRestoreRef = useRef<{
    source: string;
    key: string;
    offsetTop: number;
  } | null>(null);
  const pendingAnchorDriftCheckRef = useRef<{
    source: string;
    key: string;
    offsetTop: number;
  } | null>(null);
  const mutationSnapshotRef = useRef<{
    mutation: MutationType;
    anchor: { key: string; offsetTop: number } | null;
    rowCountDelta: number;
  } | null>(null);
  const recenterTargetIndexRef = useRef<number | null>(null);

  const scrollIdleTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const scrollRafRef = useRef<number | null>(null);
  const bottomSettleRafRef = useRef<number | null>(null);
  const topLoadArmedRef = useRef(true);
  const bottomLoadArmedRef = useRef(true);

  const rowKeys = useMemo(() => rows.map((row) => row.key), [rows]);
  const keyToIndex = useMemo(() => {
    const map = new Map<string, number>();
    rowKeys.forEach((key, index) => map.set(key, index));
    return map;
  }, [rowKeys]);
  const prevKeysRef = useRef<string[]>([]);

  const [phase, setPhase] = useState<Phase>('WAITING_VIEWPORT');
  const phaseRef = useRef<Phase>('WAITING_VIEWPORT');
  const [containerHeight, setContainerHeight] = useState(0);
  const [headerHeight, setHeaderHeight] = useState(0);
  const [renderTick, setRenderTick] = useState(0);
  const triggerRender = useCallback(() => setRenderTick((value) => value + 1), []);

  const setPhaseState = useCallback((next: Phase) => {
    if (phaseRef.current !== next) {
      logVirtualScroll('phase-change', {
        from: phaseRef.current,
        to: next,
        rowCount: rowKeys.length,
        mounted: mountedRef.current,
      });
    }
    phaseRef.current = next;
    setPhase(next);
  }, [rowKeys.length]);

  if (treeKeysRef.current !== rowKeys) {
    const tree = new FenwickTree(rowKeys.length);
    for (let index = 0; index < rowKeys.length; index += 1) {
      const key = rowKeys[index];
      const row = rows[index];
      if (!row) continue;
      tree.set(index, heightCacheRef.current.get(key) ?? estimateRowHeight(row));
    }
    treeRef.current = tree;
    treeKeysRef.current = rowKeys;
  }

  const topChromeHeight = useCallback(() => {
    return headerHeight;
  }, [headerHeight]);

  const totalHeight = useCallback(() => treeRef.current.total(), []);

  const offsetOf = useCallback((index: number) => treeRef.current.prefixSum(index), []);

  const heightBetween = useCallback((start: number, endExclusive: number) => {
    if (endExclusive <= start) return 0;
    return treeRef.current.prefixSum(endExclusive) - treeRef.current.prefixSum(start);
  }, []);

  const indexAtOffset = useCallback(
    (offset: number) => {
      if (rowKeys.length === 0) return 0;
      return treeRef.current.findIndexByOffset(offset);
    },
    [rowKeys.length],
  );

  const isMeasured = useCallback(
    (index: number) => {
      const key = rowKeys[index];
      return key ? heightCacheRef.current.has(key) : false;
    },
    [rowKeys],
  );

  const allMeasured = useCallback(
    (start: number, end: number) => {
      if (start > end) return true;
      for (let index = start; index <= end; index += 1) {
        if (!isMeasured(index)) return false;
      }
      return true;
    },
    [isMeasured],
  );

  const firstUnmeasuredInRange = useCallback(
    (start: number, end: number) => {
      for (let index = start; index <= end; index += 1) {
        if (!isMeasured(index)) return index;
      }
      return -1;
    },
    [isMeasured],
  );

  const deriveVisibleRange = useCallback(
    (scrollTop: number, viewportHeight: number): MountedWindow | null => {
      if (rowKeys.length === 0) return null;
      const contentTop = Math.max(0, scrollTop - topChromeHeight());
      const visibleStart = indexAtOffset(contentTop);
      const visibleEnd = indexAtOffset(contentTop + viewportHeight);
      return normalizeRange(visibleStart, visibleEnd, rowKeys.length - 1);
    },
    [indexAtOffset, rowKeys.length, topChromeHeight],
  );

  const deriveDesiredRange = useCallback(
    (scrollTop: number, viewportHeight: number): MountedWindow | null => {
      const visible = deriveVisibleRange(scrollTop, viewportHeight);
      if (!visible) return null;
      const desired = normalizeRange(
        visible.start - WINDOW_OVERSCAN,
        visible.end + WINDOW_OVERSCAN,
        rowKeys.length - 1,
      );
      return desired ? capRange(desired, rowKeys.length - 1) : null;
    },
    [deriveVisibleRange, rowKeys.length],
  );

  const topSpacerHeight = useCallback(() => {
    const mounted = mountedRef.current;
    return mounted ? offsetOf(mounted.start) : 0;
  }, [offsetOf]);

  const bottomSpacerHeight = useCallback(() => {
    const mounted = mountedRef.current;
    return mounted ? totalHeight() - offsetOf(mounted.end + 1) : 0;
  }, [offsetOf, totalHeight]);

  const updateMountedRange = useCallback(
    (next: MountedWindow | null) => {
      if (rangesEqual(mountedRef.current, next)) return false;
      mountedRef.current = next;
      triggerRender();
      return true;
    },
    [triggerRender],
  );

  const scrollDistances = useCallback(() => {
    const container = containerRef.current;
    if (!container) return null;

    return {
      fromTop: container.scrollTop - topChromeHeight(),
      fromBottom: container.scrollHeight - (container.scrollTop + container.clientHeight),
    };
  }, [topChromeHeight]);

  const isAtTopEdge = useCallback(() => {
    const distances = scrollDistances();
    return distances ? distances.fromTop <= EDGE_EPSILON_PX : false;
  }, [scrollDistances]);

  const isAtBottomEdge = useCallback(() => {
    const distances = scrollDistances();
    return distances ? distances.fromBottom <= EDGE_EPSILON_PX : false;
  }, [scrollDistances]);

  const updateAtBottom = useCallback(() => {
    const container = containerRef.current;
    if (!container) return;
    if (phaseRef.current !== 'READY') return;

    const visualBottom =
      container.scrollHeight - (container.scrollTop + container.clientHeight) <= AT_BOTTOM_THRESHOLD_PX;
    const atBottom = visualBottom && !loadNewer?.hasMore;
    if (atBottom !== isAtBottomRef.current) {
      isAtBottomRef.current = atBottom;
      onAtBottomChange?.(atBottom);
    }
  }, [loadNewer?.hasMore, onAtBottomChange]);

  const scrollToBottomInternal = useCallback(() => {
    const container = containerRef.current;
    if (!container) return;

    const target = roundScrollValue(container.scrollHeight - container.clientHeight);
    if (!hasMeaningfulScrollDelta(container.scrollTop, target)) return;

    logVirtualScroll('scroll-position-write', {
      source: 'scrollToBottomInternal',
      from: container.scrollTop,
      to: target,
      direction: scrollDirection(container.scrollTop, target),
    });
    container.scrollTop = target;
  }, []);

  const scrollToKeyInternal = useCallback((key: string, behavior: ScrollBehavior = 'auto') => {
    const container = containerRef.current;
    const row = rowRefsMap.current.get(key);
    if (!container || !row) return;

    const target = roundScrollValue(
      Math.max(0, Math.min(row.offsetTop, container.scrollHeight - container.clientHeight)),
    );
    if (behavior === 'auto' && !hasMeaningfulScrollDelta(container.scrollTop, target)) return;
    container.scrollTo({ top: target, behavior });
  }, []);

  const restoreAnchorOffset = useCallback((key: string, offsetTop: number) => {
    const container = containerRef.current;
    const row = rowRefsMap.current.get(key);
    if (!container || !row) return false;

    const target = roundScrollValue(row.offsetTop - offsetTop);
    const maxScrollTop = Math.max(0, container.scrollHeight - container.clientHeight);
    const nextScrollTop = roundScrollValue(Math.max(0, Math.min(target, maxScrollTop)));
    if (!hasMeaningfulScrollDelta(container.scrollTop, nextScrollTop)) return true;

    logVirtualScroll('scroll-position-write', {
      source: 'restoreAnchorOffset',
      key,
      offsetTop,
      from: container.scrollTop,
      to: nextScrollTop,
      direction: scrollDirection(container.scrollTop, nextScrollTop),
    });
    container.scrollTop = nextScrollTop;
    return true;
  }, []);

  const captureVisibleAnchor = useCallback(() => {
    const container = containerRef.current;
    const mounted = mountedRef.current;
    if (!container || !mounted) return null;

    const containerRect = container.getBoundingClientRect();
    let firstVisibleMessage: { key: string; offsetTop: number } | null = null;
    let firstMountedMessage: { key: string; offsetTop: number } | null = null;

    for (let index = mounted.start; index <= mounted.end; index += 1) {
      const key = rowKeys[index];
      const row = rowRefsMap.current.get(key);
      if (!key || !row) continue;

      if (key.startsWith('msg:') && !firstMountedMessage) {
        firstMountedMessage = { key, offsetTop: roundScrollValue(row.offsetTop) };
      }

      const rect = row.getBoundingClientRect();
      if (rect.bottom <= containerRect.top || rect.top >= containerRect.bottom) continue;

      const anchor = { key, offsetTop: roundScrollValue(rect.top - containerRect.top) };
      if (key.startsWith('msg:')) {
        firstVisibleMessage = anchor;
        break;
      }
    }

    return firstVisibleMessage ?? firstMountedMessage;
  }, [rowKeys]);

  const logMutationSnapshot = useCallback((event: string, details?: Record<string, unknown>) => {
    logVirtualScroll(event, {
      mutationSnapshot: mutationSnapshotRef.current,
      mounted: mountedRef.current,
      ...details,
    });
  }, []);

  const registerRow = useCallback((key: string, node: HTMLDivElement | null) => {
    if (node) rowRefsMap.current.set(key, node);
    else rowRefsMap.current.delete(key);
  }, []);

  const scheduleBottomSettle = useCallback(() => {
    if (bottomSettleRafRef.current != null) {
      cancelAnimationFrame(bottomSettleRafRef.current);
    }

    let framesRemaining = 2;
    const settle = () => {
      const container = containerRef.current;
      if (!container) {
        bottomSettleRafRef.current = null;
        return;
      }

      scrollToBottomInternal();
      updateAtBottom();
      framesRemaining -= 1;
      if (framesRemaining > 0) {
        bottomSettleRafRef.current = requestAnimationFrame(settle);
        return;
      }

      bottomSettleRafRef.current = null;
    };

    bottomSettleRafRef.current = requestAnimationFrame(settle);
  }, [scrollToBottomInternal, updateAtBottom]);

  const createBatch = useCallback(
    (start: number, end: number, direction: BatchDirection, reason: PendingBatch['reason']): PendingBatch | null => {
      const range = normalizeRange(start, end, rowKeys.length - 1);
      if (!range) return null;
      const keys = rowKeys.slice(range.start, range.end + 1);
      if (keys.length === 0) return null;
      return { direction, reason, keys };
    },
    [rowKeys],
  );

  const handleBatchReady = useCallback(
    (batch: PendingBatch, heights: Map<string, number>) => {
      const container = containerRef.current;
      const viewportTop = container ? Math.max(0, container.scrollTop - topChromeHeight()) : 0;
      const viewportBottom = container ? viewportTop + container.clientHeight : viewportTop;
      const anchorBeforeBatch = phaseRef.current === 'READY' ? captureVisibleAnchor() : null;

      let preserveHeightDelta = 0;
      const batchIndices: number[] = [];
      const rowAdjustments: Array<{
        key: string;
        index: number;
        previousHeight: number;
        nextHeight: number;
        delta: number;
        preserveContribution: number;
        rowTopBefore: number;
        rowBottomBefore: number;
        rowTopAfter: number;
        rowBottomAfter: number;
        wasAboveViewportBefore: boolean;
        isAboveViewportAfter: boolean;
        intersectedViewportBefore: boolean;
        intersectsViewportAfter: boolean;
      }> = [];

      for (const [key, height] of heights) {
        const index = keyToIndex.get(key);
        if (index == null) continue;

        batchIndices.push(index);
        const previousHeight = treeRef.current.get(index);
        const rowTopBefore = offsetOf(index);
        const rowBottomBefore = rowTopBefore + previousHeight;
        treeRef.current.set(index, height);
        heightCacheRef.current.set(key, height);
        const rowTopAfter = offsetOf(index);
        const rowBottomAfter = rowTopAfter + height;

        const delta = height - previousHeight;
        const preserveContribution =
          visiblePrefixHeight(rowTopAfter, height, viewportTop) -
          visiblePrefixHeight(rowTopBefore, previousHeight, viewportTop);
        rowAdjustments.push({
          key,
          index,
          previousHeight,
          nextHeight: height,
          delta,
          rowTopBefore,
          rowBottomBefore,
          rowTopAfter,
          rowBottomAfter,
          wasAboveViewportBefore: rowTopBefore < viewportTop,
          isAboveViewportAfter: rowTopAfter < viewportTop,
          intersectedViewportBefore: rowBottomBefore > viewportTop && rowTopBefore < viewportBottom,
          intersectsViewportAfter: rowBottomAfter > viewportTop && rowTopAfter < viewportBottom,
          preserveContribution,
        });
        if (phaseRef.current === 'READY' && preserveContribution !== 0) {
          preserveHeightDelta += preserveContribution;
        }
      }

      if (batchIndices.length > 0) {
        const measuredRange = {
          start: Math.min(...batchIndices),
          end: Math.max(...batchIndices),
        };

        if (phaseRef.current === 'BOOTSTRAP') {
          mountedRef.current = unionRanges(mountedRef.current, measuredRange);
        } else if (phaseRef.current === 'RECENTERING') {
          mountedRef.current = unionRanges(mountedRef.current, measuredRange);
        } else {
          mountedRef.current = unionRanges(mountedRef.current, measuredRange);
        }
      }

      if (preserveHeightDelta !== 0 && !pendingScrollToBottomRef.current) {
        layoutIntentRef.current = { preserveHeightDelta };
      }
      if (anchorBeforeBatch) {
        pendingLayoutAnchorRestoreRef.current = {
          source: `batch:${batch.reason}:${batch.direction}`,
          key: anchorBeforeBatch.key,
          offsetTop: anchorBeforeBatch.offsetTop,
        };
        pendingAnchorDriftCheckRef.current = {
          source: `batch:${batch.reason}:${batch.direction}`,
          key: anchorBeforeBatch.key,
          offsetTop: anchorBeforeBatch.offsetTop,
        };
      }

      logVirtualScroll('batch-commit', {
        reason: batch.reason,
        direction: batch.direction,
        batchSize: batch.keys.length,
        preserveHeightDelta,
        phase: phaseRef.current,
        viewportTop,
        viewportBottom,
        mountedBefore: mountedRef.current,
        rowAdjustments: rowAdjustments
          .filter((item) => item.delta !== 0)
          .sort((left, right) => Math.abs(right.delta) - Math.abs(left.delta))
          .slice(0, 6),
      });
      if (debugVirtualScroll) {
        const compactRows = rowAdjustments
          .filter((item) => item.delta !== 0)
          .sort((left, right) => Math.abs(right.delta) - Math.abs(left.delta))
          .slice(0, 6)
          .map((item) => ({
            key: item.key,
            index: item.index,
            delta: item.delta,
            preserveContribution: item.preserveContribution,
            prev: item.previousHeight,
            next: item.nextHeight,
            topBefore: item.rowTopBefore,
            bottomBefore: item.rowBottomBefore,
            topAfter: item.rowTopAfter,
            bottomAfter: item.rowBottomAfter,
            aboveBefore: item.wasAboveViewportBefore,
            aboveAfter: item.isAboveViewportAfter,
            intersectsBefore: item.intersectedViewportBefore,
            intersectsAfter: item.intersectsViewportAfter,
          }));
        console.log(
          `[ChatVirtualScroll] batch-commit-rows ${JSON.stringify({
            reason: batch.reason,
            direction: batch.direction,
            phase: phaseRef.current,
            viewportTop,
            viewportBottom,
            preserveHeightDelta,
            rows: compactRows,
          })}`,
        );
      }

      triggerRender();
    },
    [captureVisibleAnchor, keyToIndex, offsetOf, topChromeHeight, triggerRender],
  );

  const { pendingBatch, queueBatch, cancelBatch, handleStagingMeasure } = useStagingBatch(handleBatchReady);

  const queueRangeBatch = useCallback(
    (start: number, end: number, direction: BatchDirection, reason: PendingBatch['reason']) => {
      const batch = createBatch(start, end, direction, reason);
      if (!batch) return false;
      return queueBatch(batch);
    },
    [createBatch, queueBatch],
  );

  const queueAdjacentBatch = useCallback(
    (direction: BatchDirection, reason: PendingBatch['reason']) => {
      const mounted = mountedRef.current;
      if (!mounted || pendingBatch) return false;

      if (direction === 'backward') {
        if (mounted.start <= 0) return false;
        return queueRangeBatch(Math.max(0, mounted.start - STAGING_BATCH_SIZE), mounted.start - 1, direction, reason);
      }

      if (mounted.end >= rowKeys.length - 1) return false;
      return queueRangeBatch(
        mounted.end + 1,
        Math.min(rowKeys.length - 1, mounted.end + STAGING_BATCH_SIZE),
        direction,
        reason,
      );
    },
    [pendingBatch, queueRangeBatch, rowKeys.length],
  );

  const enterRecentering = useCallback(
    (targetIndex: number) => {
      recenterTargetIndexRef.current = clamp(targetIndex, 0, Math.max(0, rowKeys.length - 1));
      cancelBatch();
      mountedRef.current = null;
      setPhaseState('RECENTERING');
      triggerRender();
    },
    [cancelBatch, rowKeys.length, setPhaseState, triggerRender],
  );

  const maybeUpdateMountedForScroll = useCallback(() => {
    const container = containerRef.current;
    const mounted = mountedRef.current;
    if (!container || !mounted || rowKeys.length === 0) return;
    if (phaseRef.current !== 'READY') return;
    if (pendingPrependRestoreRef.current) return;

    const desired = deriveDesiredRange(container.scrollTop, container.clientHeight);
    if (!desired) return;

    if (desired.start < mounted.start - RECENTER_ROW_THRESHOLD || desired.end > mounted.end + RECENTER_ROW_THRESHOLD) {
      const visible = deriveVisibleRange(container.scrollTop, container.clientHeight);
      const targetIndex = visible ? Math.floor((visible.start + visible.end) / 2) : desired.start;
      logVirtualScroll('recenter-trigger', {
        mounted,
        desired,
        visible,
        targetIndex,
        scrollTop: container.scrollTop,
      });
      enterRecentering(targetIndex);
      return;
    }

    if (allMeasured(desired.start, desired.end)) {
      updateMountedRange(capRange(desired, rowKeys.length - 1));
      return;
    }

    if (pendingBatch) return;

    const firstMissing = firstUnmeasuredInRange(desired.start, desired.end);
    if (firstMissing === -1) return;

    if (firstMissing < mounted.start) {
      logVirtualScroll('preload-trigger', {
        direction: 'backward',
        mounted,
        desired,
        firstMissing,
        scrollTop: container.scrollTop,
      });
      queueAdjacentBatch('backward', 'preload');
      return;
    }
    if (firstMissing > mounted.end) {
      logVirtualScroll('preload-trigger', {
        direction: 'forward',
        mounted,
        desired,
        firstMissing,
        scrollTop: container.scrollTop,
      });
      queueAdjacentBatch('forward', 'preload');
      return;
    }

    const start = Math.max(0, firstMissing - Math.floor(STAGING_BATCH_SIZE / 2));
    const end = Math.min(rowKeys.length - 1, start + STAGING_BATCH_SIZE - 1);
    logVirtualScroll('preload-trigger', {
      direction: firstMissing <= desired.start ? 'backward' : 'forward',
      mounted,
      desired,
      firstMissing,
      start,
      end,
      scrollTop: container.scrollTop,
    });
    queueRangeBatch(start, end, firstMissing <= desired.start ? 'backward' : 'forward', 'preload');
  }, [
    allMeasured,
    deriveDesiredRange,
    deriveVisibleRange,
    enterRecentering,
    firstUnmeasuredInRange,
    pendingBatch,
    queueAdjacentBatch,
    queueRangeBatch,
    rowKeys.length,
    updateMountedRange,
  ]);

  const ensureBottomMeasured = useCallback(() => {
    if (rowKeys.length === 0 || pendingBatch) return;

    const start = Math.max(0, rowKeys.length - BOOTSTRAP_BOTTOM_SEED);
    if (allMeasured(start, rowKeys.length - 1)) {
      updateMountedRange(capRange({ start, end: rowKeys.length - 1 }, rowKeys.length - 1));
      layoutIntentRef.current = { scrollToBottom: true };
      triggerRender();
      return;
    }

    queueRangeBatch(start, rowKeys.length - 1, 'forward', 'jump');
  }, [allMeasured, pendingBatch, queueRangeBatch, rowKeys.length, triggerRender, updateMountedRange]);

  const handleMountedMeasure = useCallback(
    (key: string, height: number) => {
      const index = keyToIndex.get(key);
      if (index == null) return;
      const rowModel = rows[index];
      const attachments = rowModel?.type === 'message' ? (rowModel.message.attachments ?? []) : [];
      const hasAttachments = attachments.length > 0;
      const hasUnknownAttachmentDimensions = attachments.some(
        (attachment) =>
          (attachment.kind.startsWith('image/') || attachment.kind.startsWith('video/')) &&
          (!(attachment.width && attachment.width > 0) || !(attachment.height && attachment.height > 0)),
      );

      const previousHeight = treeRef.current.get(index);
      if (previousHeight === height && heightCacheRef.current.get(key) === height) return;

      treeRef.current.set(index, height);
      heightCacheRef.current.set(key, height);

      const container = containerRef.current;
      const rowNode = rowRefsMap.current.get(key);
      if (!container || !rowNode) return;

      if (isAtBottomRef.current) {
        logVirtualScroll('mounted-row-resize', {
          key,
          index,
          phase: phaseRef.current,
          hasAttachments,
          hasUnknownAttachmentDimensions,
          attachmentKinds: attachments.map((attachment) => attachment.kind),
          previousHeight,
          nextHeight: height,
          delta: height - previousHeight,
          scrollTop: container.scrollTop,
          rowOffsetTop: rowNode.offsetTop,
          strategy: 'bottom-lock',
        });
        scrollToBottomInternal();
        scheduleBottomSettle();
        return;
      }

      const delta = height - previousHeight;
      if (delta === 0) return;
      const preserveContribution =
        visiblePrefixHeight(rowNode.offsetTop, height, container.scrollTop) -
        visiblePrefixHeight(rowNode.offsetTop, previousHeight, container.scrollTop);
      if (preserveContribution !== 0) {
        const nextScrollTop = roundScrollValue(container.scrollTop + preserveContribution);
        logVirtualScroll('mounted-row-resize', {
          key,
          index,
          phase: phaseRef.current,
          hasAttachments,
          hasUnknownAttachmentDimensions,
          attachmentKinds: attachments.map((attachment) => attachment.kind),
          previousHeight,
          nextHeight: height,
          delta,
          preserveContribution,
          scrollTop: container.scrollTop,
          nextScrollTop,
          rowOffsetTop: rowNode.offsetTop,
          strategy: 'preserve-above-viewport',
        });
        if (hasMeaningfulScrollDelta(container.scrollTop, nextScrollTop)) {
          container.scrollTop = nextScrollTop;
        }
      } else {
        logVirtualScroll('mounted-row-resize', {
          key,
          index,
          phase: phaseRef.current,
          hasAttachments,
          hasUnknownAttachmentDimensions,
          attachmentKinds: attachments.map((attachment) => attachment.kind),
          previousHeight,
          nextHeight: height,
          delta,
          preserveContribution,
          scrollTop: container.scrollTop,
          rowOffsetTop: rowNode.offsetTop,
          strategy: 'natural-reflow',
        });
      }

    },
    [keyToIndex, rows, scheduleBottomSettle, scrollToBottomInternal],
  );

  const handleScrollIdle = useCallback(() => {
    maybeUpdateMountedForScroll();

    const distances = scrollDistances();
    if (!distances) return;

    const atTopEdge = isAtTopEdge();
    const atBottomEdge = isAtBottomEdge();

    logVirtualScroll('scroll-idle', {
      phase: phaseRef.current,
      topDistance: distances.fromTop,
      bottomDistance: distances.fromBottom,
      atTopEdge,
      atBottomEdge,
      loadOlderLoading: !!loadOlder.loading,
      loadNewerLoading: !!loadNewer?.loading,
      loadOlderHasMore: loadOlder.hasMore,
      loadNewerHasMore: !!loadNewer?.hasMore,
      mounted: mountedRef.current,
      pendingBatch: pendingBatch?.keys.length ?? 0,
      logicalAtBottom: isAtBottomRef.current,
      pendingScrollToBottom: pendingScrollToBottomRef.current,
    });

    if (atTopEdge) {
      if (loadOlder.hasMore && !loadOlder.loading && topLoadArmedRef.current) {
        topLoadArmedRef.current = false;
        logVirtualScroll('load-older-trigger', { reason: 'idle-top-edge' });
        loadOlder.onLoad();
      }
    }

    if (atBottomEdge && loadNewer) {
      if (loadNewer.hasMore && !loadNewer.loading && bottomLoadArmedRef.current) {
        bottomLoadArmedRef.current = false;
        logVirtualScroll('load-newer-trigger', {
          reason: 'idle-bottom-edge',
          logicalAtBottom: isAtBottomRef.current,
          hasMore: loadNewer.hasMore,
        });
        loadNewer.onLoad();
      }
    }
  }, [isAtBottomEdge, isAtTopEdge, loadNewer, loadOlder, maybeUpdateMountedForScroll, pendingBatch, scrollDistances]);

  const handleScroll = useCallback(() => {
    if (scrollRafRef.current == null) {
      scrollRafRef.current = requestAnimationFrame(() => {
        scrollRafRef.current = null;
        maybeUpdateMountedForScroll();
      });
    }

    updateAtBottom();

    if (scrollIdleTimerRef.current) clearTimeout(scrollIdleTimerRef.current);
    scrollIdleTimerRef.current = setTimeout(handleScrollIdle, SCROLL_IDLE_MS);

    const distances = scrollDistances();
    if (!distances) return;

    if (distances.fromTop >= EDGE_REARM_PX) {
      topLoadArmedRef.current = true;
    }
    if (distances.fromBottom >= EDGE_REARM_PX) {
      bottomLoadArmedRef.current = true;
    }
  }, [handleScrollIdle, maybeUpdateMountedForScroll, scrollDistances, updateAtBottom]);

  useLayoutEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const mutation = classifyKeyMutation(prevKeysRef.current, rowKeys);
    const intent = layoutIntentRef.current;

    if (intent?.preserveHeightDelta && intent.preserveHeightDelta !== 0) {
      const nextScrollTop = roundScrollValue(container.scrollTop + intent.preserveHeightDelta);
      if (hasMeaningfulScrollDelta(container.scrollTop, nextScrollTop)) {
        logVirtualScroll('scroll-position-write', {
          source: 'preserveHeightDelta',
          preserveHeightDelta: intent.preserveHeightDelta,
          from: container.scrollTop,
          to: nextScrollTop,
          direction: scrollDirection(container.scrollTop, nextScrollTop),
        });
        container.scrollTop = nextScrollTop;
      }
    }

    if (intent?.scrollToBottom) {
      scrollToBottomInternal();
      scheduleBottomSettle();
      pendingScrollToBottomRef.current = false;
    }

    if (intent?.scrollToKey) {
      scrollToKeyInternal(intent.scrollToKey.key, intent.scrollToKey.behavior);
      if (pendingScrollKeyRef.current === intent.scrollToKey.key) {
        pendingScrollKeyRef.current = null;
      }
    }

    if (pendingScrollKeyRef.current && !intent?.scrollToKey) {
      const targetRow = rowRefsMap.current.get(pendingScrollKeyRef.current);
      if (targetRow) {
        scrollToKeyInternal(pendingScrollKeyRef.current, pendingScrollBehaviorRef.current);
        pendingScrollKeyRef.current = null;
      }
    }

    const pendingPrependRestore = pendingPrependRestoreRef.current;
    const pendingPrependCompensation = pendingPrependCompensationRef.current;
    if (pendingPrependCompensation && pendingPrependCompensation !== 0) {
      const nextScrollTop = roundScrollValue(container.scrollTop + pendingPrependCompensation);
      logMutationSnapshot('prepend-height-compensation', {
        preserveHeightDelta: pendingPrependCompensation,
        from: container.scrollTop,
        to: nextScrollTop,
      });
      container.scrollTop = nextScrollTop;
      pendingPrependCompensationRef.current = null;
    }

    const pendingLayoutAnchorRestore = pendingLayoutAnchorRestoreRef.current;
    if (pendingLayoutAnchorRestore) {
      logVirtualScroll('layout-anchor-restore-attempt', {
        source: pendingLayoutAnchorRestore.source,
        key: pendingLayoutAnchorRestore.key,
        offsetTop: pendingLayoutAnchorRestore.offsetTop,
      });
      const restored = restoreAnchorOffset(pendingLayoutAnchorRestore.key, pendingLayoutAnchorRestore.offsetTop);
      if (restored) {
        pendingLayoutAnchorRestoreRef.current = null;
        logVirtualScroll('layout-anchor-restore-complete', {
          source: pendingLayoutAnchorRestore.source,
          key: pendingLayoutAnchorRestore.key,
        });
      }
    }

    if (pendingPrependRestore) {
      logMutationSnapshot('prepend-restore-attempt', {
        key: pendingPrependRestore.key,
        offsetTop: pendingPrependRestore.offsetTop,
      });
      const restored = restoreAnchorOffset(pendingPrependRestore.key, pendingPrependRestore.offsetTop);
      if (restored) {
        pendingPrependRestoreRef.current = null;
        mutationSnapshotRef.current = null;
        logVirtualScroll('prepend-restore-complete');
      } else {
        logMutationSnapshot('prepend-restore-missed-anchor', {
          key: pendingPrependRestore.key,
        });
      }
    }

    const pendingAnchorDriftCheck = pendingAnchorDriftCheckRef.current;
    if (pendingAnchorDriftCheck) {
      const row = rowRefsMap.current.get(pendingAnchorDriftCheck.key);
      if (row) {
        const containerRect = container.getBoundingClientRect();
        const currentOffsetTop = roundScrollValue(row.getBoundingClientRect().top - containerRect.top);
        logVirtualScroll('anchor-drift-check', {
          source: pendingAnchorDriftCheck.source,
          key: pendingAnchorDriftCheck.key,
          expectedOffsetTop: pendingAnchorDriftCheck.offsetTop,
          actualOffsetTop: currentOffsetTop,
          drift: currentOffsetTop - pendingAnchorDriftCheck.offsetTop,
          scrollTop: container.scrollTop,
        });
        pendingAnchorDriftCheckRef.current = null;
      }
    }

    if (mutation === 'reset' && rowKeys.length > 0) {
      logVirtualScroll('rows-reset', {
        previousCount: prevKeysRef.current.length,
        nextCount: rowKeys.length,
      });
      cancelBatch();
      mountedRef.current = null;
      setPhaseState(containerHeight > 0 ? 'BOOTSTRAP' : 'WAITING_VIEWPORT');
      triggerRender();
    } else if (mutation === 'append' && isAtBottomRef.current && !intent?.scrollToKey) {
      logVirtualScroll('append-bottom-lock', {
        pendingScrollToBottom: pendingScrollToBottomRef.current,
      });
      pendingScrollToBottomRef.current = true;
      ensureBottomMeasured();
    } else if (mutation === 'append') {
      logVirtualScroll('append-preserve-natural-position', {
        logicalAtBottom: isAtBottomRef.current,
        visualBottomDistance: container.scrollHeight - (container.scrollTop + container.clientHeight),
      });
    }

    updateAtBottom();
    layoutIntentRef.current = null;
    prevKeysRef.current = rowKeys;
  }, [
    rowKeys,
    renderTick,
    cancelBatch,
    containerHeight,
    ensureBottomMeasured,
    restoreAnchorOffset,
    scheduleBottomSettle,
    logMutationSnapshot,
    scrollToBottomInternal,
    scrollToKeyInternal,
    setPhaseState,
    triggerRender,
    updateAtBottom,
  ]);

  useLayoutEffect(() => {
    const container = containerRef.current;
    if (!container || !debugVirtualScroll) return;

    const mounted = mountedRef.current;
    const topSpacer = mounted ? topSpacerHeight() : 0;
    const bottomSpacer = mounted ? bottomSpacerHeight() : 0;
    const mountedContentHeight = mounted ? heightBetween(mounted.start, mounted.end + 1) : 0;
    const contentPaddingTop = (loadOlder.hasMore || loadOlder.loading) ? EDGE_HINT_HEIGHT : 0;
    const mountedTop = topSpacer + contentPaddingTop;
    const mountedBottom = mountedTop + mountedContentHeight;
    const viewportTop = container.scrollTop;
    const viewportBottom = viewportTop + container.clientHeight;
    const mountedIntersectsViewport = mountedBottom > viewportTop && mountedTop < viewportBottom;
    const mountedVisibleHeight = mounted
      ? Math.max(0, Math.min(mountedBottom, viewportBottom) - Math.max(mountedTop, viewportTop))
      : 0;
    const showLoadingScrim = phase === 'WAITING_VIEWPORT' || phase === 'BOOTSTRAP' || phase === 'RECENTERING';

    logVirtualScroll('render-state', {
      phase,
      rowCount: rowKeys.length,
      mounted,
      pendingBatch: pendingBatch
        ? {
            reason: pendingBatch.reason,
            direction: pendingBatch.direction,
            size: pendingBatch.keys.length,
            firstKey: pendingBatch.keys[0] ?? null,
            lastKey: pendingBatch.keys[pendingBatch.keys.length - 1] ?? null,
          }
        : null,
      scrollTop: container.scrollTop,
      scrollHeight: container.scrollHeight,
      clientHeight: container.clientHeight,
      topSpacer,
      bottomSpacer,
      mountedContentHeight,
      mountedTop,
      mountedBottom,
      mountedIntersectsViewport,
      mountedVisibleHeight,
      initialAnchor: formatAnchorForLog(initialAnchorRef.current),
      showLoadingScrim,
      bootstrapRevealState:
        phase === 'BOOTSTRAP'
          ? {
              mountedSize: rangeSize(mounted),
              mountedIntersectsViewport,
              mountedVisibleHeight,
              pendingBatchSize: pendingBatch?.keys.length ?? 0,
            }
          : null,
    });

  }, [bottomSpacerHeight, heightBetween, loadOlder.hasMore, loadOlder.loading, pendingBatch, phase, renderTick, rowKeys.length, topSpacerHeight]);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    let previousHeight = container.clientHeight;
    const observer = new ResizeObserver(() => {
      const nextHeight = container.clientHeight;
      if (nextHeight === previousHeight) return;
      previousHeight = nextHeight;
      setContainerHeight(nextHeight);

      if (phaseRef.current === 'WAITING_VIEWPORT' && nextHeight > 0) {
        setPhaseState('BOOTSTRAP');
      }

      if (phaseRef.current === 'READY' && isAtBottomRef.current) {
        scrollToBottomInternal();
        scheduleBottomSettle();
      }
    });

    setContainerHeight(container.clientHeight);
    if (phaseRef.current === 'WAITING_VIEWPORT' && container.clientHeight > 0) {
      setPhaseState('BOOTSTRAP');
    }

    observer.observe(container);
    return () => observer.disconnect();
  }, [scheduleBottomSettle, scrollToBottomInternal, setPhaseState]);

  useEffect(() => {
    const node = headerRef.current;
    if (!node) {
      setHeaderHeight(0);
      return;
    }

    const observer = new ResizeObserver(() => {
      setHeaderHeight(node.getBoundingClientRect().height);
    });

    observer.observe(node);
    return () => observer.disconnect();
  }, [header]);

  useEffect(() => {
    rowRefsMap.current.clear();
    cancelBatch();
    mountedRef.current = null;
    recenterTargetIndexRef.current = null;
    pendingScrollKeyRef.current = null;
    pendingScrollToBottomRef.current = false;
    pendingPrependRestoreRef.current = null;
    pendingPrependCompensationRef.current = null;
    pendingLayoutAnchorRestoreRef.current = null;
    mutationSnapshotRef.current = null;
    layoutIntentRef.current = null;
    prevKeysRef.current = rowKeys;

    if (bottomSettleRafRef.current != null) {
      cancelAnimationFrame(bottomSettleRafRef.current);
      bottomSettleRafRef.current = null;
    }

    const container = containerRef.current;
    if (container) {
      logVirtualScroll('initial-anchor-reset-effect', {
        anchor: formatAnchorForLog(initialAnchor),
        previousScrollTop: container.scrollTop,
        rowCount: rowKeys.length,
      });
      container.scrollTop = 0;
    }

    isAtBottomRef.current = initialAnchor.type === 'bottom';
    onAtBottomChange?.(initialAnchor.type === 'bottom');
    setPhaseState(containerHeight > 0 ? 'BOOTSTRAP' : 'WAITING_VIEWPORT');
    triggerRender();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initialAnchor.token]);

  useEffect(() => {
    if (phase !== 'BOOTSTRAP') return;
    if (pendingBatch || containerHeight <= 0 || rowKeys.length === 0) return;

    const mounted = mountedRef.current;
    const anchor = initialAnchorRef.current;

    if (!mounted) {
      if (anchor.type === 'bottom') {
        queueRangeBatch(
          Math.max(0, rowKeys.length - BOOTSTRAP_BOTTOM_SEED),
          rowKeys.length - 1,
          'backward',
          'bootstrap',
        );
      } else {
        const anchorIndex = keyToIndex.get(anchor.key) ?? rowKeys.length - 1;
        queueRangeBatch(
          Math.max(0, anchorIndex - BOOTSTRAP_ITEM_RADIUS),
          Math.min(rowKeys.length - 1, anchorIndex + BOOTSTRAP_ITEM_RADIUS),
          'forward',
          'bootstrap',
        );
      }
      return;
    }

    if (anchor.type === 'bottom') {
      const measuredHeight = heightBetween(mounted.start, mounted.end + 1);
      const currentTopSpacer = offsetOf(mounted.start);
      const currentMountedBottom = currentTopSpacer + measuredHeight;
      const viewportTop = containerRef.current?.scrollTop ?? 0;
      const viewportBottom = viewportTop + (containerRef.current?.clientHeight ?? 0);
      if (measuredHeight < containerHeight * BOOTSTRAP_HEIGHT_MULTIPLIER && mounted.start > 0) {
        logVirtualScroll('bootstrap-viewport-coverage', {
          anchor: formatAnchorForLog(anchor),
          mounted,
          measuredHeight,
          containerHeight,
          topSpacer: currentTopSpacer,
          mountedBottom: currentMountedBottom,
          viewportTop,
          viewportBottom,
          intersectsViewport: currentMountedBottom > viewportTop && currentTopSpacer < viewportBottom,
          reason: 'insufficient-measured-height',
        });
        queueRangeBatch(Math.max(0, mounted.start - STAGING_BATCH_SIZE), mounted.start - 1, 'backward', 'bootstrap');
        return;
      }

      logVirtualScroll('bootstrap-ready', {
        anchor: formatAnchorForLog(anchor),
        measuredHeight,
        containerHeight,
        mounted,
        topSpacer: currentTopSpacer,
        mountedBottom: currentMountedBottom,
        viewportTop,
        viewportBottom,
        action: 'scrollToBottom',
      });
      layoutIntentRef.current = { scrollToBottom: true };
      updateMountedRange(capRange(mounted, rowKeys.length - 1));
      setPhaseState('READY');
      triggerRender();
      return;
    }

    const anchorIndex = keyToIndex.get(anchor.key) ?? rowKeys.length - 1;
    const heightBelowAnchor = heightBetween(Math.max(anchorIndex + 1, mounted.start), mounted.end + 1);
    if (heightBelowAnchor < containerHeight && mounted.end < rowKeys.length - 1) {
      queueRangeBatch(
        mounted.end + 1,
        Math.min(rowKeys.length - 1, mounted.end + STAGING_BATCH_SIZE),
        'forward',
        'bootstrap',
      );
      return;
    }

    const measuredHeight = heightBetween(mounted.start, mounted.end + 1);
    if (measuredHeight < containerHeight * BOOTSTRAP_HEIGHT_MULTIPLIER && mounted.start > 0) {
      queueRangeBatch(Math.max(0, mounted.start - STAGING_BATCH_SIZE), mounted.start - 1, 'backward', 'bootstrap');
      return;
    }

    logVirtualScroll('bootstrap-ready', {
      anchor: formatAnchorForLog(anchor),
      measuredHeight,
      containerHeight,
      mounted,
      action: 'scrollToKey',
    });
    layoutIntentRef.current = { scrollToKey: { key: anchor.key, behavior: 'auto' } };
    updateMountedRange(capRange(mounted, rowKeys.length - 1));
    setPhaseState('READY');
    triggerRender();
  }, [
    containerHeight,
    heightBetween,
    keyToIndex,
    offsetOf,
    pendingBatch,
    phase,
    queueRangeBatch,
    rowKeys.length,
    setPhaseState,
    triggerRender,
    updateMountedRange,
  ]);

  useEffect(() => {
    if (phase !== 'RECENTERING') return;
    if (pendingBatch || rowKeys.length === 0 || containerHeight <= 0) return;

    const mounted = mountedRef.current;
    const container = containerRef.current;
    const targetIndex = recenterTargetIndexRef.current ?? rowKeys.length - 1;

    if (!mounted) {
      queueRangeBatch(
        Math.max(0, targetIndex - BOOTSTRAP_ITEM_RADIUS),
        Math.min(rowKeys.length - 1, targetIndex + BOOTSTRAP_ITEM_RADIUS),
        'forward',
        'recenter',
      );
      return;
    }

    const desired = container ? deriveDesiredRange(container.scrollTop, container.clientHeight) : null;
    if (!desired) {
      updateMountedRange(capRange(mounted, rowKeys.length - 1));
      setPhaseState('READY');
      triggerRender();
      return;
    }

    if (allMeasured(desired.start, desired.end)) {
      updateMountedRange(capRange(desired, rowKeys.length - 1));

      if (pendingScrollKeyRef.current) {
        layoutIntentRef.current = {
          scrollToKey: { key: pendingScrollKeyRef.current, behavior: pendingScrollBehaviorRef.current },
        };
      } else if (pendingScrollToBottomRef.current) {
        layoutIntentRef.current = { scrollToBottom: true };
      }

      setPhaseState('READY');
      triggerRender();
      return;
    }

    const firstMissing = firstUnmeasuredInRange(desired.start, desired.end);
    if (firstMissing === -1) return;

    const start = Math.max(0, firstMissing - Math.floor(STAGING_BATCH_SIZE / 2));
    const end = Math.min(rowKeys.length - 1, start + STAGING_BATCH_SIZE - 1);
    queueRangeBatch(start, end, firstMissing < targetIndex ? 'backward' : 'forward', 'recenter');
  }, [
    allMeasured,
    containerHeight,
    deriveDesiredRange,
    firstUnmeasuredInRange,
    pendingBatch,
    phase,
    queueRangeBatch,
    rowKeys.length,
    setPhaseState,
    triggerRender,
    updateMountedRange,
  ]);

  useEffect(() => {
    if (phase !== 'READY') return;

    if (pendingScrollToBottomRef.current) {
      ensureBottomMeasured();
      return;
    }

    if (pendingScrollKeyRef.current) {
      const targetIndex = keyToIndex.get(pendingScrollKeyRef.current);
      if (targetIndex == null) {
        pendingScrollKeyRef.current = null;
        return;
      }

      const mounted = mountedRef.current;
      if (mounted && targetIndex >= mounted.start && targetIndex <= mounted.end) {
        layoutIntentRef.current = {
          scrollToKey: { key: pendingScrollKeyRef.current, behavior: pendingScrollBehaviorRef.current },
        };
        triggerRender();
        return;
      }

      enterRecentering(targetIndex);
      return;
    }

    maybeUpdateMountedForScroll();
  }, [
    ensureBottomMeasured,
    enterRecentering,
    keyToIndex,
    maybeUpdateMountedForScroll,
    phase,
    renderTick,
    triggerRender,
  ]);

  useEffect(() => {
    if (!scrollApiRef) return;

    scrollApiRef.current = {
      scrollToBottom: () => {
        pendingScrollKeyRef.current = null;
        pendingScrollToBottomRef.current = true;

        if (phaseRef.current === 'READY') {
          ensureBottomMeasured();
        }
      },
      scrollToItem: (key: string, behavior: ScrollBehavior = 'auto') => {
        const targetIndex = keyToIndex.get(key);
        if (targetIndex == null) return;

        pendingScrollBehaviorRef.current = behavior;
        pendingScrollKeyRef.current = key;
        pendingScrollToBottomRef.current = false;

        const mounted = mountedRef.current;
        if (mounted && targetIndex >= mounted.start && targetIndex <= mounted.end) {
          scrollToKeyInternal(key, behavior);
          pendingScrollKeyRef.current = null;
          return;
        }

        if (phaseRef.current === 'READY') {
          enterRecentering(targetIndex);
        }
      },
    };

    return () => {
      if (scrollApiRef.current) {
        scrollApiRef.current = null;
      }
    };
  }, [ensureBottomMeasured, enterRecentering, keyToIndex, scrollApiRef, scrollToKeyInternal]);

  useEffect(() => {
    return () => {
      if (scrollIdleTimerRef.current) clearTimeout(scrollIdleTimerRef.current);
      if (scrollRafRef.current != null) cancelAnimationFrame(scrollRafRef.current);
      if (bottomSettleRafRef.current != null) cancelAnimationFrame(bottomSettleRafRef.current);
    };
  }, []);

  const adjustPrevKeysRef = useRef<string[]>([]);
  if (rowKeys !== adjustPrevKeysRef.current) {
    if (adjustPrevKeysRef.current.length > 0) {
      const mutation = classifyKeyMutation(adjustPrevKeysRef.current, rowKeys);
      if (mutation === 'prepend') {
        const anchor = captureVisibleAnchor();
        pendingPrependRestoreRef.current = anchor;
        mutationSnapshotRef.current = {
          mutation,
          anchor,
          rowCountDelta: rowKeys.length - adjustPrevKeysRef.current.length,
        };
        logMutationSnapshot('prepend-detected', {
          previousCount: adjustPrevKeysRef.current.length,
          nextCount: rowKeys.length,
        });
        const prependCount = rowKeys.length - adjustPrevKeysRef.current.length;
        pendingPrependCompensationRef.current = heightBetween(0, prependCount);
        const mounted = mountedRef.current;
        if (mounted) {
          const expandedRange = {
            start: Math.max(0, mounted.start),
            end: Math.min(rowKeys.length - 1, mounted.end + prependCount),
          };
          mountedRef.current = {
            start: expandedRange.start,
            end: expandedRange.end,
          };
          logMutationSnapshot('prepend-expanded-mounted-window', {
            prependCount,
            prependCompensation: pendingPrependCompensationRef.current,
            previousMounted: mounted,
            nextMounted: mountedRef.current,
          });
        }
        if (recenterTargetIndexRef.current != null) {
          recenterTargetIndexRef.current += prependCount;
        }
      } else if (mutation === 'append') {
        mutationSnapshotRef.current = {
          mutation,
          anchor: captureVisibleAnchor(),
          rowCountDelta: rowKeys.length - adjustPrevKeysRef.current.length,
        };
        logMutationSnapshot('append-detected', {
          previousCount: adjustPrevKeysRef.current.length,
          nextCount: rowKeys.length,
          logicalAtBottom: isAtBottomRef.current,
        });
      }
    }

    adjustPrevKeysRef.current = rowKeys;
  }

  const mounted = mountedRef.current;

  const mountedRows: ReactNode[] = [];
  if (mounted) {
    for (let index = mounted.start; index <= mounted.end; index += 1) {
      const row = rows[index];
      if (!row) continue;

      mountedRows.push(
        <MeasuredRow key={row.key} rowKey={row.key} onMeasure={handleMountedMeasure} registerRow={registerRow}>
          {renderRow(row)}
        </MeasuredRow>,
      );
    }
  }

  const stagingRows: ReactNode[] = [];
  if (pendingBatch) {
    for (const key of pendingBatch.keys) {
      const index = keyToIndex.get(key);
      if (index == null) continue;
      const row = rows[index];
      if (!row) continue;

      stagingRows.push(
        <MeasuredRow key={`staging-${key}`} rowKey={key} hidden onMeasure={handleStagingMeasure}>
          {renderRow(row)}
        </MeasuredRow>,
      );
    }
  }

  const topSpacer = mounted ? topSpacerHeight() : phase === 'RECENTERING' ? totalHeight() : 0;
  const bottomSpacer = mounted ? bottomSpacerHeight() : 0;
  const showLoadingScrim = phase === 'WAITING_VIEWPORT' || phase === 'BOOTSTRAP' || phase === 'RECENTERING';
  const showTopEdgeHint = loadOlder.hasMore || loadOlder.loading;
  const showBottomEdgeHint = !!loadNewer && (loadNewer.hasMore || loadNewer.loading);
  const topEdgeLabel = loadOlder.loading ? t`Loading…` : t`Earlier messages`;
  const bottomEdgeLabel = loadNewer?.loading ? t`Loading…` : t`Newer messages`;
  const contentPaddingTop = showTopEdgeHint ? EDGE_HINT_HEIGHT : 0;
  const contentPaddingBottom = bottomPadding + (showBottomEdgeHint ? EDGE_HINT_HEIGHT : 0);

  return (
    <div ref={containerRef} className={styles.container} onScroll={handleScroll}>
      <div
        className={styles.flowContent}
        style={{ paddingTop: contentPaddingTop, paddingBottom: contentPaddingBottom }}
      >
        {header && <div ref={headerRef}>{header}</div>}
        {showTopEdgeHint && (
          <div className={`${styles.edgeHintRow} ${styles.edgeHintTop}`} style={{ height: EDGE_HINT_HEIGHT }}>
            {topEdgeLabel}
          </div>
        )}
        {topSpacer > 0 && <div className={styles.spacer} style={{ height: topSpacer }} />}
        {mountedRows}
        {bottomSpacer > 0 && <div className={styles.spacer} style={{ height: bottomSpacer }} />}
        {showBottomEdgeHint && (
          <div className={`${styles.edgeHintRow} ${styles.edgeHintBottom}`} style={{ height: EDGE_HINT_HEIGHT }}>
            {bottomEdgeLabel}
          </div>
        )}
        <div className={styles.stagingArea}>{stagingRows}</div>
      </div>
      {showLoadingScrim && <div className={styles.loadingScrim}>Loading…</div>}
    </div>
  );
}
