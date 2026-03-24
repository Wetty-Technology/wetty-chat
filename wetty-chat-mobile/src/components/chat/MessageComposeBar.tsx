import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { IonButton, IonIcon } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { addCircleOutline, closeCircle, happyOutline, send } from 'ionicons/icons';
import styles from './MessageComposeBar.module.scss';
import { type ImageUploadDraft, UploadPreview } from './UploadPreview';
import type { Attachment } from '@/api/messages';
import { getMessagePreviewText } from './messagePreview';
import { FeatureGate } from '../FeatureGate';

interface ReplyTo {
  messageId: string;
  username: string;
  text?: string | null;
  attachments?: Attachment[];
  isDeleted?: boolean;
}

export interface EditingMessage {
  messageId: string;
  text: string;
  attachments?: Attachment[];
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

export interface ComposeUploadedAttachment {
  attachmentId: string;
  file: File;
  mimeType: string;
  size: number;
  width?: number;
  height?: number;
}

export interface ComposeSendPayload {
  text: string;
  attachmentIds: string[];
  existingAttachments: Attachment[];
  uploadedAttachments: ComposeUploadedAttachment[];
}

interface DraftUploadRecord {
  draft: ImageUploadDraft;
  file: File;
  abortController?: AbortController;
}

interface MessageComposeBarProps {
  onSend: (payload: ComposeSendPayload) => void;
  uploadAttachment: (input: ComposeUploadInput) => Promise<ComposeUploadResult>;
  replyTo?: ReplyTo;
  onCancelReply?: () => void;
  editing?: EditingMessage;
  onCancelEdit?: () => void;
  onRequestEditLastMessage?: () => boolean;
}

const isAbortError = (error: unknown) => error instanceof DOMException && error.name === 'AbortError';

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
  onRequestEditLastMessage,
}: MessageComposeBarProps) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const draftsRef = useRef<DraftUploadRecord[]>([]);
  const previousEditingMessageIdRef = useRef<string | null>(null);
  const [text, setText] = useState('');
  const prevTextLenRef = useRef(0);
  const [drafts, setDrafts] = useState<DraftUploadRecord[]>([]);
  const [existingAttachments, setExistingAttachments] = useState<Attachment[]>([]);

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

  const clearDrafts = useCallback(
    (currentDrafts: DraftUploadRecord[]) => {
      currentDrafts.forEach(cleanupDraft);
      setDrafts([]);
    },
    [cleanupDraft],
  );

  useEffect(() => {
    draftsRef.current = drafts;
  }, [drafts]);

  useEffect(() => {
    const editingMessageId = editing?.messageId ?? null;
    const previousEditingMessageId = previousEditingMessageIdRef.current;

    if (editing && editingMessageId !== previousEditingMessageId) {
      setText(editing.text);
      prevTextLenRef.current = editing.text.length;
      setExistingAttachments(editing.attachments ?? []);
      setDrafts((prev) => {
        prev.forEach(cleanupDraft);
        return [];
      });
    } else if (!editing && previousEditingMessageId != null) {
      setText('');
      prevTextLenRef.current = 0;
      setExistingAttachments([]);
      setDrafts((prev) => {
        prev.forEach(cleanupDraft);
        return [];
      });
      const ta = textareaRef.current;
      if (ta) ta.style.height = 'auto';
    }
    previousEditingMessageIdRef.current = editingMessageId;
  }, [cleanupDraft, editing]);

  useLayoutEffect(() => {
    resizeTextarea();
  }, [resizeTextarea, text]);

  useEffect(
    () => () => {
      draftsRef.current.forEach(cleanupDraft);
    },
    [cleanupDraft],
  );

  const getImageDimensions = (file: File): Promise<{ width?: number; height?: number }> => {
    return new Promise((resolve) => {
      if (file.type.startsWith('image/')) {
        const img = new Image();
        const objectUrl = URL.createObjectURL(file);
        img.onload = () => {
          URL.revokeObjectURL(objectUrl);
          resolve({ width: img.width, height: img.height });
        };
        img.onerror = () => {
          URL.revokeObjectURL(objectUrl);
          resolve({});
        };
        img.src = objectUrl;
      }else if (file.type.startsWith("video/")) {
        const video = document.createElement("video");
        const url = URL.createObjectURL(file);
        video.onloadedmetadata = () => {
          URL.revokeObjectURL(url);
          resolve({ width: video.videoWidth, height: video.videoHeight });
        };
        video.onerror = () => {
          URL.revokeObjectURL(url);
          resolve({});
        };
        video.src = url;
      } else  {
        resolve({});
      }
    });
  };

  const startUpload = useCallback(
    async (localId: string, file: File) => {
      const abortController = new AbortController();

      setDrafts((prev) =>
        prev.map((draftRecord) =>
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
            : draftRecord,
        ),
      );

      try {
        const dimensions = await getImageDimensions(file);
        setDrafts((prev) =>
          prev.map((draftRecord) =>
            draftRecord.draft.localId === localId
              ? {
                  ...draftRecord,
                  draft: {
                    ...draftRecord.draft,
                    width: dimensions.width,
                    height: dimensions.height,
                  },
                }
              : draftRecord,
          ),
        );
        const result = await uploadAttachment({
          file,
          dimensions,
          signal: abortController.signal,
          onProgress: (progress) => {
            setDrafts((prev) =>
              prev.map((draftRecord) =>
                draftRecord.draft.localId === localId
                  ? {
                      ...draftRecord,
                      draft: {
                        ...draftRecord.draft,
                        progress,
                      },
                    }
                  : draftRecord,
              ),
            );
          },
        });

        setDrafts((prev) =>
          prev.map((draftRecord) =>
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
              : draftRecord,
          ),
        );
      } catch (error) {
        if (isAbortError(error) || abortController.signal.aborted) {
          return;
        }

        console.error('Failed to upload attachment:', error);
        setDrafts((prev) =>
          prev.map((draftRecord) =>
            draftRecord.draft.localId === localId
              ? {
                  ...draftRecord,
                  abortController: undefined,
                  draft: {
                    ...draftRecord.draft,
                    status: 'error',
                    progress: 0,
                    attachmentId: undefined,
                    errorMessage: t`Upload failed`,
                  },
                }
              : draftRecord,
          ),
        );
      } finally {
        if (fileInputRef.current) fileInputRef.current.value = '';
      }
    },
    [uploadAttachment],
  );

  const queueFiles = useCallback(
    (files: File[]) => {
      const mediaFiles = files.filter((file) => file.type.startsWith('image/') || file.type.startsWith('video/'));
      if (mediaFiles.length === 0) return;

      const queuedDrafts = mediaFiles.map((file) => ({
        file,
        draft: {
          localId: createDraftId(),
          kind: file.type.startsWith('image/') ? 'image' : 'video' as 'image' | 'video',
        name: file.name,
        previewUrl: URL.createObjectURL(file),
        mimeType: file.type || 'application/octet-stream',
        size: file.size,
        progress: 0,
        status: 'uploading' as const,
      },
    }));

      setDrafts((prev) => [...prev, ...queuedDrafts]);
      queuedDrafts.forEach(({ draft, file }) => {
        void startUpload(draft.localId, file);
      });
    },
    [startUpload],
  );

  const handleSend = useCallback(() => {
    const trimmed = text.trim();
    const uploadedDrafts = drafts.filter(
      (draftRecord) => draftRecord.draft.status === 'uploaded' && Boolean(draftRecord.draft.attachmentId),
    );
    const attachmentIds = [
      ...existingAttachments.map((attachment) => attachment.id),
      ...uploadedDrafts.map((draftRecord) => draftRecord.draft.attachmentId!),
    ];

    if (!trimmed && attachmentIds.length === 0) return;

    onSend({
      text: trimmed,
      attachmentIds,
      existingAttachments,
      uploadedAttachments: uploadedDrafts.map((draftRecord) => ({
        attachmentId: draftRecord.draft.attachmentId!,
        file: draftRecord.file,
        mimeType: draftRecord.draft.mimeType,
        size: draftRecord.draft.size,
        width: draftRecord.draft.width,
        height: draftRecord.draft.height,
      })),
    });
    setText('');
    setExistingAttachments([]);
    clearDrafts(drafts);
    const ta = textareaRef.current;
    if (ta) ta.style.height = 'auto';
  }, [clearDrafts, drafts, existingAttachments, onSend, text]);

  const handleSendRef = useRef(handleSend);
  useEffect(() => {
    handleSendRef.current = handleSend;
  }, [handleSend]);

  const hasUploadingDraft = drafts.some((draftRecord) => draftRecord.draft.status === 'uploading');
  const hasFailedDraft = drafts.some((draftRecord) => draftRecord.draft.status === 'error');
  const uploadedDrafts = drafts.filter((draftRecord) => draftRecord.draft.status === 'uploaded');
  const currentAttachmentIds = [
    ...existingAttachments.map((attachment) => attachment.id),
    ...uploadedDrafts
      .map((draftRecord) => draftRecord.draft.attachmentId)
      .filter((attachmentId): attachmentId is string => Boolean(attachmentId)),
  ];
  const hasAttachment = currentAttachmentIds.length > 0;
  const trimmedText = text.trim();
  const originalEditText = editing?.text.trim() ?? '';
  const originalAttachmentIds = editing?.attachments?.map((attachment) => attachment.id) ?? [];
  const isUnchangedEdit =
    editing != null &&
    trimmedText === originalEditText &&
    currentAttachmentIds.length === originalAttachmentIds.length &&
    currentAttachmentIds.every((attachmentId, index) => attachmentId === originalAttachmentIds[index]);
  const canSend =
    !hasUploadingDraft && !hasFailedDraft && (trimmedText.length > 0 || hasAttachment) && !isUnchangedEdit;
  const canRequestRecentEdit = !editing && !replyTo && text.length === 0 && !hasAttachment && drafts.length === 0;

  useEffect(() => {
    const textarea = textareaRef.current;
    if (!textarea) return;
    textarea.setAttribute('enterkeyhint', 'send');
    const onKeyDown = (e: KeyboardEvent) => {
      const isImeConfirm = e.isComposing || e.keyCode === 229 || e.which === 229;
      if (e.key === 'Enter' && !e.shiftKey && !isImeConfirm) {
        e.preventDefault();
        handleSendRef.current();
        return;
      }

      if (e.key === 'ArrowUp' && canRequestRecentEdit) {
        const didStartEdit = onRequestEditLastMessage?.() ?? false;
        if (didStartEdit) {
          e.preventDefault();
        }
        return;
      }

      if (e.key === 'Escape' && editing && isUnchangedEdit) {
        e.preventDefault();
        onCancelEdit?.();
      }
    };
    textarea.addEventListener('keydown', onKeyDown);
    return () => textarea.removeEventListener('keydown', onKeyDown);
  }, [canRequestRecentEdit, editing, isUnchangedEdit, onCancelEdit, onRequestEditLastMessage]);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files ?? []);
    queueFiles(files);
  };

  useEffect(() => {
    const handleGlobalPaste = (e: ClipboardEvent) => {
      const items = e.clipboardData?.items;
      if (!items) return;

      const files: File[] = [];

      for (let i = 0; i < items.length; i++) {
        if (items[i].type.startsWith('image/') || items[i].type.startsWith('video/')) {
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
  }, [queueFiles]);

  const removeDraft = useCallback(
    (localId: string) => {
      setDrafts((prev) => {
        const draftToRemove = prev.find((draftRecord) => draftRecord.draft.localId === localId);
        if (draftToRemove) {
          cleanupDraft(draftToRemove);
        }
        return prev.filter((draftRecord) => draftRecord.draft.localId !== localId);
      });
    },
    [cleanupDraft],
  );

  const retryDraft = useCallback(
    (localId: string) => {
      const file = draftsRef.current.find((draftRecord) => draftRecord.draft.localId === localId)?.file;
      if (!file) return;
      void startUpload(localId, file);
    },
    [startUpload],
  );

  const removeExistingAttachment = useCallback((localId: string) => {
    const attachmentId = localId.replace(/^existing-/, '');
    setExistingAttachments((prev) => prev.filter((attachment) => attachment.id !== attachmentId));
  }, []);
  const previewItems = [
    ...existingAttachments.map((attachment) => ({
      itemType: 'existing' as const,
      localId: `existing-${attachment.id}`,
      attachmentId: attachment.id,
      kind: attachment.kind,
      name: attachment.file_name,
      previewUrl: attachment.kind.startsWith('image/') ? attachment.url : undefined,
    })),
    ...drafts.map((draftRecord) => ({
      itemType: 'draft' as const,
      ...draftRecord.draft,
    })),
  ];

  return (
    <div className={styles.bar}>
      <input
        type="file"
        accept="image/*,video/*"
        multiple
        style={{ display: 'none' }}
        ref={fileInputRef}
        onChange={handleFileChange}
      />
      <button
        type="button"
        className={styles.attachBtn}
        aria-label={t`Attach image`}
        onClick={() => fileInputRef.current?.click()}
      >
        <IonIcon icon={addCircleOutline} />
      </button>
      <div className={styles.inputWrapper}>
        {editing ? (
          <div className={styles.replyPreview}>
            <div className={styles.replyText}>
              <span className={styles.replyUsername}>{t`Edit message`}</span>
              <span className={styles.replySnippet}>{editing.text}</span>
            </div>
            <button type="button" className={styles.replyClose} aria-label={t`Cancel edit`} onClick={onCancelEdit}>
              <IonIcon icon={closeCircle} />
            </button>
          </div>
        ) : replyTo ? (
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
        ) : null}

        <UploadPreview
          items={previewItems}
          onRemove={(localId) => {
            if (localId.startsWith('existing-')) {
              removeExistingAttachment(localId);
              return;
            }
            removeDraft(localId);
          }}
          onRetry={retryDraft}
        />

        <div className={styles.inputRow}>
          <textarea
            id="messageCompose"
            ref={textareaRef}
            className={styles.textarea}
            placeholder={t`Message`}
            value={text}
            rows={1}
            onChange={(e) => {
              setText(e.target.value);
              const newLen = e.target.value.length;
              prevTextLenRef.current = newLen;
            }}
          />
          <FeatureGate>
            <button type="button" className={styles.stickerBtn} aria-label={t`Sticker`}>
              <IonIcon icon={happyOutline} />
            </button>
          </FeatureGate>
          <IonButton
            fill="solid"
            color="primary"
            size="small"
            className={`${styles.sendBtn}${!canSend ? ` ${styles.disabled}` : ''}`}
            onClick={handleSend}
            aria-label={t`Send message`}
            disabled={!canSend}
          >
            <IonIcon slot="icon-only" icon={send} />
          </IonButton>
        </div>
      </div>
    </div>
  );
}
