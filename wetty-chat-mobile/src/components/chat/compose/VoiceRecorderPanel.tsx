import { IonIcon } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { lockClosedOutline, paperPlaneOutline, trashOutline } from 'ionicons/icons';
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
  onFinish: (mode: 'send' | 'cancel') => void;
}

export function VoiceRecorderPanel({ voiceRecorder, onFinish }: VoiceRecorderPanelProps) {
  let hint = t`Slide left to cancel, up to lock`;
  if (voiceRecorder.phase === 'locked') {
    hint = t`Locked recording`;
  } else if (voiceRecorder.phase === 'uploading') {
    hint = t`Uploading ${voiceRecorder.uploadProgress}%`;
  } else if (voiceRecorder.cancelArmed) {
    hint = t`Release to cancel`;
  } else if (voiceRecorder.phase === 'requesting') {
    hint = t`Waiting for microphone…`;
  }

  return (
    <div className={styles.voiceRecorder} data-phase={voiceRecorder.phase}>
      <div className={styles.voiceRecorderMain}>
        <div className={styles.voiceIndicator} aria-hidden="true" />
        <span className={styles.voiceTimer}>{formatVoiceDuration(voiceRecorder.durationMs)}</span>
        <span className={styles.voiceHint}>{hint}</span>
      </div>
      {voiceRecorder.phase === 'locked' ? (
        <div className={styles.voiceActions}>
          <button
            type="button"
            className={`${styles.voiceActionBtn} ${styles.voiceCancelBtn}`}
            onClick={() => onFinish('cancel')}
            aria-label={t`Cancel recording`}
          >
            <IonIcon icon={trashOutline} />
          </button>
          <button
            type="button"
            className={`${styles.voiceActionBtn} ${styles.voiceSendBtn}`}
            onClick={() => onFinish('send')}
            aria-label={t`Send voice message`}
          >
            <IonIcon icon={paperPlaneOutline} />
          </button>
        </div>
      ) : voiceRecorder.phase === 'recording' ? (
        <div className={styles.voiceLockBadge} aria-hidden="true">
          <IonIcon icon={lockClosedOutline} />
        </div>
      ) : null}
    </div>
  );
}
