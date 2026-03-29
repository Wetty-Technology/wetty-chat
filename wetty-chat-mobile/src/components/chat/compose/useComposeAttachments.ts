import { useCallback, useEffect, useRef, useState } from 'react';
import { t } from '@lingui/core/macro';
import type { Attachment } from '@/api/messages';
import type { UploadPreviewItem } from '../UploadPreview';
import type { ComposeUploadInput, ComposeUploadResult, DraftUploadRecord } from './types';

const isAbortError = (error: unknown) => error instanceof DOMException && error.name === 'AbortError';

const createDraftId = () => {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }

  return `draft_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
};

const getMediaDimensions = (file: File): Promise<{ width?: number; height?: number }> =>
  new Promise((resolve) => {
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
      return;
    }

    if (file.type.startsWith('video/')) {
      const video = document.createElement('video');
      const objectUrl = URL.createObjectURL(file);
      video.onloadedmetadata = () => {
        URL.revokeObjectURL(objectUrl);
        resolve({ width: video.videoWidth, height: video.videoHeight });
      };
      video.onerror = () => {
        URL.revokeObjectURL(objectUrl);
        resolve({});
      };
      video.src = objectUrl;
      return;
    }

    resolve({});
  });

interface UseComposeAttachmentsArgs {
  uploadAttachment: (input: ComposeUploadInput) => Promise<ComposeUploadResult>;
  initialExistingAttachments?: Attachment[];
}

export function useComposeAttachments({ uploadAttachment, initialExistingAttachments = [] }: UseComposeAttachmentsArgs) {
  const [drafts, setDrafts] = useState<DraftUploadRecord[]>([]);
  const [existingAttachments, setExistingAttachments] = useState<Attachment[]>(initialExistingAttachments);
  const draftsRef = useRef<DraftUploadRecord[]>([]);

  const cleanupDraft = useCallback((draftRecord: DraftUploadRecord) => {
    draftRecord.abortController?.abort();
    URL.revokeObjectURL(draftRecord.draft.previewUrl);
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

  useEffect(
    () => () => {
      draftsRef.current.forEach(cleanupDraft);
    },
    [cleanupDraft],
  );

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
        const dimensions = await getMediaDimensions(file);
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
      }
    },
    [uploadAttachment],
  );

  const queueFiles = useCallback(
    (files: File[]) => {
      const mediaFiles = files.filter((file) => file.type.startsWith('image/') || file.type.startsWith('video/'));
      if (mediaFiles.length === 0) return;

      const queuedDrafts: DraftUploadRecord[] = mediaFiles.map((file) => ({
        file,
        draft: {
          localId: createDraftId(),
          kind: file.type.startsWith('image/') ? 'image' : 'video',
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

  useEffect(() => {
    const handleGlobalPaste = (event: ClipboardEvent) => {
      const items = event.clipboardData?.items;
      if (!items) return;

      const files: File[] = [];
      for (let index = 0; index < items.length; index += 1) {
        if (items[index].type.startsWith('image/') || items[index].type.startsWith('video/')) {
          const file = items[index].getAsFile();
          if (file) {
            files.push(file);
          }
        }
      }

      if (files.length > 0) {
        event.preventDefault();
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

  const clearAll = useCallback(() => {
    setExistingAttachments([]);
    clearDrafts(draftsRef.current);
  }, [clearDrafts]);

  const hasUploadingDraft = drafts.some((draftRecord) => draftRecord.draft.status === 'uploading');
  const hasFailedDraft = drafts.some((draftRecord) => draftRecord.draft.status === 'error');

  const previewItems: UploadPreviewItem[] = [
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

  return {
    drafts,
    existingAttachments,
    previewItems,
    hasUploadingDraft,
    hasFailedDraft,
    queueFiles,
    clearAll,
    removeDraft,
    retryDraft,
    removeExistingAttachment,
  };
}
