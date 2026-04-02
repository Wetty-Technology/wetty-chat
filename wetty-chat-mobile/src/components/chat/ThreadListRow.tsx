import { IonBadge, IonItem, IonLabel } from '@ionic/react';
import type { ThreadListItem, ThreadReplyPreview } from '@/api/threads';
import { OverlayAvatar } from '@/components/OverlayAvatar';
import { formatMessagePreview, getNotificationPreviewLabels } from '@/utils/messagePreview';
import styles from './ThreadListRow.module.scss';

function formatRelativeTime(isoString: string, locale: string): string {
  const date = new Date(isoString);
  const now = new Date();

  const isSameDay =
    date.getDate() === now.getDate() && date.getMonth() === now.getMonth() && date.getFullYear() === now.getFullYear();

  if (isSameDay) {
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const rtf = new Intl.RelativeTimeFormat(locale, { numeric: 'always' });

    if (diffMins < 60) {
      return rtf.format(-Math.max(1, diffMins), 'minute');
    }
    return rtf.format(-Math.floor(diffMins / 60), 'hour');
  }

  const isSameYear = date.getFullYear() === now.getFullYear();
  if (isSameYear) {
    return Intl.DateTimeFormat(locale, { month: 'short', day: 'numeric' }).format(date);
  }
  return Intl.DateTimeFormat(locale, { year: 'numeric', month: 'short', day: 'numeric' }).format(date);
}
function formatReplyPreview(reply: ThreadReplyPreview, locale: string): string {
  // Build a preview-compatible object for formatMessagePreview
  return formatMessagePreview(
    {
      message: reply.message,
      messageType: reply.messageType as 'text',
      sticker: reply.stickerEmoji ? { emoji: reply.stickerEmoji } : undefined,
      firstAttachmentKind: reply.firstAttachmentKind ?? undefined,
      isDeleted: reply.isDeleted,
    },
    getNotificationPreviewLabels(locale),
  );
}

interface ThreadListRowProps {
  thread: ThreadListItem;
  locale: string;
  isActive?: boolean;
  onSelect: (chatId: string, threadRootId: string) => void;
}

export function ThreadListRow({ thread, locale, isActive, onSelect }: ThreadListRowProps) {
  const rootMsg = thread.threadRootMessage;
  const rootPreview = formatMessagePreview(rootMsg, getNotificationPreviewLabels(locale));
  const lastReply = thread.lastReply;
  const lastReplyPreview = lastReply ? formatReplyPreview(lastReply, locale) : null;

  return (
    <IonItem
      button
      detail={false}
      className={`${styles.threadRow} ${thread.unreadCount > 0 ? styles.unread : ''} ${isActive ? styles.active : ''}`}
      onClick={() => onSelect(thread.chatId, rootMsg.id)}
    >
      {/* Rows 2-4: avatar + content */}
      <span slot="start">
        <OverlayAvatar
          primaryName={thread.chatName}
          primaryAvatarUrl={thread.chatAvatar}
          secondaryName={rootMsg.sender.name ?? null}
          secondaryAvatarUrl={rootMsg.sender.avatarUrl ?? null}
          size={48}
        />
      </span>
      <IonLabel className={styles.bodyContent}>
        {/* Row 2: replied to */}
        <div className={styles.repliedTo}>{rootPreview || rootMsg.sender.name}</div>
        {/* Row 3: latest reply */}
        {lastReply && lastReplyPreview && (
          <p className={styles.latestReply}>
            <span className={styles.latestReplySender}>{lastReply.sender.name ?? 'User'}:</span> {lastReplyPreview}
          </p>
        )}
      </IonLabel>
      <div slot="end" className={styles.chatsListEndSlot}>
        <div className={styles.chatsListTime}>{formatRelativeTime(thread.lastReplyAt, locale)}</div>
        <div className={styles.chatsListBadge}>
          {thread.unreadCount > 0 && (
            <IonBadge color="primary" className={styles.unreadBadge}>
              {thread.unreadCount}
            </IonBadge>
          )}
        </div>
      </div>
    </IonItem>
  );
}
