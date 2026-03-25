import { useMemo } from 'react';
import type { MessageResponse } from '@/api/messages';
import type { ChatRow } from './virtualScroll/types';

function formatDateKey(iso: string): string {
  return iso.slice(0, 10); // YYYY-MM-DD
}

function isSameDate(a: string, b: string): boolean {
  return formatDateKey(a) === formatDateKey(b);
}

export function useChatRows(messages: MessageResponse[], formatDateSeparator: (iso: string) => string): ChatRow[] {
  return useMemo(() => {
    const rows: ChatRow[] = [];
    let prevSenderUid: number | string | null = null;

    for (let i = 0; i < messages.length; i++) {
      const msg = messages[i];
      const prevMsg = messages[i - 1];
      const nextMsg = messages[i + 1];

      // Date separator: always shown on the first message and on date boundaries.
      // The first message uses a distinct key prefix so it doesn't collide with a
      // "real" date boundary separator that may appear when older messages are prepended.
      const isDateBoundary = prevMsg && !isSameDate(msg.created_at, prevMsg.created_at);
      const isFirstMessage = i === 0;
      if (isFirstMessage || isDateBoundary) {
        rows.push({
          type: 'date',
          key:
            isFirstMessage && !isDateBoundary
              ? `datefirst:${formatDateKey(msg.created_at)}`
              : `date:${formatDateKey(msg.created_at)}`,
          dateLabel: formatDateSeparator(msg.created_at),
        });
        prevSenderUid = null;
      }

      // Grouping
      const hasDateSeparator = isFirstMessage || isDateBoundary;
      const showName = msg.sender.uid !== prevSenderUid || hasDateSeparator;
      const isLastInGroup =
        !nextMsg || nextMsg.sender.uid !== msg.sender.uid || !isSameDate(msg.created_at, nextMsg.created_at);

      rows.push({
        type: 'message',
        key: `msg:${msg.client_generated_id || msg.id}`,
        message: msg,
        showName,
        showAvatar: isLastInGroup,
      });

      prevSenderUid = msg.sender.uid;
    }

    return rows;
  }, [messages, formatDateSeparator]);
}
