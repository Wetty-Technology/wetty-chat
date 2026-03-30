import { useSelector } from 'react-redux';
import type { GroupRole } from '@/api/group';
import type { RootState } from '@/store';
import { selectChatMeta } from '@/store/chatsSlice';

interface UseChatRoleResult {
  role: GroupRole | null;
  loading: boolean;
}

export function useChatRole(chatId: string): UseChatRoleResult {
  const meta = useSelector((state: RootState) => selectChatMeta(state, chatId));

  return {
    role: meta?.myRole ?? null,
    loading: meta?.myRole === undefined,
  };
}
