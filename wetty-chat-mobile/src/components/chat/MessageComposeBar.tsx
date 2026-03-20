import { useEffect, useRef, useState, useCallback, useLayoutEffect } from 'react';
import { IonIcon } from '@ionic/react';
import { addCircleOutline, happyOutline, paperPlane, closeCircle } from 'ionicons/icons';
import styles from './MessageComposeBar.module.scss';
import { UploadPreview, type ImageUploadDraft } from './UploadPreview';

interface ReplyTo {
  messageId: string;
  username: string;
  text: string;
}

export interface EditingMessage {
  messageId: string;
  text: string;
}

export interface ComposeUploadInput {
  file: File;
  signal: AbortSignal;
  onProgress: (progress: number) => void;
  dimensions?: {
    width?: number;
    height?: number;
  };
}

export interface ComposeUploadResult {
  attachmentId: string;
}

interface DraftUploadRecord {
  draft: ImageUploadDraft;
  file: File;
  abortController?: AbortController;
}

interface MessageComposeBarProps {
  onSend: (text: string, attachmentIds?: string[]) => void;
  uploadAttachment: (input: ComposeUploadInput) => Promise<ComposeUploadResult>;
  replyTo?: ReplyTo;
  onCancelReply?: () => void;
  editing?: EditingMessage;
  onCancelEdit?: () => void;
}

const isAbortError = (error: unknown) => (
  error instanceof DOMException && error.name === 'AbortError'
);

