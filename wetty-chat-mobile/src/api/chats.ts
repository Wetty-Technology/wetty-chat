import type { AxiosResponse } from 'axios';
import apiClient from './client';

export interface ChatListItem {
  id: string;
  name: string | null;
  last_message_at: string | null;
}

export interface ChatDetail {
  id: string;
  name: string | null;
  description: string | null;
  avatar: string | null;
  created_at: string;
}

interface ListChatsResponse {
  chats: ChatListItem[];
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

export function getChat(chatId: string): Promise<AxiosResponse<ChatDetail>> {
  return apiClient.get(`/chats/${chatId}`);
}

export function createChat(body: { name?: string } = {}): Promise<AxiosResponse<CreateChatResponse>> {
  return apiClient.post('/chats', body);
}
