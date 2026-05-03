import type { AxiosResponse } from 'axios';
import type { User } from './messages';
import apiClient from './client';

export type ChatAttachmentKindFilter = 'all' | 'image' | 'video' | 'other';

export interface ChatAttachmentListItem {
  id: string;
  messageId: string;
  messageCreatedAt: string;
  sender: User;
  url: string;
  kind: string;
  size: number;
  fileName: string;
  width?: number | null;
  height?: number | null;
  order: number;
}

export interface ListChatAttachmentsResponse {
  attachments: ChatAttachmentListItem[];
  olderCursor: string | null;
  newerCursor: string | null;
}

export interface ListChatAttachmentsParams {
  kind: ChatAttachmentKindFilter;
  limit?: number;
  before?: string;
  after?: string;
}

export function listChatAttachments(
  chatId: string | number,
  params: ListChatAttachmentsParams,
  signal?: AbortSignal,
): Promise<AxiosResponse<ListChatAttachmentsResponse>> {
  const query: Record<string, string | number> = {
    kind: params.kind,
  };
  if (params.limit != null) query.limit = params.limit;
  if (params.before != null) query.before = params.before;
  if (params.after != null) query.after = params.after;

  return apiClient.get(`/chats/${chatId}/attachments`, { params: query, signal });
}
