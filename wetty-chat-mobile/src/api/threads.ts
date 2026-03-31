import type { AxiosResponse } from 'axios';
import type { MessageResponse } from './messages';
import apiClient from './client';

export interface ThreadParticipant {
  uid: number;
  name: string | null;
  avatarUrl?: string | null;
}

export interface ThreadReplyPreview {
  sender: ThreadParticipant;
  message: string | null;
  messageType: string;
  stickerEmoji?: string | null;
  firstAttachmentKind?: string | null;
  isDeleted: boolean;
}

export interface ThreadListItem {
  chatId: string;
  chatName: string;
  chatAvatar: string | null;
  threadRootMessage: MessageResponse;
  participants: ThreadParticipant[];
  lastReply: ThreadReplyPreview | null;
  replyCount: number;
  lastReplyAt: string;
  unreadCount: number;
  subscribedAt: string;
}

export interface ListThreadsResponse {
  threads: ThreadListItem[];
  nextCursor: string | null;
}

export interface UnreadThreadCountResponse {
  unreadThreadCount: number;
}

export interface ThreadSubscriptionStatusResponse {
  subscribed: boolean;
}

export function getThreads(params?: { limit?: number; before?: string }): Promise<AxiosResponse<ListThreadsResponse>> {
  const query: Record<string, string | number> = {};
  if (params?.limit != null) query.limit = params.limit;
  if (params?.before != null) query.before = params.before;
  return apiClient.get('/threads', { params: query });
}

export function markThreadAsRead(
  threadRootId: string,
  messageId: string,
): Promise<AxiosResponse<{ updated: boolean }>> {
  return apiClient.post(`/threads/${threadRootId}/read`, { messageId });
}

export function getUnreadThreadCount(): Promise<AxiosResponse<UnreadThreadCountResponse>> {
  return apiClient.get('/threads/unread');
}

export function subscribeToThread(
  chatId: string | number,
  threadRootId: string | number,
): Promise<AxiosResponse<void>> {
  return apiClient.put(`/chats/${chatId}/threads/${threadRootId}/subscribe`);
}

export function unsubscribeFromThread(
  chatId: string | number,
  threadRootId: string | number,
): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/chats/${chatId}/threads/${threadRootId}/subscribe`);
}

export function getThreadSubscriptionStatus(
  chatId: string | number,
  threadRootId: string | number,
): Promise<AxiosResponse<ThreadSubscriptionStatusResponse>> {
  return apiClient.get(`/chats/${chatId}/threads/${threadRootId}/subscribe`);
}
