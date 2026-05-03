import { IonIcon } from '@ionic/react';
import { playCircle } from 'ionicons/icons';
import type { ChatAttachmentListItem } from '@/api/attachments';
import { DisplayableImage } from '@/components/shared/DisplayableImage';
import styles from './ChatAttachmentGrid.module.scss';

interface ChatAttachmentGridProps {
  attachments: ChatAttachmentListItem[];
  onOpen: (attachmentId: string) => void;
}

function attachmentLabel(attachment: ChatAttachmentListItem) {
  return attachment.fileName || 'Attachment';
}

export function ChatAttachmentGrid({ attachments, onOpen }: ChatAttachmentGridProps) {
  if (attachments.length === 0) {
    return null;
  }

  return (
    <div className={styles.grid}>
      {attachments.map((attachment) => {
        const isVideo = attachment.kind.startsWith('video/');
        return (
          <button
            key={attachment.id}
            type="button"
            className={styles.tile}
            onClick={() => onOpen(attachment.id)}
            aria-label={attachmentLabel(attachment)}
          >
            {isVideo ? (
              <video src={attachment.url} className={styles.media} muted playsInline preload="metadata" />
            ) : (
              <DisplayableImage
                src={attachment.url}
                mimeType={attachment.kind}
                fileName={attachment.fileName}
                alt=""
                className={styles.media}
                loading="lazy"
              />
            )}
            {isVideo && (
              <span className={styles.videoBadge} aria-hidden="true">
                <IonIcon icon={playCircle} />
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}
