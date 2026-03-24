import { useRef, useState } from 'react';
import { IonIcon } from '@ionic/react';
import { useSelector } from 'react-redux';
import { arrowUndo, chatbubbles, checkmarkCircle, checkmarkCircleOutline, documentOutline } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import styles from './ChatBubble.module.scss';
import type { Attachment, ReactionSummary } from '@/api/messages';
import { ImageViewer } from './ImageViewer';
import { getMessagePreviewText } from './messagePreview';
import { selectChatFontSizeStyle } from '@/store/settingsSlice';
import { UserAvatar } from '@/components/UserAvatar';

const URL_REGEX = /(https?:\/\/[A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+)/g;
const TRAILING_PUNCT = /[.,);!?]+$/;

export function renderMessageWithLinks(message: string): React.ReactNode[] {
  const parts = message.split(URL_REGEX);
  if (parts.length === 1) return [message];

  return parts.map((part, i) => {
    if (i % 2 === 1) {
      const trimmed = part.replace(TRAILING_PUNCT, '');
      const suffix = part.slice(trimmed.length);
      return (
        <span key={i}>
          <a
            href={trimmed}
            className={styles.messageLink}
            target="_blank"
            rel="noopener noreferrer"
            onClick={(e) => e.stopPropagation()}
          >{trimmed}</a>
          {suffix}
        </span>
      );
    }
    return part;
  });
}

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
  onLongPress?: (rect: DOMRect) => void;
  onAvatarClick?: () => void;
  replyTo?: {
    senderName: string;
    message?: string | null;
    attachments?: Attachment[];
    isDeleted?: boolean;
  };
  timestamp?: string;
  edited?: boolean;
  isConfirmed?: boolean;
  threadInfo?: { reply_count: number };
  onThreadClick?: () => void;
  attachments?: Attachment[];
  maxImageHeight?: number;
  reactions?: ReactionSummary[];
  onReactionToggle?: (emoji: string, currentlyReacted: boolean) => void;
}

function formatTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false });
}

const SWIPE_THRESHOLD = 60;
const SWIPE_MAX = 80;

