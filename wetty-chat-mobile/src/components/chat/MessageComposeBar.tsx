import { useEffect, useRef, useState, useCallback } from 'react';
import { IonIcon } from '@ionic/react';
import { addCircleOutline, happyOutline, paperPlane, closeCircle } from 'ionicons/icons';
import styles from './MessageComposeBar.module.scss';

interface ReplyTo {
  messageId: string;
  username: string;
  text: string;
}

interface MessageComposeBarProps {
  onSend: (text: string) => void;
  replyTo?: ReplyTo;
  onCancelReply?: () => void;
}

export function MessageComposeBar({ onSend, replyTo, onCancelReply }: MessageComposeBarProps) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const [text, setText] = useState('');

  const handleSend = useCallback(() => {
    const trimmed = text.trim();
    if (!trimmed) return;
    onSend(trimmed);
    setText('');
    const ta = textareaRef.current;
    if (ta) ta.style.height = 'auto';
  }, [text, onSend]);

  const handleSendRef = useRef(handleSend);
  useEffect(() => {
    handleSendRef.current = handleSend;
  }, [handleSend]);

  useEffect(() => {
    const textarea = textareaRef.current;
    if (!textarea) return;
    textarea.setAttribute('enterkeyhint', 'send');
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        handleSendRef.current();
      }
    };
    textarea.addEventListener('keydown', onKeyDown);
    return () => textarea.removeEventListener('keydown', onKeyDown);
  }, []);

  return (
    <div className={styles.bar}>
      <button type="button" className={styles.attachBtn} aria-label="Attach">
        <IonIcon icon={addCircleOutline} />
      </button>
      <div className={styles.inputWrapper}>
        {replyTo && (
          <div className={styles.replyPreview}>
            <div className={styles.replyText}>
              <span className={styles.replyUsername}>Replying to {replyTo.username}</span>
              <span className={styles.replySnippet}>{replyTo.text}</span>
            </div>
            <button type="button" className={styles.replyClose} aria-label="Cancel reply" onClick={onCancelReply}>
              <IonIcon icon={closeCircle} />
            </button>
          </div>
        )}
        <div className={styles.inputRow}>
          <textarea
            ref={textareaRef}
            className={styles.textarea}
            placeholder="Message"
            value={text}
            rows={1}
            onChange={(e) => {
              setText(e.target.value);
              e.target.style.height = 'auto';
              e.target.style.height = `${Math.min(e.target.scrollHeight, 120)}px`;
            }}
          />
          <button type="button" className={styles.stickerBtn} aria-label="Sticker">
            <IonIcon icon={happyOutline} />
          </button>
        </div>
      </div>
      <button
        type="button"
        className={`${styles.sendBtn}${text.trim().length === 0 ? ` ${styles.disabled}` : ''}`}
        onClick={handleSend}
        aria-label="Send message"
      >
        <IonIcon icon={paperPlane} />
      </button>
    </div>
  );
}
