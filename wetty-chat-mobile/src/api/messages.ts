import type { AxiosResponse } from 'axios';
import type { StickerSummary } from './stickers';
import apiClient from './client';

export interface UserGroupInfo {
  group_id: number;
  name?: string | null;
  chat_group_color?: string | null;
  chat_group_color_dark?: string | null;
}

export interface Sender {
  uid: number;
  avatar_url?: string;
  name: string | null;
  gender: number;
  user_group?: UserGroupInfo | null;
}

export interface ReplyToMessage {
  id: string;
  message: string | null;
  message_type: 'text' | 'audio' | 'file' | 'system' | 'invite' | 'sticker';
  sticker?: StickerSummary;
  sender: Sender;
  is_deleted: boolean;
  attachments?: Attachment[];
  first_attachment_kind?: string;
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

export interface ReactionReactor {
  uid: number;
  name: string | null;
  avatar_url?: string;
}

export interface ReactionSummary {
  emoji: string;
  count: number;
  reacted_by_me?: boolean;
  reactors?: ReactionReactor[];
}

export interface ReactionDetailResponse {
  reactions: { emoji: string; reactors: ReactionReactor[] }[];
}

export interface MessageResponse {
  id: string;
  message: string | null;
  message_type: 'text' | 'audio' | 'system' | 'invite' | 'sticker';
  sticker?: StickerSummary;
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
  reactions?: ReactionSummary[];
}

export interface ListMessagesResponse {
  messages: MessageResponse[];
  next_cursor: string | null;
  prev_cursor?: string | null;
}

export interface CreateMessageBody {
  message?: string;
  message_type: string;
  sticker_id?: string;
  client_generated_id: string;
  reply_to_id?: string; // Keep in CreateMessageBody
  reply_root_id?: string;
  attachment_ids?: string[];
}

export function getMessages(
  chatId: string | number,
  params?: { before?: string; around?: string; after?: string; max?: number; thread_id?: string },
): Promise<AxiosResponse<ListMessagesResponse>> {
  const query: Record<string, string | number> = {};
  if (params?.before != null) query.before = params.before;
  if (params?.around != null) query.around = params.around;
  if (params?.after != null) query.after = params.after;
  if (params?.max != null) query.max = params.max;
  if (params?.thread_id != null) query.thread_id = params.thread_id;
  return apiClient.get(`/chats/${chatId}/messages`, { params: query });
}

export function sendMessage(chatId: string | number, body: CreateMessageBody): Promise<AxiosResponse<MessageResponse>> {
  return apiClient.post(`/chats/${chatId}/messages`, body);
}

export function sendThreadMessage(
  chatId: string | number,
  threadId: string | number,
  body: CreateMessageBody,
): Promise<AxiosResponse<MessageResponse>> {
  return apiClient.post(`/chats/${chatId}/threads/${threadId}/messages`, body);
}

export interface UpdateMessageBody {
  message: string;
  attachment_ids?: string[];
}

export function updateMessage(
  chatId: string | number,
  messageId: string,
  body: UpdateMessageBody,
): Promise<AxiosResponse<MessageResponse>> {
  return apiClient.patch(`/chats/${chatId}/messages/${messageId}`, body);
}

export function deleteMessage(chatId: string | number, messageId: string): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/chats/${chatId}/messages/${messageId}`);
}

export function getMessage(chatId: string | number, messageId: string): Promise<AxiosResponse<MessageResponse>> {
  return apiClient.get(`/chats/${chatId}/messages/${messageId}`);
}

export function putReaction(chatId: string | number, messageId: string, emoji: string): Promise<AxiosResponse<void>> {
  return apiClient.put(`/chats/${chatId}/messages/${messageId}/reactions/${encodeURIComponent(emoji)}`);
}

export function deleteReaction(
  chatId: string | number,
  messageId: string,
  emoji: string,
): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/chats/${chatId}/messages/${messageId}/reactions/${encodeURIComponent(emoji)}`);
}

export function getReactionDetails(
  chatId: string | number,
  messageId: string,
): Promise<AxiosResponse<ReactionDetailResponse>> {
  return apiClient.get(`/chats/${chatId}/messages/${messageId}/reactions`);
}

export function markMessagesAsRead(chatId: string | number, messageId: string | number): Promise<AxiosResponse<void>> {
  return apiClient.post(`/chats/${chatId}/read`, { message_id: messageId.toString() });
}
