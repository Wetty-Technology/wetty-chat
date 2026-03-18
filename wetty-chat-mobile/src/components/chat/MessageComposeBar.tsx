import { useEffect, useRef, useState, useCallback } from 'react';
import { IonIcon } from '@ionic/react';
import { addCircleOutline, happyOutline, paperPlane, closeCircle, imageOutline } from 'ionicons/icons';
import styles from './MessageComposeBar.module.scss';
import { requestUploadUrl, uploadFileToS3 } from '@/api/upload';

interface ReplyTo {
  messageId: string;
  username: string;
  text: string;
}

export interface EditingMessage {
  messageId: string;
  text: string;
}

interface MessageComposeBarProps {
  onSend: (text: string, attachmentIds?: string[]) => void;
  replyTo?: ReplyTo;
  onCancelReply?: () => void;
  editing?: EditingMessage;
  onCancelEdit?: () => void;
}

export function MessageComposeBar({ onSend, replyTo, onCancelReply, editing, onCancelEdit }: MessageComposeBarProps) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [text, setText] = useState('');
  const prevTextLenRef = useRef(0);
  const [isUploading, setIsUploading] = useState(false);
  const [attachments, setAttachments] = useState<{ id: string, name: string, previewUrl?: string }[]>([]);

  useEffect(() => {
    if (editing) {
      setText(editing.text);
      const ta = textareaRef.current;
      if (ta) {
        ta.style.height = 'auto';
        ta.style.height = `${Math.min(ta.scrollHeight, 120)}px`;
      }
    } else {
      setText('');
      const ta = textareaRef.current;
      if (ta) ta.style.height = 'auto';
    }
  }, [editing]);

  const handleSend = useCallback(() => {
    const trimmed = text.trim();
    if (!trimmed && attachments.length === 0) return;
    onSend(trimmed, attachments.map(a => a.id));
    setText('');
    attachments.forEach(a => {
      if (a.previewUrl) URL.revokeObjectURL(a.previewUrl);
    });
    setAttachments([]);
    const ta = textareaRef.current;
    if (ta) ta.style.height = 'auto';
  }, [text, attachments, onSend]);

  const handleSendRef = useRef(handleSend);
  useEffect(() => {
    handleSendRef.current = handleSend;
  }, [handleSend]);

  useEffect(() => {
    const textarea = textareaRef.current;
    if (!textarea) return;
    textarea.setAttribute('enterkeyhint', 'send');
    const onKeyDown = (e: KeyboardEvent) => {
      // macOS Safari can report isComposing=false on the Enter key that
      // confirms an IME candidate, while still marking the event with 229.
      const isImeConfirm = e.isComposing || e.keyCode === 229 || e.which === 229;
      if (e.key === 'Enter' && !e.shiftKey && !isImeConfirm) {
        e.preventDefault();
        handleSendRef.current();
      }
    };
    textarea.addEventListener('keydown', onKeyDown);
    return () => textarea.removeEventListener('keydown', onKeyDown);
  }, []);

  const getImageDimensions = (file: File): Promise<{ width?: number; height?: number }> => {
    return new Promise((resolve) => {
      if (!file.type.startsWith('image/')) {
        resolve({});
        return;
      }
      const img = new Image();
      const objectUrl = URL.createObjectURL(file);
      img.onload = () => {
        resolve({ width: img.width, height: img.height });
        URL.revokeObjectURL(objectUrl);
      };
      img.onerror = () => {
        resolve({});
        URL.revokeObjectURL(objectUrl);
      };
      img.src = objectUrl;
    });
  };

  const processFile = useCallback(async (file: File) => {
    setIsUploading(true);
    let previewUrl: string | undefined;
    if (file.type.startsWith('image/')) {
      previewUrl = URL.createObjectURL(file);
    }

    try {
      const dimensions = await getImageDimensions(file);

      const res = await requestUploadUrl({
        filename: file.name,
        content_type: file.type || 'application/octet-stream',
        size: file.size,
        ...dimensions,
      });

      const { upload_url, attachment_id } = res.data;
      await uploadFileToS3(upload_url, file);

      setAttachments(prev => [...prev, { id: attachment_id, name: file.name, previewUrl }]);
    } catch (err) {
      console.error('Failed to upload attachment:', err);
      alert('Failed to upload file');
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
      }
    } finally {
      setIsUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  }, []);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    await processFile(file);
  };

  useEffect(() => {
    const handleGlobalPaste = (e: ClipboardEvent) => {
      const items = e.clipboardData?.items;
      if (!items) return;

      for (let i = 0; i < items.length; i++) {
        if (items[i].type.startsWith('image/')) {
          e.preventDefault();
          const file = items[i].getAsFile();
          if (file) {
            processFile(file);
          }
          break; // Process one image at a time
        }
      }
    };
    
    document.addEventListener('paste', handleGlobalPaste);
    return () => document.removeEventListener('paste', handleGlobalPaste);
  }, [processFile]);

  const removeAttachment = (index: number) => {
    setAttachments(prev => {
      const newAttachments = [...prev];
      const removed = newAttachments.splice(index, 1)[0];
      if (removed.previewUrl) {
        URL.revokeObjectURL(removed.previewUrl);
      }
      return newAttachments;
    });
  };

  return (
    <div className={styles.bar}>
      <input
        type="file"
        accept="image/*"
        style={{ display: 'none' }}
        ref={fileInputRef}
        onChange={handleFileChange}
      />
      <button
        type="button"
        className={styles.attachBtn}
        aria-label="Attach"
        onClick={() => fileInputRef.current?.click()}
        disabled={isUploading}
      >
        <IonIcon icon={addCircleOutline} />
      </button>
      <div className={styles.inputWrapper}>
        {editing ? (
          <div className={styles.replyPreview}>
            <div className={styles.replyText}>
              <span className={styles.replyUsername}>Edit message</span>
              <span className={styles.replySnippet}>{editing.text}</span>
            </div>
            <button type="button" className={styles.replyClose} aria-label="Cancel edit" onClick={onCancelEdit}>
              <IonIcon icon={closeCircle} />
            </button>
          </div>
        ) : replyTo ? (
          <div className={styles.replyPreview}>
            <div className={styles.replyText}>
              <span className={styles.replyUsername}>Replying to {replyTo.username}</span>
              <span className={styles.replySnippet}>{replyTo.text}</span>
            </div>
            <button type="button" className={styles.replyClose} aria-label="Cancel reply" onClick={onCancelReply}>
              <IonIcon icon={closeCircle} />
            </button>
          </div>
        ) : null}

        {attachments.length > 0 && (
          <div className={styles.attachmentsPreview}>
            {attachments.map((att, idx) => (
              <div key={idx} className={styles.attachmentChip}>
                {att.previewUrl ? (
                  <img src={att.previewUrl} alt={att.name} className={styles.attachmentPreviewImage} />
                ) : (
                  <IonIcon icon={imageOutline} />
                )}
                <span className={styles.attachmentName}>{att.name}</span>
                <button type="button" className={styles.removeAttachment} onClick={() => removeAttachment(idx)}>
                  <IonIcon icon={closeCircle} />
                </button>
              </div>
            ))}
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
              const ta = e.target;
              const newLen = e.target.value.length;
              const couldHaveShrunk = newLen < prevTextLenRef.current;
              prevTextLenRef.current = newLen;

              if (couldHaveShrunk) {
                // Text was deleted / IME confirmed — defer the collapse-and-measure
                // to the next frame so the auto pulse doesn't cause an intermediate
                // layout that shifts the scroll container.
                requestAnimationFrame(() => {
                  ta.style.height = 'auto';
                  ta.style.height = `${Math.min(ta.scrollHeight, 120)}px`;
                });
              } else {
                // Growing or same length — scrollHeight reflects needed height
                const desired = Math.min(ta.scrollHeight, 120);
                if (desired > ta.clientHeight) {
                  ta.style.height = `${desired}px`;
                }
              }
            }}
          />
          <button type="button" className={styles.stickerBtn} aria-label="Sticker">
            <IonIcon icon={happyOutline} />
          </button>
        </div>
      </div>
      <button
        type="button"
        className={`${styles.sendBtn}${(text.trim().length === 0 && attachments.length === 0) || isUploading ? ` ${styles.disabled}` : ''}`}
        onClick={handleSend}
        aria-label="Send message"
        disabled={isUploading}
      >
        <IonIcon icon={paperPlane} />
      </button>
    </div>
  );
}
