import type { MessageResponse } from '@/api/messages';

/**
 * Message-type discriminators shared across the chat layer (row grouping in
 * useChatRows, bubble-kind dispatch in ChatMessageRow, etc.). Centralised so a
 * new message kind has exactly one place to update before rippling out.
 *
 * Note: `messageType` is also compared inline in render-time modules
 * (ChatBubble, MessageOverlay, messagePreview, …). Those comparisons are
 * local to a single rendering path and are migrated separately; grouping and
 * bubble-kind decisions flow through these helpers.
 */
export function isSystemMessage(message: MessageResponse): boolean {
  return message.messageType === 'system';
}

export function isInviteMessage(message: MessageResponse): boolean {
  return message.messageType === 'invite';
}

export function isStickerMessage(message: MessageResponse): boolean {
  return message.messageType === 'sticker';
}
