import type { AxiosResponse } from 'axios';
import apiClient from './client';

export interface Sender {
  uid: number;
  name: string | null;
}

export interface ReplyToMessage {
  id: string;
  message: string | null;
  sender: Sender;
  is_deleted: boolean;
}

export interface Attachment {
  id: string;
  url: string;
  kind: string;
  size: number;
  file_name: string;
  width?: number | null;
  height?: number | null;
}

export interface ThreadInfo {
  reply_count: number;
}

export interface MessageResponse {
  id: string;
  message: string | null;
  message_type: string;
  reply_root_id: string | null;
  client_generated_id: string;
  sender: Sender;
  chat_id: string;
  created_at: string;
  is_edited: boolean;
  is_deleted: boolean;
  has_attachments: boolean;
  thread_info?: ThreadInfo;
  reply_to_message?: ReplyToMessage;
  attachments?: Attachment[];
}

export interface ListMessagesResponse {
  messages: MessageResponse[];
  next_cursor: string | null;
  prev_cursor?: string | null;
}

export interface CreateMessageBody {
  message?: string;
  message_type: string;
  client_generated_id: string;
  reply_to_id?: string; // Keep in CreateMessageBody
  reply_root_id?: string;
  attachment_ids?: string[];
}

export function getMessages(
  chatId: string | number,
  params?: { before?: string; around?: string; after?: string; max?: number; thread_id?: string }
): Promise<AxiosResponse<ListMessagesResponse>> {
  const query: Record<string, string | number> = {};
  if (params?.before != null) query.before = params.before;
  if (params?.around != null) query.around = params.around;
  if (params?.after != null) query.after = params.after;
  if (params?.max != null) query.max = params.max;
  if (params?.thread_id != null) query.thread_id = params.thread_id;
  return apiClient.get(`/chats/${chatId}/messages`, { params: query });
}

export function sendMessage(
  chatId: string | number,
  body: CreateMessageBody
): Promise<AxiosResponse<MessageResponse>> {
  return apiClient.post(`/chats/${chatId}/messages`, body);
}

export function sendThreadMessage(
  chatId: string | number,
  threadId: string | number,
  body: CreateMessageBody
): Promise<AxiosResponse<MessageResponse>> {
  return apiClient.post(`/chats/${chatId}/threads/${threadId}/messages`, body);
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

export function getMessage(
  chatId: string | number,
  messageId: string
): Promise<AxiosResponse<MessageResponse>> {
  return apiClient.get(`/chats/${chatId}/messages/${messageId}`);
}

export function markMessagesAsRead(
  chatId: string | number,
  messageId: string | number
): Promise<AxiosResponse<void>> {
  return apiClient.post(`/chats/${chatId}/messages/read`, { message_id: messageId.toString() });
}
