import {
  getChatBaseFont,
  getChatBubbleMaxWidth,
  getMessageLayoutStats,
  parseChatBubbleContentToRichItems,
} from '@/utils/chatTextMeasure';
import type { ChatRow } from './types';

export function estimateRowHeight(row: ChatRow, chatFontSizeStyle: string): number {
  if (row.type === 'date') return 32;

  const { message } = row;
  if (message.isDeleted) return 48;

  let estimate = message.attachments?.length || message.sticker ? 220 : 76;

  if (message.messageType === 'text' && !message.attachments?.length && !message.sticker && message.message) {
    try {
      const fontSizeNum = parseInt(chatFontSizeStyle) || 14;
      const baseFont = getChatBaseFont(chatFontSizeStyle);
      const items = parseChatBubbleContentToRichItems(message.message, message.mentions, baseFont);
      const maxWidth = getChatBubbleMaxWidth();
      const stats = getMessageLayoutStats(items, maxWidth);
      const lineHeight = fontSizeNum * 1.4;
      estimate = stats.lineCount * lineHeight + 60;
    } catch {
      /* ignore measure errors */
    }
  }

  if (message.replyToMessage) {
    estimate += 26;
  }

  return Math.min(estimate, 3000);
}
