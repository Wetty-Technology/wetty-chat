import { IonIcon } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { closeCircle } from 'ionicons/icons';
import { getMessagePreviewText } from '../messagePreview';
import type { EditingMessage, ReplyTo } from './types';
import styles from './MessageComposeBar.module.scss';

interface ComposeContextBannerProps {
  editing?: EditingMessage;
  replyTo?: ReplyTo;
  onCancelEdit?: () => void;
  onCancelReply?: () => void;
}

export function ComposeContextBanner({
  editing,
  replyTo,
  onCancelEdit,
  onCancelReply,
}: ComposeContextBannerProps) {
  if (editing) {
    return (
      <div className={styles.replyPreview}>
        <div className={styles.replyText}>
          <span className={styles.replyUsername}>{t`Edit message`}</span>
          <span className={styles.replySnippet}>{editing.text}</span>
        </div>
        <button type="button" className={styles.replyClose} aria-label={t`Cancel edit`} onClick={onCancelEdit}>
          <IonIcon icon={closeCircle} />
        </button>
      </div>
    );
  }

  if (!replyTo) {
    return null;
  }

  return (
    <div className={styles.replyPreview}>
      <div className={styles.replyText}>
        <span className={styles.replyUsername}>{t`Replying to ${replyTo.username}`}</span>
        <span className={styles.replySnippet}>
          {getMessagePreviewText({
            message: replyTo.text,
            attachments: replyTo.attachments,
            isDeleted: replyTo.isDeleted,
          })}
        </span>
      </div>
      <button type="button" className={styles.replyClose} aria-label={t`Cancel reply`} onClick={onCancelReply}>
        <IonIcon icon={closeCircle} />
      </button>
    </div>
  );
}
