import { useCallback, useRef } from 'react';
import type { HeightCache } from './heightCache';
import type { BatchDirection, CoreRange, PendingBatch } from './types';
import { CORE_CAP, STAGING_BATCH_SIZE } from './types';

export interface CoreManagerResult {
  coreRef: React.MutableRefObject<CoreRange | null>;
  expandCore: (batch: PendingBatch, heights: Map<string, number>) => number;
  expandCoreFromCache: (direction: BatchDirection, count: number) => number;
  resetCore: (range: CoreRange) => void;
  pruneCore: (viewportCenter: number) => number;
  canExpandFromCache: (direction: BatchDirection) => boolean;
  createBatch: (direction: BatchDirection) => PendingBatch | null;
  createBootstrapBatch: (anchorIndex: number) => PendingBatch | null;
  coreHeight: () => number;
  coreHeightBefore: (index: number) => number;
  coreHeightAfter: (index: number) => number;
}

export function useCoreManager(rowKeys: string[], heightCache: HeightCache): CoreManagerResult {
  const coreRef = useRef<CoreRange | null>(null);

  const expandCore = useCallback(
    (batch: PendingBatch, heights: Map<string, number>): number => {
      for (const [key, height] of heights) {
        heightCache.set(key, height);
      }

      const core = coreRef.current;
      const batchIndices: number[] = [];
      for (const key of batch.keys) {
        const idx = rowKeys.indexOf(key);
        if (idx !== -1) batchIndices.push(idx);
      }
      if (batchIndices.length === 0) return 0;

      const batchStart = Math.min(...batchIndices);
      const batchEnd = Math.max(...batchIndices);

      if (!core) {
        coreRef.current = { start: batchStart, end: batchEnd };
        return 0;
      }

      let heightDelta = 0;
      if (batch.direction === 'backward' && batchStart < core.start) {
        for (let i = batchStart; i < core.start; i++) {
          heightDelta += heightCache.get(rowKeys[i]) ?? 0;
        }
        core.start = batchStart;
      }
      if (batchEnd > core.end) {
        core.end = batchEnd;
      }

      return heightDelta;
    },
    [heightCache, rowKeys],
  );

  const expandCoreFromCache = useCallback(
    (direction: BatchDirection, count: number): number => {
      const core = coreRef.current;
      if (!core) return 0;

      let heightDelta = 0;

      if (direction === 'backward') {
        const newStart = Math.max(0, core.start - count);
        for (let i = newStart; i < core.start; i++) {
          heightDelta += heightCache.get(rowKeys[i]) ?? 0;
        }
        core.start = newStart;
      } else {
        core.end = Math.min(rowKeys.length - 1, core.end + count);
      }

      return heightDelta;
    },
    [heightCache, rowKeys],
  );

  const resetCore = useCallback((range: CoreRange) => {
    coreRef.current = { ...range };
  }, []);

  const pruneCore = useCallback(
    (viewportCenterIndex: number): number => {
      const core = coreRef.current;
      if (!core) return 0;

      const coreSize = core.end - core.start + 1;
      if (coreSize <= CORE_CAP) return 0;

      const excess = coreSize - CORE_CAP;
      const distToStart = viewportCenterIndex - core.start;
      const distToEnd = core.end - viewportCenterIndex;

      let heightDelta = 0;

      if (distToStart > distToEnd) {
        const pruneEnd = core.start + excess;
        for (let i = core.start; i < pruneEnd; i++) {
          heightDelta += heightCache.get(rowKeys[i]) ?? 0;
        }
        core.start = pruneEnd;
        return -heightDelta;
      }

      core.end -= excess;
      return 0;
    },
    [heightCache, rowKeys],
  );

  const canExpandFromCache = useCallback(
    (direction: BatchDirection): boolean => {
      const core = coreRef.current;
      if (!core) return false;

      if (direction === 'backward') {
        if (core.start <= 0) return false;
        const checkStart = Math.max(0, core.start - STAGING_BATCH_SIZE);
        for (let i = checkStart; i < core.start; i++) {
          if (!heightCache.has(rowKeys[i])) return false;
        }
        return true;
      }

      if (core.end >= rowKeys.length - 1) return false;
      const checkEnd = Math.min(rowKeys.length - 1, core.end + STAGING_BATCH_SIZE);
      for (let i = core.end + 1; i <= checkEnd; i++) {
        if (!heightCache.has(rowKeys[i])) return false;
      }
      return true;
    },
    [heightCache, rowKeys],
  );

  const createBatch = useCallback(
    (direction: BatchDirection): PendingBatch | null => {
      const core = coreRef.current;
      if (!core || rowKeys.length === 0) return null;

      if (direction === 'backward') {
        if (core.start <= 0) return null;
        const start = Math.max(0, core.start - STAGING_BATCH_SIZE);
        const batchKeys = rowKeys.slice(start, core.start);
        return batchKeys.length > 0 ? { direction, keys: batchKeys } : null;
      }

      if (core.end >= rowKeys.length - 1) return null;
      const end = Math.min(rowKeys.length - 1, core.end + STAGING_BATCH_SIZE);
      const batchKeys = rowKeys.slice(core.end + 1, end + 1);
      return batchKeys.length > 0 ? { direction, keys: batchKeys } : null;
    },
    [rowKeys],
  );

  const createBootstrapBatch = useCallback(
    (anchorIndex: number): PendingBatch | null => {
      if (rowKeys.length === 0) return null;

      const clampedAnchor = Math.min(Math.max(0, anchorIndex), rowKeys.length - 1);
      const halfBatch = Math.floor(STAGING_BATCH_SIZE / 2);
      const start = Math.max(0, clampedAnchor - halfBatch);
      const end = Math.min(rowKeys.length - 1, clampedAnchor + halfBatch);
      const batchKeys = rowKeys.slice(start, end + 1);
      return batchKeys.length > 0 ? { direction: 'backward', keys: batchKeys } : null;
    },
    [rowKeys],
  );

  const coreHeight = useCallback((): number => {
    const core = coreRef.current;
    if (!core) return 0;

    let total = 0;
    for (let i = core.start; i <= core.end; i++) {
      total += heightCache.get(rowKeys[i]) ?? 0;
    }
    return total;
  }, [heightCache, rowKeys]);

  const coreHeightBefore = useCallback(
    (index: number): number => {
      const core = coreRef.current;
      if (!core) return 0;

      let total = 0;
      for (let i = core.start; i < index; i++) {
        total += heightCache.get(rowKeys[i]) ?? 0;
      }
      return total;
    },
    [heightCache, rowKeys],
  );

  const coreHeightAfter = useCallback(
    (index: number): number => {
      const core = coreRef.current;
      if (!core) return 0;

      let total = 0;
      for (let i = index + 1; i <= core.end; i++) {
        total += heightCache.get(rowKeys[i]) ?? 0;
      }
      return total;
    },
    [heightCache, rowKeys],
  );

  return {
    coreRef,
    expandCore,
    expandCoreFromCache,
    resetCore,
    pruneCore,
    canExpandFromCache,
    createBatch,
    createBootstrapBatch,
    coreHeight,
    coreHeightBefore,
    coreHeightAfter,
  };
}
