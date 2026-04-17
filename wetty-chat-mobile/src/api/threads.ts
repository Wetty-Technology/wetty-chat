import type { AxiosResponse } from 'axios';
import type { MentionInfo } from './messages';
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
  mentions?: MentionInfo[] | null;
}

export interface ThreadRootMessagePreview {
  id: string;
  sender: ThreadParticipant;
  message: string | null;
  messageType: string;
  firstAttachmentKind?: string | null;
  isDeleted: boolean;
  mentions?: MentionInfo[];
}

export interface ThreadListItem {
  chatId: string;
  chatName: string;
  chatAvatar: string | null;
  threadRootMessage: ThreadRootMessagePreview;
  participants: ThreadParticipant[];
  lastReply: ThreadReplyPreview | null;
  replyCount: number;
  lastReplyAt: string;
  unreadCount: number;
  subscribedAt: string;
  archived: boolean;
}

/** Internal Redux state representation — replaces `lastReply` with a cache-only fallback. */
export interface StoredThreadListItem extends Omit<ThreadListItem, 'lastReply'> {
  cachedLastReply: ThreadReplyPreview | null;
}

export interface ListThreadsResponse {
  threads: ThreadListItem[];
  nextCursor: string | null;
}

export interface UnreadThreadCountResponse {
  unreadThreadCount: number;
  archivedUnreadThreadCount: number;
}

export interface ThreadSubscriptionStatusResponse {
  subscribed: boolean;
  archived: boolean;
}

export function getThreads(params?: {
  limit?: number;
  before?: string;
  archived?: boolean;
}): Promise<AxiosResponse<ListThreadsResponse>> {
  const query: Record<string, string | number | boolean> = {};
  if (params?.limit != null) query.limit = params.limit;
  if (params?.before != null) query.before = params.before;
  if (params?.archived != null) query.archived = params.archived;
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

export function archiveThread(chatId: string | number, threadRootId: string | number): Promise<AxiosResponse<void>> {
  return apiClient.put(`/chats/${chatId}/threads/${threadRootId}/archive`);
}

export function unarchiveThread(chatId: string | number, threadRootId: string | number): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/chats/${chatId}/threads/${threadRootId}/archive`);
}
