import { describe, expect, it } from 'vitest';
import { buildChatMessageNavigationTarget, buildChatMessageNavigationUrl } from './chatNavigationTarget';

describe('chat navigation target helpers', () => {
  it('builds direct chat message targets', () => {
    expect(buildChatMessageNavigationTarget({ chatId: '10', messageId: '200' })).toEqual({
      pathname: '/chats/chat/10',
      hash: '#msg=200',
    });
  });

  it('builds thread message targets', () => {
    expect(buildChatMessageNavigationTarget({ chatId: '10', messageId: '201', threadRootId: '150' })).toEqual({
      pathname: '/chats/chat/10/thread/150',
      hash: '#msg=201',
    });
  });

  it('URL encodes route and hash ids', () => {
    expect(
      buildChatMessageNavigationTarget({
        chatId: 'chat 10/20',
        messageId: 'message #200',
        threadRootId: 'thread/150',
      }),
    ).toEqual({
      pathname: '/chats/chat/chat%2010%2F20/thread/thread%2F150',
      hash: '#msg=message%20%23200',
    });
  });

  it('omits hash when no message id is provided', () => {
    expect(buildChatMessageNavigationUrl({ chatId: 'chat 10/20', threadRootId: 'thread/150' })).toBe(
      '/chats/chat/chat%2010%2F20/thread/thread%2F150',
    );
  });
});