const createDraftId = () => {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }

  return `draft_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
};

export function MessageComposeBar({
  onSend,
  uploadAttachment,
  replyTo,
  onCancelReply,
  editing,
  onCancelEdit,
}: MessageComposeBarProps) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const draftsRef = useRef<DraftUploadRecord[]>([]);
  const [text, setText] = useState('');
  const prevTextLenRef = useRef(0);
  const [drafts, setDrafts] = useState<DraftUploadRecord[]>([]);

  const resizeTextarea = useCallback(() => {
    const ta = textareaRef.current;
    if (!ta) return;

    ta.style.height = 'auto';
    ta.style.height = `${Math.min(ta.scrollHeight, 120)}px`;
  }, []);

  const cleanupDraft = useCallback((draft: DraftUploadRecord) => {
    draft.abortController?.abort();
    URL.revokeObjectURL(draft.draft.previewUrl);
  }, []);

  const clearDrafts = useCallback((currentDrafts: DraftUploadRecord[]) => {
    currentDrafts.forEach(cleanupDraft);
    setDrafts([]);
  }, [cleanupDraft]);

  useEffect(() => {
    draftsRef.current = drafts;
  }, [drafts]);

  useEffect(() => {
    if (editing) {
      setText(editing.text);
      prevTextLenRef.current = editing.text.length;
      setDrafts((prev) => {
        prev.forEach(cleanupDraft);
        return [];
      });
    } else {
      setText('');
      prevTextLenRef.current = 0;
      const ta = textareaRef.current;
      if (ta) ta.style.height = 'auto';
    }
  }, [cleanupDraft, editing]);

  useLayoutEffect(() => {
    resizeTextarea();
  }, [resizeTextarea, text]);

  useEffect(() => () => {
    draftsRef.current.forEach(cleanupDraft);
  }, [cleanupDraft]);

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

  const startUpload = useCallback(async (localId: string, file: File) => {
    const abortController = new AbortController();

    setDrafts((prev) => prev.map((draftRecord) => (
      draftRecord.draft.localId === localId
        ? {
          ...draftRecord,
          abortController,
          draft: {
            ...draftRecord.draft,
            status: 'uploading',
            progress: 0,
            errorMessage: undefined,
            attachmentId: undefined,
          },
        }
        : draftRecord
    )));

    try {
      const dimensions = await getImageDimensions(file);
      const result = await uploadAttachment({
        file,
        dimensions,
        signal: abortController.signal,
        onProgress: (progress) => {
          setDrafts((prev) => prev.map((draftRecord) => (
            draftRecord.draft.localId === localId
              ? {
                ...draftRecord,
                draft: {
                  ...draftRecord.draft,
                  progress,
                },
              }
              : draftRecord
          )));
        },
      });

      setDrafts((prev) => prev.map((draftRecord) => (
        draftRecord.draft.localId === localId
          ? {
            ...draftRecord,
            abortController: undefined,
            draft: {
              ...draftRecord.draft,
              status: 'uploaded',
              progress: 100,
              attachmentId: result.attachmentId,
              errorMessage: undefined,
            },
          }
          : draftRecord
      )));
    } catch (error) {
      if (isAbortError(error) || abortController.signal.aborted) {
        return;
      }

      console.error('Failed to upload attachment:', error);
      setDrafts((prev) => prev.map((draftRecord) => (
        draftRecord.draft.localId === localId
          ? {
            ...draftRecord,
            abortController: undefined,
            draft: {
              ...draftRecord.draft,
              status: 'error',
              progress: 0,
              attachmentId: undefined,
              errorMessage: 'Upload failed',
            },
          }
          : draftRecord
      )));
    } finally {
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  }, [uploadAttachment]);

  const queueFiles = useCallback((files: File[]) => {
    const imageFiles = files.filter((file) => file.type.startsWith('image/'));
    if (imageFiles.length === 0) return;

    const queuedDrafts = imageFiles.map((file) => ({
      file,
      draft: {
        localId: createDraftId(),
        kind: 'image' as const,
        name: file.name,
        previewUrl: URL.createObjectURL(file),
        progress: 0,
        status: 'uploading' as const,
      },
    }));

    setDrafts((prev) => [...prev, ...queuedDrafts]);
    queuedDrafts.forEach(({ draft, file }) => {
      void startUpload(draft.localId, file);
    });
  }, [startUpload]);

  const handleSend = useCallback(() => {
    const trimmed = text.trim();
    const attachmentIds = drafts
      .map((draftRecord) => draftRecord.draft.attachmentId)
      .filter((attachmentId): attachmentId is string => Boolean(attachmentId));

    if (!trimmed && attachmentIds.length === 0) return;

    onSend(trimmed, attachmentIds);
    setText('');
    clearDrafts(drafts);
    const ta = textareaRef.current;
    if (ta) ta.style.height = 'auto';
  }, [clearDrafts, drafts, onSend, text]);

  const handleSendRef = useRef(handleSend);
  useEffect(() => {
    handleSendRef.current = handleSend;
  }, [handleSend]);

  useEffect(() => {
    const textarea = textareaRef.current;
    if (!textarea) return;
    textarea.setAttribute('enterkeyhint', 'send');
    const onKeyDown = (e: KeyboardEvent) => {
      const isImeConfirm = e.isComposing || e.keyCode === 229 || e.which === 229;
      if (e.key === 'Enter' && !e.shiftKey && !isImeConfirm) {
        e.preventDefault();
        handleSendRef.current();
      }
    };
    textarea.addEventListener('keydown', onKeyDown);
    return () => textarea.removeEventListener('keydown', onKeyDown);
  }, []);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (editing) return;
    const files = Array.from(e.target.files ?? []);
    queueFiles(files);
  };

  useEffect(() => {
    const handleGlobalPaste = (e: ClipboardEvent) => {
      if (editing) return;

      const items = e.clipboardData?.items;
      if (!items) return;

      const files: File[] = [];

      for (let i = 0; i < items.length; i++) {
        if (items[i].type.startsWith('image/')) {
          const file = items[i].getAsFile();
          if (file) {
            files.push(file);
          }
        }
      }

      if (files.length > 0) {
        e.preventDefault();
        queueFiles(files);
      }
    };

    document.addEventListener('paste', handleGlobalPaste);
    return () => document.removeEventListener('paste', handleGlobalPaste);
  }, [editing, queueFiles]);

  const removeDraft = useCallback((localId: string) => {
    setDrafts((prev) => {
      const draftToRemove = prev.find((draftRecord) => draftRecord.draft.localId === localId);
      if (draftToRemove) {
        cleanupDraft(draftToRemove);
      }
      return prev.filter((draftRecord) => draftRecord.draft.localId !== localId);
    });
  }, [cleanupDraft]);

  const retryDraft = useCallback((localId: string) => {
    const file = draftsRef.current.find((draftRecord) => draftRecord.draft.localId === localId)?.file;
    if (!file) return;
    void startUpload(localId, file);
  }, [startUpload]);

  const hasUploadingDraft = drafts.some((draftRecord) => draftRecord.draft.status === 'uploading');
  const hasFailedDraft = drafts.some((draftRecord) => draftRecord.draft.status === 'error');
  const hasUploadedAttachment = drafts.some((draftRecord) => draftRecord.draft.status === 'uploaded');
  const canSend = !hasUploadingDraft && !hasFailedDraft && (text.trim().length > 0 || hasUploadedAttachment);

  return (
    <div className={styles.bar}>
      <input
        type="file"
        accept="image/*"
        multiple
        style={{ display: 'none' }}
        ref={fileInputRef}
        onChange={handleFileChange}
      />
      <button
        type="button"
        className={styles.attachBtn}
        aria-label="Attach image"
        onClick={() => fileInputRef.current?.click()}
        disabled={Boolean(editing)}
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

        <UploadPreview
          drafts={drafts.map((draftRecord) => draftRecord.draft)}
          onRemove={removeDraft}
          onRetry={retryDraft}
        />

        <div className={styles.inputRow}>
          <textarea
            ref={textareaRef}
            className={styles.textarea}
            placeholder="Message"
            value={text}
            rows={1}
            onChange={(e) => {
              setText(e.target.value);
              const newLen = e.target.value.length;
              prevTextLenRef.current = newLen;
            }}
          />
          <button type="button" className={styles.stickerBtn} aria-label="Sticker">
            <IonIcon icon={happyOutline} />
          </button>
        </div>
      </div>
      <button
        type="button"
        className={`${styles.sendBtn}${!canSend ? ` ${styles.disabled}` : ''}`}
        onClick={handleSend}
        aria-label="Send message"
        disabled={!canSend}
      >
        <IonIcon icon={paperPlane} />
      </button>
    </div>
  );
}
