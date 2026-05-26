import type { AxiosResponse } from 'axios';
import type { MentionInfo, MessageResponse, UserGroupTagInfo } from './messages';
import apiClient from './client';

export interface SavedAttachmentSnapshot {
  id: string;
  externalReference: string;
  url: string;
  kind: string;
  size: number;
  fileName: string;
  width?: number | null;
  height?: number | null;
  order: number;
}

export interface SavedStickerSnapshot {
  id: string;
  emoji: string;
  name?: string | null;
  mediaUrl: string;
  mediaContentType: string;
}

export interface SavedSenderSnapshot {
  uid: number;
  name: string | null;
  avatarUrl?: string | null;
  gender: number;
  userGroup?: UserGroupTagInfo | null;
}

export interface SavedChatSnapshot {
  id: string;
  name: string | null;
  avatarUrl?: string | null;
}

export interface SavedMessageResponse {
  id: string;
  originalChatId: string;
  originalThreadRootId: string | null;
  originalMessageId: string;
  originalReplyToMessageId: string | null;
  originalSenderUid: number;
  originalCreatedAt: string;
  savedAt: string;
  message: string | null;
  messageType: MessageResponse['messageType'];
  attachments: SavedAttachmentSnapshot[];
  sticker?: SavedStickerSnapshot | null;
  mentions: MentionInfo[];
  sender: SavedSenderSnapshot;
  chat: SavedChatSnapshot;
  canLocateContext: boolean;
}

export interface ListSavedMessagesResponse {
  savedMessages: SavedMessageResponse[];
  nextCursor: string | null;
}

interface ListSavedMessagesParams {
  limit?: number;
  before?: string | null;
}

function compactListParams(params?: ListSavedMessagesParams): Record<string, string | number> {
  const query: Record<string, string | number> = {};
  if (params?.limit != null) query.limit = params.limit;
  if (params?.before != null) query.before = params.before;
  return query;
}

export function saveMessage(messageId: string): Promise<AxiosResponse<SavedMessageResponse>> {
  return apiClient.put(`/saved-messages/${messageId}`);
}

export function deleteSavedMessage(savedMessageId: string): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/saved-messages/by-id/${savedMessageId}`);
}

export function deleteSavedMessageByOriginal(messageId: string): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/saved-messages/by-message/${messageId}`);
}

export function listSavedMessages(params?: ListSavedMessagesParams): Promise<AxiosResponse<ListSavedMessagesResponse>> {
  return apiClient.get('/saved-messages', { params: compactListParams(params) });
}

export function listChatSavedMessages(
  chatId: string,
  params?: ListSavedMessagesParams,
): Promise<AxiosResponse<ListSavedMessagesResponse>> {
  return apiClient.get(`/chats/${chatId}/saved-messages`, { params: compactListParams(params) });
}
