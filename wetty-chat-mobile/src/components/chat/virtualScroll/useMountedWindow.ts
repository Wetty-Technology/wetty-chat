import { useCallback, useRef } from 'react';
import type { HeightCache } from './heightCache';
import type { CoreRange, MountedWindow } from './types';
import { MOUNT_CAP, MOUNT_OVERSCAN } from './types';

export interface MountedWindowResult {
  mountedRef: React.MutableRefObject<MountedWindow | null>;
  recomputeMounted: (core: CoreRange, scrollTop: number, viewportHeight: number, topChromeHeight: number) => void;
  resetMounted: (core: CoreRange) => void;
  topSpacerHeight: (core: CoreRange) => number;
  bottomSpacerHeight: (core: CoreRange) => number;
}

export function useMountedWindow(rowKeys: string[], heightCache: HeightCache): MountedWindowResult {
  const mountedRef = useRef<MountedWindow | null>(null);

  const findUnmeasuredSpan = useCallback(
    (core: CoreRange): MountedWindow | null => {
      let firstMissing = -1;
      let lastMissing = -1;

      for (let i = core.start; i <= core.end; i++) {
        if (heightCache.has(rowKeys[i])) continue;
        if (firstMissing === -1) {
          firstMissing = i;
        }
        lastMissing = i;
      }

      return firstMissing === -1 ? null : { start: firstMissing, end: lastMissing };
    },
    [heightCache, rowKeys],
  );

  const recomputeMounted = useCallback(
    (core: CoreRange, scrollTop: number, viewportHeight: number, topChromeHeight: number) => {
      const mounted = mountedRef.current;
      const coreScrollOffset = Math.max(0, scrollTop - topChromeHeight);

      let cumHeight = 0;
      let visibleStart = core.start;
      let visibleEnd = core.start;

      for (let i = core.start; i <= core.end; i++) {
        const height = heightCache.get(rowKeys[i]) ?? 0;
        if (cumHeight + height > coreScrollOffset) {
          visibleStart = i;
          break;
        }
        cumHeight += height;
        visibleStart = i;
      }

      let afterStart = 0;
      for (let i = core.start; i <= core.end; i++) {
        const height = heightCache.get(rowKeys[i]) ?? 0;
        afterStart += height;
        if (afterStart >= coreScrollOffset) {
          let visibleHeight = afterStart - coreScrollOffset;
          visibleEnd = i;
          for (let j = i + 1; j <= core.end; j++) {
            if (visibleHeight >= viewportHeight) break;
            visibleHeight += heightCache.get(rowKeys[j]) ?? 0;
            visibleEnd = j;
          }
          break;
        }
      }

      const newStart = Math.max(core.start, visibleStart - MOUNT_OVERSCAN);
      const newEnd = Math.min(core.end, visibleEnd + MOUNT_OVERSCAN);
      const unmeasuredSpan = findUnmeasuredSpan(core);

      // Unmeasured core rows must stay mounted until they have exact heights.
      // Otherwise they fall back to zero-height spacers and the scroll geometry oscillates.
      const requiredStart = unmeasuredSpan ? Math.min(newStart, unmeasuredSpan.start) : newStart;
      const requiredEnd = unmeasuredSpan ? Math.max(newEnd, unmeasuredSpan.end) : newEnd;

      if (!unmeasuredSpan && requiredEnd - requiredStart + 1 > MOUNT_CAP) {
        const center = Math.floor((visibleStart + visibleEnd) / 2);
        const halfCap = Math.floor(MOUNT_CAP / 2);
        const cappedStart = Math.max(core.start, center - halfCap);
        const cappedEnd = Math.min(core.end, cappedStart + MOUNT_CAP - 1);
        mountedRef.current = { start: cappedStart, end: cappedEnd };
        return;
      }

      if (mounted) {
        const expandedStart = Math.min(mounted.start, requiredStart);
        const expandedEnd = Math.max(mounted.end, requiredEnd);
        if (unmeasuredSpan || expandedEnd - expandedStart + 1 <= MOUNT_CAP) {
          mountedRef.current = {
            start: Math.max(core.start, expandedStart),
            end: Math.min(core.end, expandedEnd),
          };
          return;
        }
      }

      mountedRef.current = { start: requiredStart, end: requiredEnd };
    },
    [findUnmeasuredSpan, heightCache, rowKeys],
  );

  const resetMounted = useCallback((core: CoreRange) => {
    const size = core.end - core.start + 1;
    if (size <= MOUNT_CAP) {
      mountedRef.current = { start: core.start, end: core.end };
      return;
    }

    mountedRef.current = { start: core.end - MOUNT_CAP + 1, end: core.end };
  }, []);

  const topSpacerHeight = useCallback(
    (core: CoreRange): number => {
      const mounted = mountedRef.current;
      if (!mounted) return 0;

      let total = 0;
      for (let i = core.start; i < mounted.start; i++) {
        total += heightCache.get(rowKeys[i]) ?? 0;
      }
      return total;
    },
    [heightCache, rowKeys],
  );

  const bottomSpacerHeight = useCallback(
    (core: CoreRange): number => {
      const mounted = mountedRef.current;
      if (!mounted) return 0;

      let total = 0;
      for (let i = mounted.end + 1; i <= core.end; i++) {
        total += heightCache.get(rowKeys[i]) ?? 0;
      }
      return total;
    },
    [heightCache, rowKeys],
  );

  return { mountedRef, recomputeMounted, resetMounted, topSpacerHeight, bottomSpacerHeight };
}
