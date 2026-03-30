import { t } from '@lingui/core/macro';
import type { Attachment } from '@/api/messages';

export interface PreviewMessage {
  message?: string | null;
  text?: string | null;
  messageType?: string | null;
  attachments?: Attachment[];
  firstAttachmentKind?: string | null;
  isDeleted?: boolean;
}

function normalizePreviewMessage({
  message,
  text,
  messageType,
  attachments,
  firstAttachmentKind,
  isDeleted,
}: PreviewMessage) {
  return {
    message: message ?? text,
    messageType: messageType,
    attachments,
    firstAttachmentKind: firstAttachmentKind,
    isDeleted,
  };
}

export function getMessagePreviewText(preview: PreviewMessage): string {
  const { message, messageType, attachments, firstAttachmentKind, isDeleted } = normalizePreviewMessage(preview);

  if (isDeleted) {
    return t`[Deleted]`;
  }

  if (messageType === 'invite') {
    return t`[Invite]`;
  }

  if (messageType === 'sticker') {
    return t`[Sticker]`;
  }

  if (messageType === 'audio') {
    return t`[Voice message]`;
  }

  if (message?.trim()) {
    return message;
  }

  if (attachments?.some((attachment) => attachment.kind.startsWith('audio/'))) {
    return t`[Voice message]`;
  }

  if (firstAttachmentKind?.startsWith('audio/')) {
    return t`[Voice message]`;
  }

  if (attachments?.some((attachment) => attachment.kind.startsWith('image/'))) {
    return t`[Image]`;
  }

  if (firstAttachmentKind?.startsWith('image/')) {
    return t`[Image]`;
  }

  if (attachments?.some((attachment) => attachment.kind.startsWith('video/'))) {
    return t`[Video]`;
  }

  if (firstAttachmentKind?.startsWith('video/')) {
    return t`[Video]`;
  }

  if (attachments && attachments.length > 0) {
    return t`[Attachment]`;
  }

  if (firstAttachmentKind) {
    return t`[Attachment]`;
  }

  return '';
}
