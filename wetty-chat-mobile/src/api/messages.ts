import type { AxiosResponse } from 'axios';
import apiClient from './client';

export interface ReplyToMessage {
  id: string;
  message: string | null;
  sender_uid: number;
  deleted_at: string | null;
}

export interface MessageResponse {
  id: string;
  message: string | null;
  message_type: string;
  reply_to_id: string | null;
  reply_root_id: string | null;
  client_generated_id: string;
  sender_uid: number;
  chat_id: string;
  created_at: string;
  updated_at: string | null;
  deleted_at: string | null;
  has_attachments: boolean;
  reply_to_message?: ReplyToMessage;
}

export interface ListMessagesResponse {
  messages: MessageResponse[];
  next_cursor: string | null;
}

export interface CreateMessageBody {
  message?: string;
  message_type: string;
  client_generated_id: string;
  reply_to_id?: string;
  reply_root_id?: string;
}

export function getMessages(
  chatId: string | number,
  params?: { before?: string; max?: number }
): Promise<AxiosResponse<ListMessagesResponse>> {
  const query: Record<string, string | number> = {};
  if (params?.before != null) query.before = params.before;
  if (params?.max != null) query.max = params.max;
  return apiClient.get(`/chats/${chatId}/messages`, { params: query });
}

export function sendMessage(
  chatId: string | number,
  body: CreateMessageBody
): Promise<AxiosResponse<MessageResponse>> {
  return apiClient.post(`/chats/${chatId}/messages`, body);
}

export interface UpdateMessageBody {
  message: string;
}

export function updateMessage(
  chatId: string | number,
  messageId: string,
  body: UpdateMessageBody
): Promise<AxiosResponse<MessageResponse>> {
  return apiClient.patch(`/chats/${chatId}/messages/${messageId}`, body);
}

export function deleteMessage(
  chatId: string | number,
  messageId: string
): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/chats/${chatId}/messages/${messageId}`);
}
