import { useEffect } from 'react';
import { IonIcon } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { happyOutline } from 'ionicons/icons';
import type { EditingMessage } from './types';
import styles from './MessageComposeBar.module.scss';

interface ComposeInputProps {
  textareaRef: React.RefObject<HTMLTextAreaElement | null>;
  text: string;
  onTextChange: (value: string) => void;
  onFocusChange?: (focused: boolean) => void;
  onSubmit: () => void;
  canRequestRecentEdit: boolean;
  onRequestEditLastMessage?: () => boolean;
  editing?: EditingMessage;
  isUnchangedEdit: boolean;
  onCancelEdit?: () => void;
  onStickerPress?: () => void;
  isStickerActive?: boolean;
  onMentionKeyDown?: (event: KeyboardEvent) => boolean;
}

export function ComposeInput({
  textareaRef,
  text,
  onTextChange,
  onFocusChange,
  onSubmit,
  canRequestRecentEdit,
  onRequestEditLastMessage,
  editing,
  isUnchangedEdit,
  onCancelEdit,
  onStickerPress,
  isStickerActive,
  onMentionKeyDown,
}: ComposeInputProps) {
  useEffect(() => {
    const textarea = textareaRef.current;
    if (!textarea) return;

    textarea.setAttribute('enterkeyhint', 'send');
    const onKeyDown = (event: KeyboardEvent) => {
      // Let mention autocomplete consume the event first
      if (onMentionKeyDown?.(event)) return;

      const isImeConfirm = event.isComposing || event.keyCode === 229 || event.which === 229;
      if (event.key === 'Enter' && !event.shiftKey && !isImeConfirm) {
        event.preventDefault();
        onSubmit();
        return;
      }

      if (event.key === 'ArrowUp' && canRequestRecentEdit) {
        const didStartEdit = onRequestEditLastMessage?.() ?? false;
        if (didStartEdit) {
          event.preventDefault();
        }
        return;
      }

      if (event.key === 'Escape' && editing && isUnchangedEdit) {
        event.preventDefault();
        onCancelEdit?.();
      }
    };

    textarea.addEventListener('keydown', onKeyDown);
    return () => textarea.removeEventListener('keydown', onKeyDown);
  }, [
    canRequestRecentEdit,
    editing,
    isUnchangedEdit,
    onCancelEdit,
    onMentionKeyDown,
    onRequestEditLastMessage,
    onSubmit,
    textareaRef,
  ]);

  return (
    <div className={styles.inputRow}>
      <textarea
        id="messageCompose"
        ref={textareaRef}
        className={styles.textarea}
        placeholder={t`Message`}
        value={text}
        rows={1}
        onChange={(event) => onTextChange(event.target.value)}
        onFocus={() => onFocusChange?.(true)}
        onBlur={() => onFocusChange?.(false)}
      />
      <button
        type="button"
        className={`${styles.stickerBtn}${isStickerActive ? ` ${styles.stickerBtnActive}` : ''}`}
        aria-label={t`Sticker`}
        aria-pressed={isStickerActive}
        onClick={onStickerPress}
      >
        <IonIcon icon={happyOutline} />
      </button>
    </div>
  );
}