function getImageLayoutStyle(
  width: number | null | undefined,
  height: number | null | undefined,
  maxImageHeight: number
): React.CSSProperties | undefined {
  if (!width || !height || width <= 0 || height <= 0) {
    return undefined;
  }

  const aspectRatio = width / height;
  const imageStyle: React.CSSProperties = {
    aspectRatio: `${width} / ${height}`,
  };

  if (height > maxImageHeight) {
    imageStyle.width = Math.min(width, maxImageHeight * aspectRatio);
  } else {
    imageStyle.width = width;
  }

  return imageStyle;
}

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
  reactions,
  onReactionToggle,
}: ChatBubbleProps) {
  const swipeSign = swipeDirection === 'left' ? -1 : 1;
  const [offset, setOffset] = useState(0);
  const [animating, setAnimating] = useState(false);
  const [viewingAttachmentIndex, setViewingAttachmentIndex] = useState<number | null>(null);
  const startX = useRef(0);
  const startY = useRef(0);
  const swiping = useRef(false);
  const directionLocked = useRef<'horizontal' | 'vertical' | null>(null);
  const longPressTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const bubbleRef = useRef<HTMLDivElement>(null);

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
        if (bubbleRef.current) {
          onLongPress(bubbleRef.current.getBoundingClientRect());
        }
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
    if (onLongPress && bubbleRef.current) {
      e.preventDefault();
      onLongPress(bubbleRef.current.getBoundingClientRect());
    }
  }

  const progress = Math.min(offset / SWIPE_THRESHOLD, 1);

  const imageAttachments = attachments?.filter(att => att.kind.startsWith('image/')) ?? [];
  const chatFontSizeStyle = useSelector(selectChatFontSizeStyle);

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
            <UserAvatar
              name={senderName}
              avatarUrl={avatarUrl}
              size={36}
              className={styles.avatar}
              onClick={onAvatarClick}
            />
          ) : (
            <div className={styles.avatarSpacer} />
          )}
          <div ref={bubbleRef} className={styles.bubble} style={{ fontSize: chatFontSizeStyle }}>
            {showName && <div className={styles.senderName}>{senderName}</div>}
            {replyTo && (
              <div
                className={`${styles.replyPreview} ${onReplyTap ? styles.replyPreviewTappable : ''}`}
                onClick={onReplyTap}
              >
                <div className={styles.replyPreviewName}>{replyTo.senderName}</div>
                <div className={styles.replyPreviewText}>{getMessagePreviewText({
                  message: replyTo.message,
                  attachments: replyTo.attachments,
                  isDeleted: replyTo.isDeleted,
                })}</div>
              </div>
            )}
            {attachments && attachments.length > 0 && (
              <div className={styles.attachmentsContainer}>
                {attachments.map((att) => {
                  if (att.kind.startsWith('image/')) {
                    const imageLayoutStyle = getImageLayoutStyle(att.width, att.height, maxImageHeight);
                    const imageContainerStyle: React.CSSProperties = {
                      maxHeight: maxImageHeight,
                      ...(imageLayoutStyle ?? {}),
                    };

                    return (
                        <button
                            key={att.id}
                            type="button"
                            className={styles.attachmentImageButton}
                            style={imageContainerStyle}
                            onClick={() => {
                              const imageIndex = imageAttachments.findIndex(image => image.id === att.id);
                              setViewingAttachmentIndex(imageIndex >= 0 ? imageIndex : 0);
                            }}
                        >
                          <img
                              src={att.url}
                              alt={t`Attachment`}
                              className={styles.attachmentImage}
                              style={imageLayoutStyle ? undefined : {maxHeight: maxImageHeight}}
                          />
                        </button>
                    );
                  }else if (att.kind.startsWith('video/')){
                      const imageLayoutStyle = getImageLayoutStyle(att.width, att.height, maxImageHeight);
                      const imageContainerStyle: React.CSSProperties = {
                          maxHeight: maxImageHeight,
                          ...(imageLayoutStyle ?? {}),
                      };
                      return (
                          <button
                              key={att.id}
                              type="button"
                              className={styles.attachmentImageButton}
                              style={imageContainerStyle}
                              onClick={() => {
                                  // const imageIndex = imageAttachments.findIndex(image => image.id === att.id);
                                  // setViewingAttachmentIndex(imageIndex >= 0 ? imageIndex : 0);
                              }}
                          >
                              <video
                                  autoPlay
                                  src={att.url}
                                  className={styles.attachmentImage}
                                  style={imageLayoutStyle ? undefined : {maxHeight: maxImageHeight}}
                              />
                          </button>
                      );
                  }else{
                    return (
                        <a
                            key={att.id}
                            className={styles.filePlaceholder}
                            href={att.url}
                            target="_blank"
                            rel="noopener noreferrer"
                        >
                          <IonIcon icon={documentOutline} className={styles.fileIcon} />
                          <span className={styles.fileName}>{att.file_name}</span>
                        </a>
                    );
                  }

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
            {threadInfo && (
              <div className={styles.threadIndicator} onClick={onThreadClick}>
                <IonIcon icon={chatbubbles} />
                <span>{threadInfo.reply_count} {threadInfo.reply_count === 1 ? t`reply` : t`replies`}</span>
              </div>
            )}
            {reactions && reactions.length > 0 && (
              <div className={styles.reactions}>
                {reactions.map(r => (
                  <button
                    key={r.emoji}
                    type="button"
                    className={`${styles.reactionPill} ${r.reacted_by_me ? styles.reactionPillActive : ''}`}
                    onClick={(e) => {
                      e.stopPropagation();
                      onReactionToggle?.(r.emoji, !!r.reacted_by_me);
                    }}
                  >
                    <span className={styles.reactionEmoji}>{r.emoji}</span>
                    {r.reactors && r.reactors.length > 0 ? (
                      <span className={styles.reactorAvatars}>
                        {r.reactors.slice(0, 5).map((reactor, i) => (
                          <img
                            key={reactor.uid}
                            src={reactor.avatar_url ?? undefined}
                            alt=""
                            className={styles.reactorAvatar}
                            style={{ marginLeft: i > 0 ? -8 : 0, zIndex: 5 - i }}
                          />
                        ))}
                        {r.count > 5 && <span className={styles.reactorOverflow}>+{r.count - 5}</span>}
                      </span>
                    ) : (
                      r.count > 1 && <span className={styles.reactionCount}>{r.count}</span>
                    )}
                  </button>
                ))}
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
      {viewingAttachmentIndex !== null && imageAttachments.length > 0 && (
        <ImageViewer
          images={imageAttachments.map(image => ({
            id: image.id,
            src: image.url,
            fileName: image.file_name,
            width: image.width,
            height: image.height,
          }))}
          initialIndex={viewingAttachmentIndex}
          onClose={() => setViewingAttachmentIndex(null)}
        />
      )}
    </div >
  );
}
