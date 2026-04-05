import { getMessage } from '@/api/messages';
import { navigateToNotificationTarget } from '@/utils/notificationTargetNavigator';

interface OpenPermalinkTargetParams {
  chatId: string;
  messageId: string;
  preserveCurrentEntry?: boolean;
}

export async function openPermalinkTarget({
  chatId,
  messageId,
  preserveCurrentEntry = false,
}: OpenPermalinkTargetParams): Promise<void> {
  console.debug('[permalink] resolving target', { chatId, messageId, preserveCurrentEntry });

  const res = await getMessage(chatId, messageId);
  const msg = res.data;
  const threadRootId = msg.replyRootId;
  const basePath = threadRootId
    ? `/chats/chat/${encodeURIComponent(chatId)}/thread/${threadRootId}`
    : `/chats/chat/${encodeURIComponent(chatId)}`;
  const target = `${basePath}#msg=${messageId}`;

  console.debug('[permalink] navigating to resolved target', {
    chatId,
    messageId,
    threadRootId,
    target,
    preserveCurrentEntry,
  });

  navigateToNotificationTarget(target, { preserveCurrentEntry });
}
