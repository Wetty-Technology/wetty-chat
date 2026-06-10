import { describe, expect, it } from 'vitest';
import {
  buildNotificationChatTarget,
  buildNotificationThreadTarget,
  resolveNotificationTarget,
} from './notificationNavigation';

describe('notification navigation helpers', () => {
  it('rejects invalid chat ids', () => {
    expect(buildNotificationChatTarget(null)).toBeNull();
    expect(buildNotificationChatTarget('   ')).toBeNull();
  });

  it('trims ids before building thread targets', () => {
    expect(buildNotificationThreadTarget(' 10 ', ' 150 ')).toBe('/chats/chat/10/thread/150');
  });

  it('prefers resolved thread targets over raw notification targets', () => {
    expect(
      resolveNotificationTarget({
        chatId: '10',
        threadRootId: '150',
        target: '/settings',
      }),
    ).toBe('/chats/chat/10/thread/150');
  });
});
