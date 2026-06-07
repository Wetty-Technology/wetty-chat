import type { Attachment, MessageResponse } from '@/api/messages';
import type { ComposeUploadedAttachment } from '@/components/chat/compose/MessageComposeBar';
import type { GroupRole } from '@/api/group';

export function generateClientId(): string {
  return `cg_${Date.now()}_${Math.random().toString(36).slice(2)}`;
}

export function parseComparableMessageId(messageId: string): bigint | null {
  if (!/^\d+$/.test(messageId)) return null;
  return BigInt(messageId);
}

export function isMessageAtOrAfter(messageId: string | null, targetMessageId: string): boolean {
  if (!messageId) return false;
  const comparableId = parseComparableMessageId(messageId);
  const targetComparableId = parseComparableMessageId(targetMessageId);
  if (comparableId == null || targetComparableId == null) return false;
  return comparableId >= targetComparableId;
}

export function areAttachmentIdsEqual(left: string[], right: string[]): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

export function areMessageListsEquivalent(left: MessageResponse[], right: MessageResponse[]): boolean {
  return (
    left.length === right.length &&
    left.every((message, index) => {
      const candidate = right[index];
      return candidate != null && message.id === candidate.id;
    })
  );
}

export function isAudioMessage(message: MessageResponse): boolean {
  return message.messageType === 'audio';
}

export function buildOptimisticUploadedAttachments(uploadedAttachments: ComposeUploadedAttachment[]): {
  attachments: Attachment[];
  revoke: () => void;
} {
  const previewUrls: string[] = [];
  const attachments = uploadedAttachments.map((attachment) => {
    const previewUrl = URL.createObjectURL(attachment.file);
    previewUrls.push(previewUrl);

    return {
      id: attachment.attachmentId,
      url: previewUrl,
      kind: attachment.mimeType,
      size: attachment.size,
      fileName: attachment.file.name,
      width: attachment.width ?? null,
      height: attachment.height ?? null,
    };
  });

  return {
    attachments,
    revoke: () => {
      previewUrls.forEach((previewUrl) => URL.revokeObjectURL(previewUrl));
    },
  };
}

export function hasLoadedThreadChatMeta(cachedMeta?: { name?: string | null; myRole?: GroupRole | null }) {
  return cachedMeta?.name != null && cachedMeta.myRole !== undefined;
}
