import { useRef, useState } from 'react';
import { IonIcon } from '@ionic/react';
import { arrowUndo } from 'ionicons/icons';
import styles from './ChatBubble.module.scss';

interface ChatBubbleProps {
  senderName: string;
  message: string;
  isSent: boolean;
  avatarColor: string;
  showName?: boolean;
  showAvatar?: boolean;
  onReply?: () => void;
  onLongPress?: () => void;
  onAvatarClick?: () => void;
  replyTo?: {
    senderName: string;
    message: string;
    avatarColor?: string;
  };
  timestamp?: string;
}

function formatTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false });
}

function getInitials(name: string): string {
  return name.slice(0, 2).toUpperCase();
}

const SWIPE_THRESHOLD = 60;
const SWIPE_MAX = 80;

export function ChatBubble({ senderName, message, isSent, avatarColor, showName = true, showAvatar = true, onReply, onLongPress, onAvatarClick, replyTo, timestamp }: ChatBubbleProps) {
  const [offset, setOffset] = useState(0);
  const [animating, setAnimating] = useState(false);
  const startX = useRef(0);
  const startY = useRef(0);
  const swiping = useRef(false);
  const directionLocked = useRef<'horizontal' | 'vertical' | null>(null);
  const longPressTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const longPressFired = useRef(false);

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
    longPressFired.current = false;
    setAnimating(false);

    if (onLongPress && /iPad|iPhone|iPod/.test(navigator.userAgent)) {
      longPressTimer.current = setTimeout(() => {
        longPressFired.current = true;
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

    const clamped = Math.min(Math.max(dx, 0), SWIPE_MAX);
    if (clamped > 0) {
      swiping.current = true;
      setOffset(clamped);
    }
  }

  function onTouchEnd() {
    clearLongPress();
    if (longPressFired.current) return;
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
      if (!longPressFired.current) {
        longPressFired.current = true;
        onLongPress();
      }
    }
  }

  const progress = Math.min(offset / SWIPE_THRESHOLD, 1);

  return (
    <div className={styles.swipeContainer}>
      <div
        className={styles.replyIcon}
        style={{ opacity: progress, transform: `scale(${0.5 + progress * 0.5})` }}
      >
        <IonIcon icon={arrowUndo} />
      </div>
      <div
        className={`${styles.swipeContent} ${animating ? styles.snapBack : ''}`}
        style={{ transform: `translateX(${offset}px)` }}
        onTouchStart={onTouchStart}
        onTouchMove={onTouchMove}
        onTouchEnd={onTouchEnd}
        onContextMenu={handleContextMenu}
        onTransitionEnd={() => setAnimating(false)}
      >
        <div className={`${styles.chatRow} ${isSent ? styles.sent : styles.received}`}>
          {showAvatar ? (
            <div
              className={styles.avatar}
              style={{ backgroundColor: avatarColor, cursor: onAvatarClick ? 'pointer' : undefined }}
              onClick={onAvatarClick}
            >
              {getInitials(senderName)}
            </div>
          ) : (
            <div className={styles.avatarSpacer} />
          )}
          <div className={styles.bubble}>
            {!isSent && showName && <div className={styles.senderName}>{senderName}</div>}
            {replyTo && (
              <div className={styles.replyPreview}>
                <div className={styles.replyPreviewName}>{replyTo.senderName}</div>
                <div className={styles.replyPreviewText}>{replyTo.message}</div>
              </div>
            )}
            <div className={styles.messageText}>{message}</div>
            {timestamp && (
              <div className={styles.timestamp}>{formatTime(timestamp)}</div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
