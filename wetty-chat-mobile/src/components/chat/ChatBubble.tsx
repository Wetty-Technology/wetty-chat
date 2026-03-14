import { useRef, useState } from 'react';
import { IonIcon } from '@ionic/react';
import { arrowUndo, chatbubbles, checkmarkCircle, checkmarkCircleOutline } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import styles from './ChatBubble.module.scss';
import type { Attachment } from '@/api/messages';
import { ImageViewer } from './ImageViewer';

interface ChatBubbleProps {
  senderName: string;
  message: string;
  isSent: boolean;
  avatarUrl?: string;
  showName?: boolean;
  showAvatar?: boolean;
  swipeDirection?: 'left' | 'right';
  onReply?: () => void;
  onReplyTap?: () => void;
  onLongPress?: () => void;
  onAvatarClick?: () => void;
  replyTo?: {
    senderName: string;
    message: string;
  };
  timestamp?: string;
  edited?: boolean;
  isConfirmed?: boolean;
  threadInfo?: { reply_count: number };
  onThreadClick?: () => void;
  attachments?: Attachment[];
  maxImageHeight?: number;
}

function formatTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false });
}

function getInitials(name: string): string {
  return name.slice(0, 2).toUpperCase();
}

function colorForUser(name: string): string {
  let hash = 0;
  for (const char of name) {
    hash = (hash << 5) - hash + char.charCodeAt(0);
    hash |= 0; // Cap to 32bit
  }
  const hue = ((hash * 137) % 360 + 360) % 360;
  return `hsl(${hue}, 55%, 50%)`;
}

const SWIPE_THRESHOLD = 60;
const SWIPE_MAX = 80;

