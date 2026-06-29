import { createContext } from 'react';

/**
 * Lets a ChatBubble report its live swipe transform up to the enclosing
 * SenderGroup, which applies the effect directly to the DOM (no React state)
 * so swiping stays 60fps regardless of group size. Two effects, gated by
 * `isLastInGroup`: any bubble raises the message column z-index so it paints
 * over the sticky avatar; the last bubble also slides the avatar horizontally.
 *
 * When the context is null (search / read-only / showAllAvatars inline mode)
 * ChatBubble's reporting is a no-op. See SenderGroup.reportSwipe for details.
 */
export interface SenderSwipeContextValue {
  reportSwipe: (transformPx: number, animating: boolean, isLastInGroup: boolean) => void;
}

export const SenderSwipeContext = createContext<SenderSwipeContextValue | null>(null);
