import { t } from '@lingui/core/macro';
import type { Attachment } from '@/api/messages';

interface PreviewMessage {
  message?: string | null;
  attachments?: Attachment[];
  isDeleted?: boolean;
}

export function getMessagePreviewText({ message, attachments, isDeleted }: PreviewMessage): string {
  if (isDeleted) {
    return t`[Deleted]`;
  }

  if (message?.trim()) {
    return message;
  }

  if (attachments?.some((attachment) => attachment.kind.startsWith('image/'))) {
    return t`[Image]`;
  }

  if (attachments?.some((attachment) => attachment.kind.startsWith('video/'))) {
    return t`[Video]`;
  }

  if (attachments && attachments.length > 0) {
    return t`[Attachment]`;
  }

  return '';
}
