import { useState, type CSSProperties, type HTMLAttributes, type ReactNode, type Ref } from 'react';
import { IonIcon } from '@ionic/react';
import {
  arrowUndo,
  chatbubbles,
  checkmarkCircle,
  checkmarkCircleOutline,
  documentOutline,
  femaleOutline,
  maleOutline,
} from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import { useSelector } from 'react-redux';
import styles from './ChatBubble.module.scss';
import type { Attachment, MentionInfo, ReactionSummary, UserGroupInfo } from '@/api/messages';
import { ImageViewer } from '@/components/chat/ImageViewer';
import { formatMessagePreview, type PreviewMessage, getNotificationPreviewLabels } from '@/utils/messagePreview';
import { selectChatFontSizeStyle, selectEffectiveLocale } from '@/store/settingsSlice';
import { UserAvatar } from '@/components/UserAvatar';
import { useMouseDetected } from '@/hooks/platformHooks';
import { parseInviteCodeFromUrl } from '@/utils/inviteUrl';
import { VoiceMessageBubble } from './VoiceMessageBubble';
import { InviteLinkInline } from './InviteLinkInline';

const URL_REGEX = /(https?:\/\/[A-Za-z0-9\-._~:/?#@!$&'()*+,;=%]+)/g;
const TRAILING_PUNCT = /[.,);!?]+$/;

function formatTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false });
}

function renderMessageWithLinks(message: string): ReactNode[] {
  const parts = message.split(URL_REGEX);
  if (parts.length === 1) return [message];

  return parts.map((part, i) => {
    if (i % 2 === 1) {
      const trimmed = part.replace(TRAILING_PUNCT, '');
      const suffix = part.slice(trimmed.length);
      const inviteCode = parseInviteCodeFromUrl(trimmed);
      return (
        <span key={i}>
          {inviteCode ? (
            <InviteLinkInline code={inviteCode} url={trimmed} />
          ) : (
            <a
              href={trimmed}
              className={styles.messageLink}
              target="_blank"
              rel="noopener noreferrer"
              onClick={(e) => e.stopPropagation()}
            >
              {trimmed}
            </a>
          )}
          {suffix}
        </span>
      );
    }

    return part;
  });
}

const MENTION_TEST = /@\[uid:\d+\]/;

function renderMessageContent(
  message: string,
  mentions: MentionInfo[] | undefined,
  currentUserUid: number | null | undefined,
  onMentionClick: ((uid: number) => void) | undefined,
): ReactNode[] {
  if (!MENTION_TEST.test(message)) {
    return renderMessageWithLinks(message);
  }

  const mentionMap = new Map<number, string>();
  if (mentions) {
    for (const m of mentions) {
      if (m.username) mentionMap.set(m.uid, m.username);
    }
  }

  const regex = /@\[uid:(\d+)\]/g;
  const result: ReactNode[] = [];
  let lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = regex.exec(message)) !== null) {
    if (match.index > lastIndex) {
      result.push(...renderMessageWithLinks(message.slice(lastIndex, match.index)));
    }

    const uid = parseInt(match[1], 10);
    const username = mentionMap.get(uid);
    const isSelf = currentUserUid != null && uid === currentUserUid;
    const clickable = onMentionClick != null;
    result.push(
      <span
        key={`mention-${uid}-${match.index}`}
        className={`${styles.mention}${isSelf ? ` ${styles.mentionSelf}` : ''}${clickable ? ` ${styles.mentionClickable}` : ''}`}
        onClick={
          clickable
            ? (e) => {
                e.stopPropagation();
                onMentionClick(uid);
              }
            : undefined
        }
      >
        @{username ?? `User ${uid}`}
      </span>,
    );
    lastIndex = match.index + match[0].length;
  }

  if (lastIndex < message.length) {
    result.push(...renderMessageWithLinks(message.slice(lastIndex)));
  }

  return result;
}

function getImageLayoutStyle(
  width: number | null | undefined,
  height: number | null | undefined,
  maxImageHeight: number,
): CSSProperties | undefined {
  if (!width || !height || width <= 0 || height <= 0) {
    return undefined;
  }

  const aspectRatio = width / height;
  const imageStyle: CSSProperties = {
    aspectRatio: `${width} / ${height}`,
  };

  if (height > maxImageHeight) {
    imageStyle.width = Math.min(width, maxImageHeight * aspectRatio);
  } else {
    imageStyle.width = width;
  }

  return imageStyle;
}

