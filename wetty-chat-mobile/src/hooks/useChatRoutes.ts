import { useRouteMatch } from 'react-router-dom';

export interface ChatRouteState {
  activeChatId: string | undefined;
  threadMatch: { id: string; threadId: string } | null;
  groupInfoMatch: { id: string } | null;
  membersMatch: { id: string } | null;
  invitesMatch: { id: string } | null;
  isNewChat: boolean;
}

export function useChatRoutes(): ChatRouteState {
  const threadRaw = useRouteMatch<{ id: string; threadId: string }>('/chats/chat/:id/thread/:threadId');
  const groupInfoRaw = useRouteMatch<{ id: string }>('/chats/chat/:id/group-info');
  const membersRaw = useRouteMatch<{ id: string }>('/chats/chat/:id/members');
  const invitesRaw = useRouteMatch<{ id: string }>('/chats/chat/:id/invites');
  const chatRaw = useRouteMatch<{ id: string }>('/chats/chat/:id');
  const newRaw = useRouteMatch('/chats/new');

  const threadMatch = threadRaw?.isExact ? threadRaw.params : null;
  const groupInfoMatch = groupInfoRaw?.isExact ? groupInfoRaw.params : null;
  const membersMatch = membersRaw?.isExact ? membersRaw.params : null;
  const invitesMatch = invitesRaw?.isExact ? invitesRaw.params : null;

  const activeChatId =
    threadRaw?.params.id ??
    groupInfoRaw?.params.id ??
    membersRaw?.params.id ??
    invitesRaw?.params.id ??
    chatRaw?.params.id ??
    undefined;

  return {
    activeChatId,
    threadMatch,
    groupInfoMatch,
    membersMatch,
    invitesMatch,
    isNewChat: !!newRaw,
  };
}
