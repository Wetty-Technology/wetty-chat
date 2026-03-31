import { IonBadge, IonIcon } from '@ionic/react';
import { chatbubblesOutline } from 'ionicons/icons';
import { Trans } from '@lingui/react/macro';
import type { ThreadListItem, ThreadParticipant, ThreadReplyPreview } from '@/api/threads';
import { UserAvatar } from '@/components/UserAvatar';
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

function formatParticipants(participants: ThreadParticipant[]): string {
  if (participants.length === 0) return '';
  const names = participants.map((p) => p.name ?? 'User');
  if (names.length <= 2) {
    return names.join(', ');
  }
  return `${names[0]}, ${names[1]} and ${names.length - 2} others`;
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
  onSelect: (chatId: string, threadRootId: string) => void;
}

export function ThreadListRow({ thread, locale, onSelect }: ThreadListRowProps) {
  const rootMsg = thread.threadRootMessage;
  const rootPreview = formatMessagePreview(rootMsg, getNotificationPreviewLabels(locale));
  const lastReply = thread.lastReply;
  const lastReplyPreview = lastReply ? formatReplyPreview(lastReply, locale) : null;

  return (
    <div
      className={`${styles.threadRow} ${thread.unreadCount > 0 ? styles.unread : ''}`}
      onClick={() => onSelect(thread.chatId, rootMsg.id)}
    >
      {/* Row 1: header */}
      <div className={styles.headerRow}>
        <span className={styles.headerLeft}>
          <IonIcon icon={chatbubblesOutline} className={styles.headerIcon} />
          <Trans>Thread in {thread.chatName}</Trans>
        </span>
        <span className={styles.headerTime}>
          {formatRelativeTime(thread.lastReplyAt, locale)}
          {thread.unreadCount > 0 && (
            <IonBadge color="primary" className={styles.unreadBadge}>
              {thread.unreadCount}
            </IonBadge>
          )}
        </span>
      </div>

      {/* Rows 2-4: avatar + content */}
      <div className={styles.bodyRow}>
        <UserAvatar name={thread.chatName} avatarUrl={thread.chatAvatar} size={40} />
        <div className={styles.bodyContent}>
          {/* Row 2: participants */}
          <div className={styles.participants}>{formatParticipants(thread.participants)}</div>
          {/* Row 3: replied to */}
          <div className={styles.repliedTo}>
            <span className={styles.repliedToLabel}>
              <Trans>replied to:</Trans>
            </span>{' '}
            {rootPreview || rootMsg.sender.name}
          </div>
          {/* Row 4: latest reply */}
          {lastReply && lastReplyPreview && (
            <div className={styles.latestReply}>
              <span className={styles.latestReplySender}>{lastReply.sender.name ?? 'User'}:</span> {lastReplyPreview}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
