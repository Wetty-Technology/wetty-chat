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
    const contentRect = content.getBoundingClientRect();
    const pad = 40;
    const visualViewport = window.visualViewport;
    const vh = visualViewport?.height ?? window.innerHeight;
    const vw = visualViewport?.width ?? window.innerWidth;
    const offsetTop = visualViewport?.offsetTop ?? 0;
    const offsetLeft = visualViewport?.offsetLeft ?? 0;

    // Start at the original bubble position, offset by the bubble clone's
    // position within the content container (reactions may be above it)
    const bubbleEl = content.querySelector('[data-bubble-clone]') as HTMLElement | null;
    const bubbleOffsetTop = bubbleEl ? bubbleEl.offsetTop : 0;

    let top = sourceRect.top - bubbleOffsetTop;

    // Check if there's enough space below for the actions
    const actionListEl = content.querySelector('[data-action-list]') as HTMLElement | null;
    const reactionBarEl = content.querySelector('[data-reaction-bar]') as HTMLElement | null;
    if (actionListEl) {
      const spaceBelow = offsetTop + vh - sourceRect.bottom;
      // If space below is less than actionList height + padding, try to move actionList above
      if (spaceBelow < actionListEl.offsetHeight + pad) {
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
    let left = isSent ? sourceRect.right - contentRect.width : sourceRect.left;

    // Clamp vertically: ensure the entire content (reactions + bubble + actions) fits
    if (top + contentRect.height > offsetTop + vh - pad) {
      top = offsetTop + vh - pad - contentRect.height;
    }
    if (top < offsetTop + pad) {
      top = offsetTop + pad;
    }

    // Clamp horizontally
    if (left + contentRect.width > offsetLeft + vw - pad) {
      left = offsetLeft + vw - pad - contentRect.width;
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