export function ChatBubble({
  senderName,
  message,
  isSent,
  avatarUrl,
  showName = true,
  showAvatar = true,
  swipeDirection = 'left',
  onReply,
  onReplyTap,
  onLongPress,
  onAvatarClick,
  replyTo,
  timestamp,
  edited,
  isConfirmed,
  threadInfo,
  onThreadClick,
  attachments,
  maxImageHeight = 300,
}: ChatBubbleProps) {
  const swipeSign = swipeDirection === 'left' ? -1 : 1;
  const [offset, setOffset] = useState(0);
  const [animating, setAnimating] = useState(false);
  const [viewingAttachment, setViewingAttachment] = useState<Attachment | null>(null);
  const startX = useRef(0);
  const startY = useRef(0);
  const swiping = useRef(false);
  const directionLocked = useRef<'horizontal' | 'vertical' | null>(null);
  const longPressTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  function clearLongPress() {
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current);
      longPressTimer.current = null;
    }
  }

  function onTouchStart(e: React.TouchEvent) {
    const touch = e.touches[0];
    startX.current = touch.clientX;
    startY.current = touch.clientY;
    swiping.current = false;
    directionLocked.current = null;
    setAnimating(false);

    if (onLongPress && /iPad|iPhone|iPod/.test(navigator.userAgent)) {
      longPressTimer.current = setTimeout(() => {
        onLongPress();
      }, 500);
    }
  }

  function onTouchMove(e: React.TouchEvent) {
    const touch = e.touches[0];
    const dx = touch.clientX - startX.current;
    const dy = touch.clientY - startY.current;

    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
      clearLongPress();
    }

    if (!onReply) return;

    if (!directionLocked.current) {
      if (Math.abs(dx) > 5 || Math.abs(dy) > 5) {
        directionLocked.current = Math.abs(dx) > Math.abs(dy) ? 'horizontal' : 'vertical';
      }
    }

    if (directionLocked.current !== 'horizontal') return;

    const clamped = Math.min(Math.max(dx * swipeSign, 0), SWIPE_MAX);
    if (clamped > 0) {
      swiping.current = true;
      setOffset(clamped);
    }
  }

  function onTouchEnd() {
    clearLongPress();
    if (!onReply || !swiping.current) return;
    if (offset >= SWIPE_THRESHOLD) {
      onReply();
    }
    setAnimating(true);
    setOffset(0);
  }

  function handleContextMenu(e: React.MouseEvent) {
    if (onLongPress) {
      e.preventDefault();
      onLongPress();
    }
  }

  const progress = Math.min(offset / SWIPE_THRESHOLD, 1);

  return (
    <div className={styles.swipeContainer}>
      <div
        className={styles.replyIcon}
        style={{ opacity: progress, transform: `scale(${0.5 + progress * 0.5})`, [swipeDirection === 'left' ? 'right' : 'left']: 16 }}
      >
        <IonIcon icon={arrowUndo} />
      </div>
      <div
        className={`${styles.swipeContent} ${animating ? styles.snapBack : ''}`}
        style={{ transform: `translateX(${offset * swipeSign}px)` }}
        onTouchStart={onTouchStart}
        onTouchMove={onTouchMove}
        onTouchEnd={onTouchEnd}
        onContextMenu={handleContextMenu}
        onTransitionEnd={() => setAnimating(false)}
      >
        <div className={`${styles.chatRow} ${isSent ? styles.sent : styles.received}`}>
          {showAvatar ? (
            avatarUrl ? (
              <div className={styles.avatar}>
                <img src={avatarUrl} />
              </div>
            ) : (
              <div
                className={styles.avatar}
                style={{ backgroundColor: colorForUser(senderName), cursor: onAvatarClick ? 'pointer' : undefined }}
                onClick={onAvatarClick}
              >
                {getInitials(senderName)}
              </div>
            )
          ) : (
            <div className={styles.avatarSpacer} />
          )}
          <div className={styles.bubble}>
            {showName && <div className={styles.senderName}>{senderName}</div>}
            {replyTo && (
              <div
                className={`${styles.replyPreview} ${onReplyTap ? styles.replyPreviewTappable : ''}`}
                onClick={onReplyTap}
              >
                <div className={styles.replyPreviewName}>{replyTo.senderName}</div>
                <div className={styles.replyPreviewText}>{replyTo.message}</div>
              </div>
            )}
            {attachments && attachments.length > 0 && (
              <div className={styles.attachmentsContainer}>
                {attachments.map((att) => {
                  const hasSize = att.width && att.height;

                  const imageStyle: React.CSSProperties = {
                    backgroundColor: 'rgba(128, 128, 128, 0.2)',
                    cursor: 'pointer',
                    display: 'block',
                  };

                  if (hasSize) {
                    imageStyle.width = att.width!;
                    imageStyle.height = att.height!;
                    imageStyle.maxHeight = maxImageHeight;
                    imageStyle.maxWidth = '100%';
                    imageStyle.aspectRatio = `${att.width} / ${att.height}`;
                  } else {
                    imageStyle.height = maxImageHeight;
                    imageStyle.width = 'auto';
                    imageStyle.maxWidth = '100%';
                    imageStyle.objectFit = 'contain';
                  }

                  return (
                    <img
                      key={att.id}
                      src={att.url}
                      alt="attachment"
                      className={styles.attachmentImage}
                      style={imageStyle}
                      onClick={() => setViewingAttachment(att)}
                    />
                  );
                })}
              </div>
            )}
            <div className={styles.messageWrapper}>
              <span className={styles.messageText}>{message}</span>
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
            {threadInfo && (
              <div className={styles.threadIndicator} onClick={onThreadClick}>
                <IonIcon icon={chatbubbles} />
                <span>{threadInfo.reply_count} {threadInfo.reply_count === 1 ? t`reply` : t`replies`}</span>
              </div>
            )}
          </div>
          {onReply && (
            <button className={styles.hoverReplyBtn} onClick={onReply} aria-label={t`Reply`}>
              <IonIcon icon={arrowUndo} />
            </button>
          )}
        </div>
      </div>
      {
        viewingAttachment && (
          <ImageViewer
            src={viewingAttachment.url}
            fileName={viewingAttachment.file_name}
            onClose={() => setViewingAttachment(null)}
          />
        )
      }
    </div >
  );
}
