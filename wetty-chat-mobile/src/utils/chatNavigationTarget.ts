export interface ChatMessageNavigationTarget {
  pathname: string;
  hash: string;
}

export interface ChatMessageNavigationTargetParams {
  chatId: string | number;
  messageId?: string | number | null;
  threadRootId?: string | number | null;
}

export function buildChatMessageNavigationTarget({
  chatId,
  messageId,
  threadRootId,
}: ChatMessageNavigationTargetParams): ChatMessageNavigationTarget {
  const encodedChatId = encodeURIComponent(String(chatId));
  const pathname =
    threadRootId != null
      ? `/chats/chat/${encodedChatId}/thread/${encodeURIComponent(String(threadRootId))}`
      : `/chats/chat/${encodedChatId}`;

  return {
    pathname,
    hash: messageId != null ? `#msg=${encodeURIComponent(String(messageId))}` : '',
  };
}

export function buildChatMessageNavigationUrl(params: ChatMessageNavigationTargetParams): string {
  const { pathname, hash } = buildChatMessageNavigationTarget(params);
  return `${pathname}${hash}`;
}
