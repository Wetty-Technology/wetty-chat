import { describe, expect, it } from 'vitest';
import type { MessageResponse } from '@/api/messages';
import type { ChatRow } from './types';
import { estimateRowHeight } from './rowHeightEstimator';

type MessageChatRow = Extract<ChatRow, { type: 'message' }>;

function baseMessage(): MessageResponse {
  return {
    clientGeneratedId: 'client-1',
    id: '1',
    chatId: 'chat-1',
    replyRootId: null,
    message: 'hello',
    messageType: 'text',
    sender: { uid: 1, name: 'User', gender: 0 },
    createdAt: '2026-01-01T00:00:00.000Z',
    isEdited: false,
    isDeleted: false,
    hasAttachments: false,
    attachments: [],
  };
}

function messageRow(overrides: Partial<MessageChatRow> = {}): MessageChatRow {
  return {
    type: 'message',
    key: 'msg:1',
    messageId: '1',
    clientGeneratedId: 'client-1',
    showName: true,
    showAvatar: true,
    message: baseMessage(),
    ...overrides,
  };
}

describe('estimateRowHeight', () => {
  it('uses fixed compact estimates for date and deleted rows', () => {
    expect(estimateRowHeight({ type: 'date', key: 'date:1', dateLabel: 'Today' }, '14px')).toBe(32);
    expect(estimateRowHeight(messageRow({ message: { ...baseMessage(), isDeleted: true } }), '14px')).toBe(48);
  });

  it('adds reply affordance height to media-heavy estimates', () => {
    const base = estimateRowHeight(
      messageRow({
        message: {
          ...baseMessage(),
          attachments: [{ id: 'a1', url: 'u', kind: 'image/png', size: 1, fileName: 'a.png' }],
        },
      }),
      '14px',
    );
    const withReply = estimateRowHeight(
      messageRow({
        message: {
          ...baseMessage(),
          attachments: [{ id: 'a1', url: 'u', kind: 'image/png', size: 1, fileName: 'a.png' }],
          replyToMessage: baseMessage(),
        },
      }),
      '14px',
    );

    expect(base).toBe(220);
    expect(withReply).toBe(246);
  });
});
