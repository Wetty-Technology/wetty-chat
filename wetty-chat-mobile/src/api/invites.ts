import type { AxiosResponse } from 'axios';
import apiClient from './client';
import type { GroupInfoResponse } from './group';
import type { MessageResponse } from './messages';

export type InviteType = 'generic' | 'targeted' | 'membership';

export interface InviteInfoResponse {
  id: string;
  code: string;
  chatId: string;
  inviteType: InviteType;
  creatorUid: number | null;
  targetUid: number | null;
  requiredChatId: string | null;
  createdAt: string;
  expiresAt: string | null;
  revokedAt: string | null;
  usedAt: string | null;
}

export interface InvitePreviewResponse {
  invite: InviteInfoResponse;
  chat: GroupInfoResponse;
  alreadyMember: boolean;
}

export interface RedeemInviteBody {
  code: string;
}

export interface RedeemInviteResponse {
  chat: GroupInfoResponse;
}

export interface ListInvitesResponse {
  invites: InviteInfoResponse[];
}

export interface CreateInviteBody {
  chatId: string;
  inviteType: InviteType;
  targetUid?: number;
  requiredChatId?: string;
  expiresAt?: string | null;
}

export interface SendInviteMessageBody {
  sourceChatId: string;
  destinationChatId: string;
  inviteId?: string;
  expiresAt?: string | null;
  clientGeneratedId: string;
}

export interface SendInviteMessageResponse {
  invite: InviteInfoResponse;
  message: MessageResponse;
}

export function getInvitePreview(inviteCode: string): Promise<AxiosResponse<InvitePreviewResponse>> {
  return apiClient.get('/invites/invite', { params: { inviteCode } });
}

export function redeemInvite(body: RedeemInviteBody): Promise<AxiosResponse<RedeemInviteResponse>> {
  return apiClient.post('/invites/redeem', body);
}

export function getInvites(
  params: {
    groupId?: string;
    limit?: number;
  } = {},
): Promise<AxiosResponse<ListInvitesResponse>> {
  return apiClient.get('/invites', { params });
}

export function createInvite(body: CreateInviteBody): Promise<AxiosResponse<InviteInfoResponse>> {
  return apiClient.post('/invites', body);
}

export function sendInviteMessage(body: SendInviteMessageBody): Promise<AxiosResponse<SendInviteMessageResponse>> {
  return apiClient.post('/invites/send', body);
}

export function deleteInvite(inviteId: string): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/invites/invite/${inviteId}`);
}
