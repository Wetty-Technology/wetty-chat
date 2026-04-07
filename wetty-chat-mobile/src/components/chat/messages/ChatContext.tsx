import { createContext, useContext } from 'react';

export interface ChatContextValue {
  chatId: string;
  threadId: string | undefined;
  jumpToMessage: (messageId: string, options?: { silent?: boolean }) => Promise<boolean>;
}

export const ChatContext = createContext<ChatContextValue | null>(null);

export function useChatContext(): ChatContextValue | null {
  return useContext(ChatContext);
}
