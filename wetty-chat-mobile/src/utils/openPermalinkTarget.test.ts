import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { getMessage } from '@/api/messages';
import { navigateToNotificationTarget } from '@/utils/notificationTargetNavigator';
import { openPermalinkTarget } from './openPermalinkTarget';

vi.mock('@/api/messages', () => ({
  getMessage: vi.fn(),
}));

vi.mock('@/utils/notificationTargetNavigator', () => ({
  navigateToNotificationTarget: vi.fn(),
}));

describe('openPermalinkTarget', () => {
  let debugSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    debugSpy = vi.spyOn(console, 'debug').mockImplementation(() => {});
    vi.clearAllMocks();
  });

  afterEach(() => {
    debugSpy.mockRestore();
  });

  it('navigates to a direct message permalink target', async () => {
    vi.mocked(getMessage).mockResolvedValueOnce({
      data: { replyRootId: null },
    } as Awaited<ReturnType<typeof getMessage>>);

    await openPermalinkTarget({ chatId: '10', messageId: '200' });

    expect(navigateToNotificationTarget).toHaveBeenCalledWith('/chats/chat/10#msg=200', {
      preserveCurrentEntry: false,
    });
  });

  it('uses the resolved reply root when navigating to a thread permalink target', async () => {
    vi.mocked(getMessage).mockResolvedValueOnce({
      data: { replyRootId: '150' },
    } as Awaited<ReturnType<typeof getMessage>>);

    await openPermalinkTarget({
      chatId: '10',
      messageId: '201',
      preserveCurrentEntry: true,
    });

    expect(navigateToNotificationTarget).toHaveBeenCalledWith('/chats/chat/10/thread/150#msg=201', {
      preserveCurrentEntry: true,
    });
  });
});
