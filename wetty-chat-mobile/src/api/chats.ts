import type { AxiosResponse } from 'axios';
import apiClient from './client';
import type { MessageResponse } from './messages';

export interface ChatListEntry {
  id: string;
  name: string | null;
  avatar: string | null;
  last_message_at: string | null;
  unread_count: number;
  last_read_message_id?: string | null;
  last_message: MessageResponse | null;
  muted_until: string | null;
}

interface ListChatsResponse {
  chats: ChatListEntry[];
  next_cursor: string | null;
}

interface CreateChatResponse {
  id: string;
  name: string | null;
  created_at: string;
}

export function getChats(params: { limit?: number; after?: string } = {}): Promise<AxiosResponse<ListChatsResponse>> {
  return apiClient.get('/chats', { params });
}

export function createChat(body: { name?: string } = {}): Promise<AxiosResponse<CreateChatResponse>> {
  return apiClient.post('/group', body);
}

export function getUnreadCount(): Promise<AxiosResponse<{ unread_count: number }>> {
  return apiClient.get('/chats/unread');
}
