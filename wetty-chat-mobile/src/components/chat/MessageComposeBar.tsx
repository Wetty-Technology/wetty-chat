import { forwardRef, useCallback, useImperativeHandle, useLayoutEffect, useRef, useState } from 'react';
import { IonButton, IonIcon } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { addCircleOutline, micOutline, send } from 'ionicons/icons';
import styles from './compose/MessageComposeBar.module.scss';
import { UploadPreview } from './UploadPreview';
import { ComposeContextBanner } from './compose/ComposeContextBanner';
import { ComposeInput } from './compose/ComposeInput';
import { VoiceRecorderPanel } from './compose/VoiceRecorderPanel';
import { useComposeAttachments } from './compose/useComposeAttachments';
import { useVoiceRecorder } from './compose/useVoiceRecorder';
import type {
  ComposeSendPayload,
  ComposeUploadInput,
  ComposeUploadResult,
  EditingMessage,
  ReplyTo,
} from './compose/types';
export type {
  ComposeSendAudioPayload,
  ComposeSendPayload,
  ComposeSendTextPayload,
  ComposeUploadedAttachment,
  ComposeUploadInput,
  ComposeUploadResult,
  EditingMessage,
  ReplyTo,
} from './compose/types';

interface MessageComposeBarProps {
  onSend: (payload: ComposeSendPayload) => void;
  uploadAttachment: (input: ComposeUploadInput) => Promise<ComposeUploadResult>;
  replyTo?: ReplyTo;
  onCancelReply?: () => void;
  editing?: EditingMessage;
  onCancelEdit?: () => void;
  onRequestEditLastMessage?: () => boolean;
  onFocusChange?: (focused: boolean) => void;
  onError?: (message: string) => void;
}

export interface MessageComposeBarHandle {
  focusInput: () => void;
  blurInput: () => void;
  isFocused: () => boolean;
}

export const MessageComposeBar = forwardRef<MessageComposeBarHandle, MessageComposeBarProps>(function MessageComposeBar(
  props,
  ref,
) {
  const composeKey = props.editing?.messageId ?? '__compose__';

  return <MessageComposeBarInner key={composeKey} {...props} ref={ref} />;
});

const MessageComposeBarInner = forwardRef<MessageComposeBarHandle, MessageComposeBarProps>(function MessageComposeBarInner(
  {
    onSend,
    uploadAttachment,
    replyTo,
    onCancelReply,
    editing,
    onCancelEdit,
    onRequestEditLastMessage,
    onFocusChange,
    onError,
  }: MessageComposeBarProps,
  ref,
) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [text, setText] = useState(() => editing?.text ?? '');

  useImperativeHandle(
    ref,
    () => ({
      focusInput: () => textareaRef.current?.focus(),
      blurInput: () => textareaRef.current?.blur(),
      isFocused: () => document.activeElement === textareaRef.current,
    }),
    [],
  );

  const resizeTextarea = useCallback(() => {
    const ta = textareaRef.current;
    if (!ta) return;

    ta.style.height = 'auto';
    ta.style.height = `${Math.min(ta.scrollHeight, 120)}px`;
  }, []);

  const {
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
  } = useComposeAttachments({ uploadAttachment, initialExistingAttachments: editing?.attachments ?? [] });

  useLayoutEffect(() => {
    resizeTextarea();
  }, [resizeTextarea, text]);

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
      kind: 'text',
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
    clearAll();
    const ta = textareaRef.current;
    if (ta) ta.style.height = 'auto';
  }, [clearAll, drafts, existingAttachments, onSend, text]);

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
  const canStartVoiceBase = trimmedText.length === 0 && !hasAttachment && !editing && !hasUploadingDraft && !hasFailedDraft;
  const canRequestRecentEdit = !editing && !replyTo && text.length === 0 && !hasAttachment && drafts.length === 0;

  const { voiceRecorder, voiceActive, handleVoicePointerDown, finishVoiceRecording } = useVoiceRecorder({
    uploadAttachment,
    onSend,
    onError,
    canStartVoice: canStartVoiceBase,
    onBeforeStart: () => {
      textareaRef.current?.blur();
    },
  });
  const canStartVoice = canStartVoiceBase && !voiceActive;

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files ?? []);
    queueFiles(files);
    e.target.value = '';
  };

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
        disabled={voiceActive}
      >
        <IonIcon icon={addCircleOutline} />
      </button>
      <div className={styles.inputWrapper}>
        <ComposeContextBanner editing={editing} replyTo={replyTo} onCancelEdit={onCancelEdit} onCancelReply={onCancelReply} />

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

        {voiceRecorder ? (
          <VoiceRecorderPanel voiceRecorder={voiceRecorder} onFinish={finishVoiceRecording} />
        ) : (
          <ComposeInput
            textareaRef={textareaRef}
            text={text}
            onTextChange={setText}
            onFocusChange={onFocusChange}
            onSubmit={handleSend}
            canRequestRecentEdit={canRequestRecentEdit}
            onRequestEditLastMessage={onRequestEditLastMessage}
            editing={editing}
            isUnchangedEdit={isUnchangedEdit}
            onCancelEdit={onCancelEdit}
          />
        )}
      </div>
      {canStartVoice || voiceActive ? (
        <IonButton
          fill="solid"
          color="primary"
          className={`${styles.sendBtn} ${voiceActive ? styles.recordingBtn : ''}`}
          onPointerDown={handleVoicePointerDown}
          onClick={(event) => event.preventDefault()}
          aria-label={t`Record voice`}
          disabled={voiceRecorder?.phase === 'uploading'}
        >
          <IonIcon slot="icon-only" icon={micOutline} />
        </IonButton>
      ) : (
        <IonButton
          fill="solid"
          color="primary"
          className={`${styles.sendBtn}${!canSend ? ` ${styles.disabled}` : ''}`}
          onClick={handleSend}
          aria-label={t`Send message`}
          disabled={!canSend}
        >
          <IonIcon slot="icon-only" icon={send} className={styles.moveRight} />
        </IonButton>
      )}
    </div>
  );
});
