import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { IonIcon } from '@ionic/react';
import { checkmarkCircle, checkmarkCircleOutline, documentOutline } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import { useSelector } from 'react-redux';
import { renderMessageWithLinks } from './ChatBubble';
import { getMessagePreviewText } from './messagePreview';
import { selectChatFontSizeStyle } from '@/store/settingsSlice';
import type { Attachment } from '@/api/messages';
import styles from './MessageOverlay.module.scss';

export interface MessageOverlayAction {
  key: string;
  label: string;
  icon?: string;
  role?: 'destructive';
  disabled?: boolean;
  handler: () => void;
}

interface MessageOverlayProps {
  senderName: string;
  message: string;
  isSent: boolean;
  showName?: boolean;
  replyTo?: {
    senderName: string;
    message?: string | null;
    attachments?: Attachment[];
    isDeleted?: boolean;
  };
  timestamp?: string;
  edited?: boolean;
  isConfirmed?: boolean;
  attachments?: Attachment[];
  sourceRect: DOMRect;
  actions: MessageOverlayAction[];
  reactions?: {
    emojis: string[];
    onReact: (emoji: string) => void;
  };
  onClose: () => void;
}

function formatTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false });
}

export function MessageOverlay({
  senderName,
  message,
  isSent,
  showName = true,
  replyTo,
  timestamp,
  edited,
  isConfirmed,
  attachments,
  sourceRect,
  actions,
  reactions,
  onClose,
}: MessageOverlayProps) {
  const contentRef = useRef<HTMLDivElement>(null);
  const [position, setPosition] = useState<{ top: number; left: number } | null>(null);
  const chatFontSizeStyle = useSelector(selectChatFontSizeStyle);

  // Compute position after first render so we know the full content dimensions
  useEffect(() => {
    if (!contentRef.current) return;
    const content = contentRef.current;
    const contentRect = content.getBoundingClientRect();
    const pad = 40;
    const vh = window.innerHeight;
    const vw = window.innerWidth;

    // Start at the original bubble position, offset by the bubble clone's
    // position within the content container (reactions may be above it)
    const bubbleEl = content.querySelector('[data-bubble-clone]') as HTMLElement | null;
    const bubbleOffsetTop = bubbleEl ? bubbleEl.offsetTop : 0;

    let top = sourceRect.top - bubbleOffsetTop;

    // For sent messages, align right edge to source right edge
    let left = isSent
      ? sourceRect.right - contentRect.width
      : sourceRect.left;

    // Clamp vertically: ensure the entire content (reactions + bubble + actions) fits
    if (top + contentRect.height > vh - pad) {
      top = vh - pad - contentRect.height;
    }
    if (top < pad) {
      top = pad;
    }

    // Clamp horizontally
    if (left + contentRect.width > vw - pad) {
      left = vw - pad - contentRect.width;
    }
    if (left < pad) {
      left = pad;
    }

    setPosition({ top, left });
  }, [sourceRect]);

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

  const bubbleClass = `${styles.bubbleClone} ${isSent ? styles.bubbleSent : styles.bubbleReceived}`;

  const overlay = (
    <div className={styles.overlay} onClick={handleBackdropClick}>
      <div
        ref={contentRef}
        className={`${styles.content} ${isSent ? styles.contentSent : ''} ${position ? styles.contentVisible : ''}`}
        style={
          position
            ? { top: position.top, left: position.left }
            : { top: sourceRect.top, left: sourceRect.left, visibility: 'hidden' }
        }
      >
        {/* Reaction bar */}
        {reactions && (
          <div className={styles.reactionBar}>
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
        <div data-bubble-clone className={bubbleClass} style={{ fontSize: chatFontSizeStyle, width: sourceRect.width }}>
          {showName && <div className={styles.senderName}>{senderName}</div>}
          {replyTo && (
            <div className={styles.replyPreview}>
              <div className={styles.replyPreviewName}>{replyTo.senderName}</div>
              <div className={styles.replyPreviewText}>
                {getMessagePreviewText({
                  message: replyTo.message,
                  attachments: replyTo.attachments,
                  isDeleted: replyTo.isDeleted,
                })}
              </div>
            </div>
          )}
          {attachments && attachments.length > 0 && (
            <div className={styles.attachmentsContainer}>
              {attachments.map((att) => {
                if (!att.kind.startsWith('image/')) {
                  return (
                    <div key={att.id} className={styles.filePlaceholder}>
                      <IonIcon icon={documentOutline} className={styles.fileIcon} />
                      <span className={styles.fileName}>{att.file_name}</span>
                    </div>
                  );
                }
                return (
                  <img
                    key={att.id}
                    src={att.url}
                    alt={t`Attachment`}
                    className={styles.attachmentImage}
                  />
                );
              })}
            </div>
          )}
          <div className={styles.messageWrapper}>
            <span className={styles.messageText}>{renderMessageWithLinks(message)}</span>
            <span className={styles.timestampSpacer} />
            {timestamp && (
              <span className={styles.timestamp}>
                {formatTime(timestamp)}{edited && ` (${t`Edited`})`}
                {isSent && (
                  <IonIcon
                    icon={isConfirmed ? checkmarkCircle : checkmarkCircleOutline}
                    className={styles.statusIcon}
                  />
                )}
              </span>
            )}
          </div>
        </div>

        {/* Action list */}
        <div className={styles.actionList}>
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
