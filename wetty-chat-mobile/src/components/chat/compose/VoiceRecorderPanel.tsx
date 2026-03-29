import { IonIcon } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { documentOutline, trashOutline } from 'ionicons/icons';
import type { VoiceRecorderState } from './types';
import styles from './MessageComposeBar.module.scss';

const formatVoiceDuration = (durationMs: number) => {
  const totalSeconds = Math.max(0, Math.round(durationMs / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${seconds.toString().padStart(2, '0')}`;
};

interface VoiceRecorderPanelProps {
  voiceRecorder: VoiceRecorderState;
  onCancel: () => void;
}

export function VoiceRecorderPanel({ voiceRecorder, onCancel }: VoiceRecorderPanelProps) {
  let hint = t`Release to save`;
  if (voiceRecorder.phase === 'uploading') {
    hint = t`Uploading ${voiceRecorder.uploadProgress}%`;
  } else if (voiceRecorder.phase === 'requesting') {
    hint = t`Waiting for microphone…`;
  }

  if (voiceRecorder.phase === 'recorded' || voiceRecorder.phase === 'uploading') {
    const isUploading = voiceRecorder.phase === 'uploading';

    return (
      <div className={`${styles.voiceRecorder} ${styles.voiceRecorderDraft}`} data-phase={voiceRecorder.phase}>
        <div className={styles.voiceRecorderMain}>
          <div className={styles.voiceDraftIcon} aria-hidden="true">
            <IonIcon icon={documentOutline} />
          </div>
          <div className={styles.voiceDraftMeta}>
            <span className={styles.voiceTimer}>{formatVoiceDuration(voiceRecorder.durationMs)}</span>
            <span className={styles.voiceHint}>{isUploading ? hint : t`Voice message`}</span>
          </div>
        </div>
        <div className={styles.voiceActions}>
          <button
            type="button"
            className={`${styles.voiceActionBtn} ${styles.voiceCancelBtn}`}
            onClick={onCancel}
            aria-label={t`Delete recording`}
            disabled={isUploading}
          >
            <IonIcon icon={trashOutline} />
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className={styles.voiceRecorder} data-phase={voiceRecorder.phase}>
      <div className={styles.voiceRecorderMain}>
        <div className={styles.voiceIndicator} aria-hidden="true" />
        <span className={styles.voiceTimer}>{formatVoiceDuration(voiceRecorder.durationMs)}</span>
        <span className={styles.voiceHint}>{hint}</span>
      </div>
    </div>
  );
}
