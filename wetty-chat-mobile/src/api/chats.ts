import type { AxiosResponse } from 'axios';
import apiClient from './client';
import type { MessageResponse } from './messages';

export interface ChatListEntry {
  id: string;
  name: string | null;
  avatar: string | null;
  lastMessageAt: string | null;
  unreadCount: number;
  lastReadMessageId?: string | null;
  lastMessage: MessageResponse | null;
  mutedUntil: string | null;
}

interface ListChatsResponse {
  chats: ChatListEntry[];
  nextCursor: string | null;
}

interface CreateChatResponse {
  id: string;
  name: string | null;
  createdAt: string;
}

export function getChats(params: { limit?: number; after?: string } = {}): Promise<AxiosResponse<ListChatsResponse>> {
  return apiClient.get('/chats', { params });
}

export function createChat(body: { name?: string } = {}): Promise<AxiosResponse<CreateChatResponse>> {
  return apiClient.post('/group', body);
}

export function getUnreadCount(): Promise<AxiosResponse<{ unreadCount: number }>> {
  return apiClient.get('/chats/unread');
}