type BubblePropsOverride = Omit<HTMLAttributes<HTMLDivElement>, 'children' | 'className' | 'style'> & {
  className?: string;
  style?: CSSProperties;
  [dataAttr: `data-${string}`]: string | undefined;
};

export interface ChatBubbleBaseProps {
  messageType?: 'text' | 'audio';
  senderName: string;
  senderGender?: number;
  senderGroup?: UserGroupInfo | null;
  message: string;
  isSent: boolean;
  avatarUrl?: string;
  showName?: boolean;
  showAvatar?: boolean;
  onReply?: () => void;
  onReplyTap?: () => void;
  onAvatarClick?: () => void;
  replyTo?: {
    senderName: string;
    preview: PreviewMessage;
  };
  timestamp?: string;
  edited?: boolean;
  isConfirmed?: boolean;
  threadInfo?: { replyCount: number };
  onThreadClick?: () => void;
  attachments?: Attachment[];
  maxImageHeight?: number;
  reactions?: ReactionSummary[];
  onReactionToggle?: (emoji: string, currentlyReacted: boolean) => void;
  layout?: 'thread' | 'bubble-only';
  interactionMode?: 'interactive' | 'read-only';
  bubbleProps?: BubblePropsOverride;
  bubbleRef?: Ref<HTMLDivElement>;
  mentions?: MentionInfo[];
  currentUserUid?: number | null;
  onMentionClick?: (uid: number) => void;
}

