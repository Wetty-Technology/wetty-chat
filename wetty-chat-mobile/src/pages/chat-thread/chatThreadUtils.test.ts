import { describe, expect, it, vi } from 'vitest';
import type { MessageResponse } from '@/api/messages';
import type { ComposeUploadedAttachment } from '@/components/chat/compose/MessageComposeBar';
import {
  areAttachmentIdsEqual,
  areMessageListsEquivalent,
  buildOptimisticUploadedAttachments,
  hasLoadedThreadChatMeta,
  isAudioMessage,
  isMessageAtOrAfter,
  parseComparableMessageId,
} from './chatThreadUtils';

function message(id: string, messageType: MessageResponse['messageType'] = 'text'): MessageResponse {
  return {
    id,
    clientGeneratedId: `client-${id}`,
    chatId: '1',
    replyRootId: null,
    message: `message ${id}`,
    messageType,
    sender: { uid: 1, name: 'User', gender: 0 },
    createdAt: new Date(Number.parseInt(id, 10) || 1).toISOString(),
    isEdited: false,
    isDeleted: false,
    hasAttachments: false,
  };
}

describe('chatThreadUtils', () => {
  it('parses only numeric message ids for comparable ordering', () => {
    expect(parseComparableMessageId('123')).toBe(123n);
    expect(parseComparableMessageId('001')).toBe(1n);
    expect(parseComparableMessageId('cg_1')).toBeNull();
    expect(parseComparableMessageId('12a')).toBeNull();
    expect(parseComparableMessageId('')).toBeNull();
  });

  it('compares message ids only when both ids are numeric', () => {
    expect(isMessageAtOrAfter('11', '10')).toBe(true);
    expect(isMessageAtOrAfter('10', '10')).toBe(true);
    expect(isMessageAtOrAfter('9', '10')).toBe(false);
    expect(isMessageAtOrAfter(null, '10')).toBe(false);
    expect(isMessageAtOrAfter('cg_10', '10')).toBe(false);
    expect(isMessageAtOrAfter('10', 'cg_9')).toBe(false);
  });

  it('compares attachment ids by ordered identity', () => {
    expect(areAttachmentIdsEqual(['a', 'b'], ['a', 'b'])).toBe(true);
    expect(areAttachmentIdsEqual(['b', 'a'], ['a', 'b'])).toBe(false);
    expect(areAttachmentIdsEqual(['a'], ['a', 'b'])).toBe(false);
  });

  it('compares message lists by ordered ids only', () => {
    expect(areMessageListsEquivalent([message('1'), message('2')], [message('1'), message('2')])).toBe(true);
    expect(areMessageListsEquivalent([message('1'), message('2')], [message('2'), message('1')])).toBe(false);
    expect(areMessageListsEquivalent([message('1')], [message('1'), message('2')])).toBe(false);
    expect(areMessageListsEquivalent([message('1', 'audio')], [message('1', 'text')])).toBe(true);
  });

  it('detects audio messages', () => {
    expect(isAudioMessage(message('1', 'audio'))).toBe(true);
    expect(isAudioMessage(message('1', 'text'))).toBe(false);
  });

  it('requires both chat name and role metadata to be loaded', () => {
    expect(hasLoadedThreadChatMeta({ name: 'Chat', myRole: 'member' })).toBe(true);
    expect(hasLoadedThreadChatMeta({ name: null, myRole: 'member' })).toBe(false);
    expect(hasLoadedThreadChatMeta({ name: 'Chat' })).toBe(false);
    expect(hasLoadedThreadChatMeta(undefined)).toBe(false);
  });

  it('builds optimistic attachments and revokes generated object urls', () => {
    const createObjectURL = vi.spyOn(URL, 'createObjectURL').mockReturnValueOnce('blob:preview-1');
    const revokeObjectURL = vi.spyOn(URL, 'revokeObjectURL').mockImplementation(() => {});
    const file = new File(['hello'], 'hello.txt', { type: 'text/plain' });
    const upload: ComposeUploadedAttachment = {
      attachmentId: 'att-1',
      file,
      mimeType: 'text/plain',
      size: file.size,
    };

    const result = buildOptimisticUploadedAttachments([upload]);

    expect(createObjectURL).toHaveBeenCalledWith(file);
    expect(result.attachments).toEqual([
      {
        id: 'att-1',
        url: 'blob:preview-1',
        kind: 'text/plain',
        size: file.size,
        fileName: 'hello.txt',
        width: null,
        height: null,
      },
    ]);

    result.revoke();
    expect(revokeObjectURL).toHaveBeenCalledWith('blob:preview-1');
  });
});
