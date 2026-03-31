import { useEffect, useLayoutEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { IonIcon } from '@ionic/react';
import type { Attachment } from '@/api/messages';
import type { PreviewMessage } from '@/utils/messagePreview';
import { ChatBubbleBase } from './messages/ChatBubbleBase';
import { StickerBubble } from './messages/StickerBubble';
import styles from './MessageOverlay.module.scss';

export interface MessageOverlayAction {
  key: string;
  label: string;
  icon?: string;
  role?: 'destructive';
  disabled?: boolean;
  handler: () => void;
}

interface MessageOverlayBaseProps {
  senderName: string;
  isSent: boolean;
  showName?: boolean;
  replyTo?: {
    senderName: string;
    preview: PreviewMessage;
  };
  timestamp?: string;
  edited?: boolean;
  isConfirmed?: boolean;
  sourceRect: DOMRect;
  actions: MessageOverlayAction[];
  reactions?: {
    emojis: string[];
    onReact: (emoji: string) => void;
  };
  onClose: () => void;
}

interface StickerOverlayProps extends MessageOverlayBaseProps {
  messageType: 'sticker';
  stickerUrl: string;
  message?: never;
  attachments?: never;
}

interface RegularOverlayProps extends MessageOverlayBaseProps {
  messageType?: 'text' | 'audio';
  message: string;
  attachments?: Attachment[];
  stickerUrl?: never;
}

export type MessageOverlayProps = StickerOverlayProps | RegularOverlayProps;

export function MessageOverlay(props: MessageOverlayProps) {
  const {
    senderName,
    isSent,
    showName = true,
    replyTo,
    timestamp,
    edited,
    isConfirmed,
    sourceRect,
    actions,
    reactions,
    onClose,
  } = props;
  const isSticker = props.messageType === 'sticker';
  const contentRef = useRef<HTMLDivElement>(null);

  // Compute position after first render so we know the full content dimensions
  useLayoutEffect(() => {
    const content = contentRef.current;
    if (!content) return;
    const pad = 40;
    const visualViewport = window.visualViewport;
    const vh = visualViewport?.height ?? window.innerHeight;
    const vw = visualViewport?.width ?? window.innerWidth;
    const offsetTop = visualViewport?.offsetTop ?? 0;
    const offsetLeft = visualViewport?.offsetLeft ?? 0;

    let contentWidth = content.offsetWidth;
    let contentHeight = content.offsetHeight;

    // Start at the original bubble position, offset by the bubble clone's
    // position within the content container (reactions may be above it)
    const bubbleEl = content.querySelector('[data-bubble-clone]') as HTMLElement | null;
    const bubbleOffsetTop = bubbleEl ? bubbleEl.offsetTop : 0;

    let top = sourceRect.top - bubbleOffsetTop;

    // Check if there's enough space below for the actions
    const actionListEl = content.querySelector('[data-action-list]') as HTMLElement | null;
    const reactionBarEl = content.querySelector('[data-reaction-bar]') as HTMLElement | null;
    
    // Check if entire content will fit, otherwise we clip just the inner text mechanism
    const maxAllowedHeight = vh - 2 * pad;
    if (contentHeight > maxAllowedHeight && bubbleEl) {
      const nonBubbleHeight = contentHeight - bubbleEl.offsetHeight;
      const maxBubbleHeight = maxAllowedHeight - nonBubbleHeight;
      if (maxBubbleHeight > 0) {
        // Find if we already added a fade block, remove it to recalculate
        const existingFade = bubbleEl.querySelector('.text-fade-overlay');
        if (existingFade) existingFade.remove();

        bubbleEl.style.position = 'relative';
        bubbleEl.style.maxHeight = `${maxBubbleHeight}px`;
        bubbleEl.style.overflow = 'hidden';
        
        // Fading out the text by overlaying a gradient that matches the bubble's background color.
        const bgColor = window.getComputedStyle(bubbleEl).backgroundColor;
        const fadeNode = document.createElement('div');
        fadeNode.className = 'text-fade-overlay';
        fadeNode.style.position = 'absolute';
        fadeNode.style.bottom = '0';
        fadeNode.style.left = '0';
        fadeNode.style.right = '0';
        fadeNode.style.height = '48px';
        fadeNode.style.pointerEvents = 'none';
        // We make the bottom fully opaque matching the background color, so the timestamp rests on a solid colored block,
        // and only the top part of the 48px area represents the fade gradient overlaying the cut-off text.
        fadeNode.style.background = `linear-gradient(to bottom, transparent 0%, ${bgColor} 80%, ${bgColor} 100%)`;
        
        bubbleEl.appendChild(fadeNode);

        // Note: The timestamp component naturally sinks into the bottom right corner due to flex-wrap and Spacer.
        // What we need to do is clear its original rendering slot inside the flex-box, and physically lift it
        // into an absolute layer resting securely ABOVE the background-color gradient block we just added,
        // while also injecting a background plate to cover any clipped text artifacts behind it.
        const timeEls = Array.from(bubbleEl.querySelectorAll('span[class*="timestamp"]'));
        const timestampEl = timeEls.find(el => !el.className.includes('Spacer')) as HTMLElement | null;
        if (timestampEl) {
          timestampEl.style.position = 'absolute';
          timestampEl.style.bottom = '8px';
          timestampEl.style.right = '12px';
          timestampEl.style.zIndex = '10';
          // Ensure it has a stark background so that half-transparent text doesn't bleed through
          timestampEl.style.background = bgColor;
          // Adding small padding to make the solid background look like a natural text plate
          timestampEl.style.padding = '2px 4px';
          timestampEl.style.borderRadius = '8px';
          
          // Since it's absolutely positioned, we also need to enforce its display block to bypass any wrapper cuts
          timestampEl.style.display = 'inline-flex';
        }
        
        // Refresh dimensions
        contentHeight = content.offsetHeight;
      }
    }

    if (actionListEl) {
      const spaceBelow = offsetTop + vh - sourceRect.bottom;
      // Required space: action list height + flex gap (8px) + visual margin (pad)
      const requiredSpace = actionListEl.offsetHeight + 8 + pad;
      
      // If space below is less than the required space, swap the layout
      if (spaceBelow < requiredSpace) {
        // We move the action list to the top and reaction bar to the bottom
        actionListEl.style.order = '-1';
        if (reactionBarEl) {
          reactionBarEl.style.order = '1';
        }
        // Re-read bubbleOffsetTop since the layout just changed!
        const newBubbleOffsetTop = bubbleEl ? bubbleEl.offsetTop : 0;
        top = sourceRect.top - newBubbleOffsetTop;
      }
    }

    // For sent messages, align right edge to source right edge
    let left = isSent ? sourceRect.right - contentWidth : sourceRect.left;

    // Clamp vertically: ensure the entire content (reactions + bubble + actions) fits
    if (top + contentHeight > offsetTop + vh - pad) {
      top = offsetTop + vh - pad - contentHeight;
    }
    if (top < offsetTop + pad) {
      top = offsetTop + pad;
    }

    // Clamp horizontally
    if (left + contentWidth > offsetLeft + vw - pad) {
      left = offsetLeft + vw - pad - contentWidth;
    }
    if (left < offsetLeft + pad) {
      left = offsetLeft + pad;
    }

    content.style.top = `${top}px`;
    content.style.left = `${left}px`;
    content.style.visibility = 'visible';
  }, [isSent, sourceRect]);

  // Body scroll lock
  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prev;
    };
  }, []);

  // Escape key dismissal
  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        onClose();
      }
    }
    document.addEventListener('keydown', onKeyDown);
    return () => document.removeEventListener('keydown', onKeyDown);
  }, [onClose]);

  function handleBackdropClick(e: React.MouseEvent) {
    if (e.target === e.currentTarget) {
      onClose();
    }
  }

  const bubbleCloneProps = {
    'data-bubble-clone': 'true' as const,
    className: isSticker ? undefined : styles.bubbleClone,
    style: { width: sourceRect.width },
  };

  let bubbleClone;
  if (props.messageType === 'sticker') {
    bubbleClone = (
      <StickerBubble
        stickerUrl={props.stickerUrl}
        senderName={senderName}
        isSent={isSent}
        showAvatar={false}
        replyTo={replyTo}
        timestamp={timestamp}
        edited={edited}
        isConfirmed={isConfirmed}
        layout="bubble-only"
        interactionMode="read-only"
        bubbleProps={bubbleCloneProps}
      />
    );
  } else {
    bubbleClone = (
      <ChatBubbleBase
        messageType={props.messageType}
        senderName={senderName}
        message={props.message}
        isSent={isSent}
        showName={showName}
        showAvatar={false}
        replyTo={replyTo}
        timestamp={timestamp}
        edited={edited}
        isConfirmed={isConfirmed}
        attachments={props.attachments}
        layout="bubble-only"
        interactionMode="read-only"
        bubbleProps={bubbleCloneProps}
      />
    );
  }

  const overlay = (
    <div className={styles.overlay} onClick={handleBackdropClick}>
      <div
        ref={contentRef}
        className={`${styles.content} ${isSent ? styles.contentSent : ''} ${styles.contentVisible}`}
        style={{ top: sourceRect.top, left: sourceRect.left, visibility: 'hidden' }}
      >
        {/* Reaction bar — hidden for stickers */}
        {!isSticker && reactions && (
          <div className={styles.reactionBar} data-reaction-bar="true">
            {reactions.emojis.map((emoji) => (
              <button
                key={emoji}
                type="button"
                className={styles.reactionBtn}
                onClick={() => {
                  reactions.onReact(emoji);
                  onClose();
                }}
              >
                {emoji}
              </button>
            ))}
          </div>
        )}

        {/* Bubble clone */}
        {bubbleClone}

        {/* Action list */}
        <div className={styles.actionList} data-action-list="true">
          {actions.map((action) => (
            <button
              key={action.key}
              type="button"
              disabled={action.disabled}
              className={`${styles.actionItem} ${action.role === 'destructive' ? styles.actionDestructive : ''} ${action.disabled ? styles.actionDisabled : ''}`}
              onClick={() => {
                if (action.disabled) return;
                action.handler();
                onClose();
              }}
            >
              {action.icon && <IonIcon icon={action.icon} />}
              {action.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );

  return createPortal(overlay, document.body);
}