export function ChatBubbleBase({
  messageType = 'text',
  senderName,
  senderGender,
  senderGroup,
  message,
  isSent,
  avatarUrl,
  showName = true,
  showAvatar = true,
  onReply,
  onReplyTap,
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
  layout = 'thread',
  interactionMode = 'interactive',
  bubbleProps,
  bubbleRef,
  mentions,
  currentUserUid,
  onMentionClick,
}: ChatBubbleBaseProps) {
  const [viewingAttachmentIndex, setViewingAttachmentIndex] = useState<number | null>(null);
  const mouseDetected = useMouseDetected();
  const chatFontSizeStyle = useSelector(selectChatFontSizeStyle);
  const locale = useSelector(selectEffectiveLocale);
  const interactive = interactionMode === 'interactive';
  const imageAttachments =
    attachments?.filter((att) => att.kind.startsWith('image/') || att.kind.startsWith('video/')) ?? [];
  const { className: bubbleClassName, style: bubbleStyle, ...bubbleRestProps } = bubbleProps ?? {};

  function logAttachmentLoad(
    kind: 'image' | 'video',
    attachment: Attachment,
    element: HTMLImageElement | HTMLVideoElement,
  ) {
    if (!import.meta.env.DEV) return;

    const rect = element.getBoundingClientRect();
    console.log('[ChatBubble] attachment-load', {
      kind,
      attachmentId: attachment.id,
      attachmentKind: attachment.kind,
      src: attachment.url,
      metaWidth: attachment.width ?? null,
      metaHeight: attachment.height ?? null,
      renderedWidth: Math.round(rect.width),
      renderedHeight: Math.round(rect.height),
      naturalWidth: 'naturalWidth' in element ? element.naturalWidth : element.videoWidth,
      naturalHeight: 'naturalHeight' in element ? element.naturalHeight : element.videoHeight,
    });
  }

  function renderAttachment(att: Attachment) {
    if (att.kind.startsWith('image/')) {
      const imageLayoutStyle = getImageLayoutStyle(att.width, att.height, maxImageHeight);
      const imageContainerStyle: CSSProperties = {
        maxHeight: maxImageHeight,
        ...(imageLayoutStyle ?? {}),
      };

      const image = (
        <img
          src={att.url}
          alt={t`Attachment`}
          className={styles.attachmentImage}
          style={imageLayoutStyle ? undefined : { maxHeight: maxImageHeight }}
          onLoad={(event) => {
            logAttachmentLoad('image', att, event.currentTarget);
          }}
        />
      );

      if (!interactive) {
        return (
          <div key={att.id} className={styles.attachmentStatic} style={imageContainerStyle}>
            {image}
          </div>
        );
      }

      return (
        <button
          key={att.id}
          type="button"
          className={styles.attachmentImageButton}
          style={imageContainerStyle}
          onClick={() => {
            const imageIndex = imageAttachments.findIndex((imageAttachment) => imageAttachment.id === att.id);
            setViewingAttachmentIndex(imageIndex >= 0 ? imageIndex : 0);
          }}
        >
          {image}
        </button>
      );
    }

    if (att.kind.startsWith('video/')) {
      const imageLayoutStyle = getImageLayoutStyle(att.width, att.height, maxImageHeight);
      const imageContainerStyle: CSSProperties = {
        maxHeight: maxImageHeight,
        ...(imageLayoutStyle ?? {}),
      };

      const video = (
        <video
          autoPlay
          loop
          muted
          playsInline
          src={att.url}
          className={styles.attachmentImage}
          style={imageLayoutStyle ? undefined : { maxHeight: maxImageHeight }}
          onLoadedMetadata={(event) => {
            logAttachmentLoad('video', att, event.currentTarget);
          }}
        />
      );

      if (!interactive) {
        return (
          <div key={att.id} className={styles.attachmentStatic} style={imageContainerStyle}>
            {video}
          </div>
        );
      }

      return (
        <button
          key={att.id}
          type="button"
          rel="noopener noreferrer"
          className={styles.attachmentImageButton}
          style={imageContainerStyle}
          onClick={() => {
            const imageIndex = imageAttachments.findIndex((imageAttachment) => imageAttachment.id === att.id);
            setViewingAttachmentIndex(imageIndex >= 0 ? imageIndex : 0);
          }}
        >
          {video}
        </button>
      );
    }

    if (att.kind.startsWith('audio/')) {
      if (messageType === 'audio') {
        return <VoiceMessageBubble key={att.id} src={att.url} />;
      }

      if (!interactive) {
        return (
          <div key={att.id} className={styles.filePlaceholder}>
            <IonIcon icon={documentOutline} className={styles.fileIcon} />
            <span className={styles.fileName}>{att.fileName}</span>
          </div>
        );
      }

      return (
        <a key={att.id} className={styles.filePlaceholder} href={att.url} target="_blank" rel="noopener noreferrer">
          <IonIcon icon={documentOutline} className={styles.fileIcon} />
          <span className={styles.fileName}>{att.fileName}</span>
        </a>
      );
    }

    if (!interactive) {
      return (
        <div key={att.id} className={styles.filePlaceholder}>
          <IonIcon icon={documentOutline} className={styles.fileIcon} />
          <span className={styles.fileName}>{att.fileName}</span>
        </div>
      );
    }

    return (
      <a key={att.id} className={styles.filePlaceholder} href={att.url} target="_blank" rel="noopener noreferrer">
        <IonIcon icon={documentOutline} className={styles.fileIcon} />
        <span className={styles.fileName}>{att.fileName}</span>
      </a>
    );
  }

  const bubble = (
    <div
      ref={bubbleRef}
      {...bubbleRestProps}
      className={[styles.bubble, mouseDetected ? styles.mouseSelectable : '', bubbleClassName]
        .filter(Boolean)
        .join(' ')}
      style={{ fontSize: chatFontSizeStyle, ...bubbleStyle }}
    >
      {showName && (
        <div className={styles.sender}>
          <span className={styles.senderName}>{senderName}</span>
          {senderGroup && (
            <span className={styles.senderGroup} color={senderGroup.chatGroupColor!}>
              {senderGroup.name}
            </span>
          )}
          {senderGender != null &&
            (senderGender === 2 ? (
              <IonIcon icon={femaleOutline} className={`${styles.gender} ${styles.gender2}`} />
            ) : (
              <IonIcon icon={maleOutline} className={`${styles.gender} ${styles.gender1}`} />
            ))}
        </div>
      )}
      {replyTo && (
        <div
          className={`${styles.replyPreview} ${interactive && onReplyTap ? styles.replyPreviewTappable : ''}`}
          onClick={interactive ? onReplyTap : undefined}
        >
          <div className={styles.replyPreviewName}>{replyTo.senderName}</div>
          <div className={styles.replyPreviewText}>
            {formatMessagePreview(replyTo.preview, getNotificationPreviewLabels(locale))}
          </div>
        </div>
      )}
      {attachments && attachments.length > 0 && (
        <div className={styles.attachmentsContainer}>{attachments.map(renderAttachment)}</div>
      )}
      <div className={styles.messageWrapper}>
        <span className={styles.messageText}>
          {renderMessageContent(message, mentions, currentUserUid, interactive ? onMentionClick : undefined)}
        </span>
        <span className={styles.timestampSpacer} />
        {timestamp && (
          <span className={styles.timestamp}>
            {formatTime(timestamp)}
            {edited && ` (${t`Edited`})`}
            {isSent && (
              <IonIcon icon={isConfirmed ? checkmarkCircle : checkmarkCircleOutline} className={styles.statusIcon} />
            )}
          </span>
        )}
      </div>
      {threadInfo && (
        <div className={styles.threadIndicator} onClick={interactive ? onThreadClick : undefined}>
          <IonIcon icon={chatbubbles} />
          <span>
            {threadInfo.replyCount} {threadInfo.replyCount === 1 ? t`reply` : t`replies`}
          </span>
        </div>
      )}
      {reactions && reactions.length > 0 && (
        <div className={styles.reactions}>
          {reactions.map((reaction) =>
            interactive ? (
              <button
                key={reaction.emoji}
                type="button"
                className={`${styles.reactionPill} ${reaction.reactedByMe ? styles.reactionPillActive : ''}`}
                onClick={(e) => {
                  e.stopPropagation();
                  onReactionToggle?.(reaction.emoji, !!reaction.reactedByMe);
                }}
              >
                <span className={styles.reactionEmoji}>{reaction.emoji}</span>
                {reaction.reactors && reaction.reactors.length > 0 ? (
                  <span className={styles.reactorAvatars}>
                    {reaction.reactors.slice(0, 5).map((reactor, i) => (
                      <img
                        key={reactor.uid}
                        src={reactor.avatarUrl ?? undefined}
                        alt=""
                        className={styles.reactorAvatar}
                        style={{ marginLeft: i > 0 ? -9 : 0, zIndex: 5 - i }}
                      />
                    ))}
                    {reaction.count > 5 && <span className={styles.reactorOverflow}>+{reaction.count - 5}</span>}
                  </span>
                ) : (
                  reaction.count > 1 && <span className={styles.reactionCount}>{reaction.count}</span>
                )}
              </button>
            ) : (
              <div
                key={reaction.emoji}
                className={`${styles.reactionPill} ${reaction.reactedByMe ? styles.reactionPillActive : ''}`}
              >
                <span className={styles.reactionEmoji}>{reaction.emoji}</span>
                {reaction.reactors && reaction.reactors.length > 0 ? (
                  <span className={styles.reactorAvatars}>
                    {reaction.reactors.slice(0, 5).map((reactor, i) => (
                      <img
                        key={reactor.uid}
                        src={reactor.avatarUrl ?? undefined}
                        alt=""
                        className={styles.reactorAvatar}
                        style={{ marginLeft: i > 0 ? -9 : 0, zIndex: 5 - i }}
                      />
                    ))}
                    {reaction.count > 5 && <span className={styles.reactorOverflow}>+{reaction.count - 5}</span>}
                  </span>
                ) : (
                  reaction.count > 1 && <span className={styles.reactionCount}>{reaction.count}</span>
                )}
              </div>
            ),
          )}
        </div>
      )}
    </div>
  );

  if (layout === 'bubble-only') {
    return <div className={`${styles.bubbleOnly} ${isSent ? styles.sent : styles.received}`}>{bubble}</div>;
  }

  return (
    <>
      <div className={`${styles.chatRow} ${isSent ? styles.sent : styles.received}`}>
        {showAvatar ? (
          <UserAvatar
            name={senderName}
            avatarUrl={avatarUrl}
            size={36}
            className={styles.avatar}
            onClick={interactive ? onAvatarClick : undefined}
          />
        ) : (
          <div className={styles.avatarSpacer} />
        )}
        {bubble}
        {interactive && onReply && (
          <button className={styles.hoverReplyBtn} onClick={onReply} aria-label={t`Reply`}>
            <IonIcon icon={arrowUndo} />
          </button>
        )}
      </div>
      {interactive && viewingAttachmentIndex !== null && imageAttachments.length > 0 && (
        <ImageViewer
          images={imageAttachments.map((image) => ({
            id: image.id,
            kind: image.kind,
            src: image.url,
            fileName: image.fileName,
            width: image.width,
            height: image.height,
          }))}
          initialIndex={viewingAttachmentIndex}
          onClose={() => setViewingAttachmentIndex(null)}
        />
      )}
    </>
  );
}
