import { IonIcon } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { alertCircleOutline, closeCircle, refreshOutline } from 'ionicons/icons';
import styles from './UploadPreview.module.scss';

export type ComposeUploadDraftStatus = 'uploading' | 'uploaded' | 'error';

export interface ImageUploadDraft {
  localId: string;
  kind: 'image';
  name: string;
  previewUrl: string;
  progress: number;
  status: ComposeUploadDraftStatus;
  attachmentId?: string;
  errorMessage?: string;
}

interface UploadPreviewProps {
  drafts: ImageUploadDraft[];
  onRemove: (localId: string) => void;
  onRetry: (localId: string) => void;
}

export function UploadPreview({ drafts, onRemove, onRetry }: UploadPreviewProps) {
  if (drafts.length === 0) return null;

  return (
    <div className={styles.previewTray} aria-label={t`Attachment preview tray`}>
      {drafts.map((draft) => (
        <article key={draft.localId} className={styles.card}>
          <img src={draft.previewUrl} alt={draft.name} className={styles.previewImage} />
          <button
            type="button"
            className={styles.removeButton}
            aria-label={t`Remove ${draft.name}`}
            onClick={() => onRemove(draft.localId)}
          >
            <IonIcon icon={closeCircle} />
          </button>

          {draft.status !== 'uploaded' && (
            <div className={`${styles.overlay} ${draft.status === 'error' ? styles.overlayError : ''}`}>
              {draft.status === 'uploading' ? (
                <>
                  <div className={styles.progressRing} aria-hidden="true">
                    <svg viewBox="0 0 36 36">
                      <path
                        className={styles.progressTrack}
                        d="M18 2.5a15.5 15.5 0 1 1 0 31a15.5 15.5 0 1 1 0-31"
                      />
                      <path
                        className={styles.progressValue}
                        d="M18 2.5a15.5 15.5 0 1 1 0 31a15.5 15.5 0 1 1 0-31"
                        style={{ strokeDasharray: `${draft.progress}, 100` }}
                      />
                    </svg>
                    <span className={styles.progressLabel}>{draft.progress}%</span>
                  </div>
                  <span className={styles.statusText}>{t`Uploading`}</span>
                </>
              ) : (
                <>
                  <IonIcon icon={alertCircleOutline} className={styles.errorIcon} />
                  <span className={styles.statusText}>{draft.errorMessage ?? t`Upload failed`}</span>
                  <button
                    type="button"
                    className={styles.retryButton}
                    onClick={() => onRetry(draft.localId)}
                  >
                    <IonIcon icon={refreshOutline} />
                    {t`Retry`}
                  </button>
                </>
              )}
            </div>
          )}
        </article>
      ))}
    </div>
  );
}

// When file/video/audio previews are added, keep this tray-level API unchanged and
// branch on draft.kind into dedicated card renderers. The compose bar should continue
// to own draft lifecycle, while this component stays focused on presentation/actions.
