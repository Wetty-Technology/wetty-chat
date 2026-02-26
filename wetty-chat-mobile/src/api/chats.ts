import type { AxiosResponse } from 'axios';
import apiClient from './client';

export interface ChatListItem {
  id: string;
  name: string | null;
  last_message_at: string | null;
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

export function createChat(body: { name?: string } = {}): Promise<AxiosResponse<CreateChatResponse>> {
  return apiClient.post('/chats', body);
}

export interface ChatDetailResponse {
  id: string;
  name: string;
  description: string | null;
  avatar: string | null;
  visibility: string;
  created_at: string;
}

export interface UpdateChatBody {
  name?: string;
  description?: string;
  avatar?: string;
  visibility?: string;
}

export function getChatDetails(chatId: string | number): Promise<AxiosResponse<ChatDetailResponse>> {
  return apiClient.get(`/chats/${chatId}`);
}

export function updateChat(chatId: string | number, body: UpdateChatBody): Promise<AxiosResponse<ChatDetailResponse>> {
  return apiClient.patch(`/chats/${chatId}`, body);
}

export interface MemberResponse {
  uid: number;
  role: string;
  joined_at: string;
  username: string | null;
}

export interface AddMemberBody {
  uid: number;
  role?: string;
}

export interface UpdateMemberRoleBody {
  role: string;
}

export function getMembers(chatId: string | number): Promise<AxiosResponse<MemberResponse[]>> {
  return apiClient.get(`/chats/${chatId}/members`);
}

export function addMember(chatId: string | number, body: AddMemberBody): Promise<AxiosResponse<MemberResponse>> {
  return apiClient.post(`/chats/${chatId}/members`, body);
}

export function removeMember(chatId: string | number, uid: number): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/chats/${chatId}/members/${uid}`);
}

export function updateMemberRole(chatId: string | number, uid: number, body: UpdateMemberRoleBody): Promise<AxiosResponse<MemberResponse>> {
  return apiClient.patch(`/chats/${chatId}/members/${uid}`, body);
}
