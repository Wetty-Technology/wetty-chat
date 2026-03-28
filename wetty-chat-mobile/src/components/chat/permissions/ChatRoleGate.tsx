import type { ReactNode } from 'react';
import type { GroupRole } from '@/api/group';
import { useChatRole } from './useChatRole';

interface ChatRoleGateProps {
  chatId: string;
  allow: GroupRole | GroupRole[];
  role?: GroupRole | null;
  fallback?: ReactNode;
  children: ReactNode;
}

export function ChatRoleGate({ chatId, allow, role, fallback = null, children }: ChatRoleGateProps) {
  const { role: cachedRole } = useChatRole(chatId);
  const resolvedRole = role === undefined ? cachedRole : role;
  const allowedRoles = Array.isArray(allow) ? allow : [allow];

  if (!resolvedRole || !allowedRoles.includes(resolvedRole)) {
    return <>{fallback}</>;
  }

  return <>{children}</>;
}
