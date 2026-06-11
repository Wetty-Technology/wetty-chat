import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it, vi } from 'vitest';
import { renderMessageContent } from './messageContent';

vi.mock('./InviteLinkInline', () => ({
  InviteLinkInline: ({ url }: { url: string }) => <span data-kind="invite">{url}</span>,
}));

vi.mock('./PermalinkInline', () => ({
  PermalinkInline: ({ url }: { url: string }) => <span data-kind="permalink">{url}</span>,
}));

vi.mock('@/utils/inviteUrl', () => ({
  parseInviteCodeFromUrl: (url: string) => (url.includes('/invite/') ? 'invite-code' : null),
}));

vi.mock('@/utils/permalinkUrl', () => ({
  decodePermalink: () => ({ chatId: 'chat-1', messageId: 'msg-1' }),
}));

describe('renderMessageContent', () => {
  it('renders links and mentions from message text', () => {
    const html = renderToStaticMarkup(
      <>
        {renderMessageContent(
          'Hello @[uid:7] https://example.test/path.',
          [{ uid: 7, username: 'Alice', gender: 0 }],
          7,
          vi.fn(),
        )}
      </>,
    );

    expect(html).toContain('@Alice');
    expect(html).toContain('https://example.test/path');
    expect(html).toContain('href="https://example.test/path"');
  });

  it('uses specialized inline components for invite and permalink URLs', () => {
    const permalinkUrl = `${document.location.origin}/m/abc123`;
    const html = renderToStaticMarkup(
      <>{renderMessageContent(`Join https://example.test/invite/abc or ${permalinkUrl}`, [], null, undefined)}</>,
    );

    expect(html).toContain('data-kind="invite"');
    expect(html).toContain('data-kind="permalink"');
  });
});
