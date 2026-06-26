import { createContext } from 'react';

/**
 * Reports the live swipe transform of the group's LAST message bubble up to the
 * SenderGroup, so the floating sticky avatar can slide horizontally together
 * with that bubble — but only when the group is at rest (avatar aligned with the
 * last message). SenderGroup applies the transform; non-last messages and groups
 * whose avatar is still stuck mid-scroll keep the avatar static.
 *
 * `transformPx` is the already-signed translateX (offset * swipeSign), so the
 * avatar mirrors the bubble exactly. `animating` mirrors the `.snapBack` flag so
 * the snap-back transition stays in sync.
 */
export interface SenderSwipeContextValue {
  reportSwipe: (transformPx: number, animating: boolean) => void;
}

export const SenderSwipeContext = createContext<SenderSwipeContextValue | null>(null);
