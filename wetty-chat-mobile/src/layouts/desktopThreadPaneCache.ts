export interface CachedThreadPane {
  key: string;
  chatId: string;
  threadId: string;
}

export function buildThreadPaneKey(chatId: string, threadId: string): string {
  return `${chatId}:thread:${threadId}`;
}

export function createCachedThreadPane(chatId: string, threadId: string): CachedThreadPane {
  return {
    key: buildThreadPaneKey(chatId, threadId),
    chatId,
    threadId,
  };
}

export function updateCachedThreadPanes(
  current: CachedThreadPane[],
  activePane: CachedThreadPane | null,
  maxEntries: number,
): CachedThreadPane[] {
  if (maxEntries <= 0) {
    return [];
  }

  if (!activePane) {
    return current.slice(0, maxEntries);
  }

  const activeIndex = current.findIndex((pane) => pane.key === activePane.key);
  if (activeIndex >= 0) {
    const next = current.slice(0, maxEntries);
    next[activeIndex] = activePane;
    return next;
  }

  return [...current.slice(Math.max(0, current.length - maxEntries + 1)), activePane];
}

export function areCachedThreadPanesEqual(left: CachedThreadPane[], right: CachedThreadPane[]): boolean {
  return (
    left.length === right.length &&
    left.every((pane, index) => {
      const candidate = right[index];
      return candidate?.key === pane.key && candidate.chatId === pane.chatId && candidate.threadId === pane.threadId;
    })
  );
}
