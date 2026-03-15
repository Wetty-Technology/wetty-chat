import { useRouteMatch } from 'react-router-dom';

export interface ChatRouteState {
  activeChatId: string | undefined;
  threadMatch: { id: string; threadId: string } | null;
  settingsMatch: { id: string } | null;
  membersMatch: { id: string } | null;
  detailsMatch: { id: string } | null;
  isNewChat: boolean;
}

export function useChatRoutes(): ChatRouteState {
  const threadRaw = useRouteMatch<{ id: string; threadId: string }>('/chats/chat/:id/thread/:threadId');
  const settingsRaw = useRouteMatch<{ id: string }>('/chats/chat/:id/settings');
  const membersRaw = useRouteMatch<{ id: string }>('/chats/chat/:id/members');
  const detailsRaw = useRouteMatch<{ id: string }>('/chats/chat/:id/details');
  const chatRaw = useRouteMatch<{ id: string }>('/chats/chat/:id');
  const newRaw = useRouteMatch('/chats/new');

  const threadMatch = threadRaw?.isExact ? threadRaw.params : null;
  const settingsMatch = settingsRaw?.isExact ? settingsRaw.params : null;
  const membersMatch = membersRaw?.isExact ? membersRaw.params : null;
  const detailsMatch = detailsRaw?.isExact ? detailsRaw.params : null;

  const activeChatId =
    threadRaw?.params.id ??
    settingsRaw?.params.id ??
    membersRaw?.params.id ??
    detailsRaw?.params.id ??
    chatRaw?.params.id ??
    undefined;

  return {
    activeChatId,
    threadMatch,
    settingsMatch,
    membersMatch,
    detailsMatch,
    isNewChat: !!newRaw,
  };
}
