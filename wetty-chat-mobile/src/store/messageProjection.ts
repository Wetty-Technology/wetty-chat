import type { MessageResponse } from '@/api/messages';

interface MessageWindowLike {
  messages: MessageResponse[];
}

export function isOptimisticMessageId(messageId: string | null | undefined): boolean {
  return typeof messageId === 'string' && messageId.startsWith('cg_');
}

export function compareMessageOrder(
  a: MessageResponse | null | undefined,
  b: MessageResponse | null | undefined,
): number {
  if (!a && !b) return 0;
  if (!a) return -1;
  if (!b) return 1;

  const aOptimistic = isOptimisticMessageId(a.id);
  const bOptimistic = isOptimisticMessageId(b.id);

  if (!aOptimistic && !bOptimistic) {
    try {
      const aId = BigInt(a.id);
      const bId = BigInt(b.id);
      if (aId > bId) return 1;
      if (aId < bId) return -1;
      return 0;
    } catch {
      // Fall back to timestamps when ids are not comparable.
    }
  }

  const aTs = a.created_at ? new Date(a.created_at).getTime() : 0;
  const bTs = b.created_at ? new Date(b.created_at).getTime() : 0;
  if (aTs > bTs) return 1;
  if (aTs < bTs) return -1;
  return 0;
}

export function isSameMessage(a: MessageResponse | null | undefined, b: MessageResponse | null | undefined): boolean {
  if (!a || !b) return false;
  if (a.id === b.id) return true;
  return !!a.client_generated_id && a.client_generated_id === b.client_generated_id;
}

export function isEligibleRootPreviewMessage(message: MessageResponse, excludeMessageId?: string): boolean {
  if (message.reply_root_id != null) return false;
  if (message.is_deleted) return false;
  if (excludeMessageId && message.id === excludeMessageId) return false;
  return true;
}

export function findLatestEligibleRootMessage(
  windows: MessageWindowLike[] | undefined,
  excludeMessageId?: string,
): MessageResponse | null {
  if (!windows) return null;

  let latest: MessageResponse | null = null;
  for (const window of windows) {
    for (const message of window.messages) {
      if (!isEligibleRootPreviewMessage(message, excludeMessageId)) continue;
      if (!latest || compareMessageOrder(message, latest) > 0) {
        latest = message;
      }
    }
  }
  return latest;
}
