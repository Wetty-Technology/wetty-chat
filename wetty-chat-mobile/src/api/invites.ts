import type { AxiosResponse } from 'axios';
import apiClient from './client';
import type { GroupInfoResponse } from './group';
import type { MessageResponse } from './messages';

export type InviteType = 'generic' | 'targeted' | 'membership';

export interface InviteInfoResponse {
  id: string;
  code: string;
  chat_id: string;
  invite_type: InviteType;
  creator_uid: number;
  target_uid: number | null;
  required_chat_id: string | null;
  created_at: string;
  expires_at: string | null;
  revoked_at: string | null;
  used_at: string | null;
}

export interface InvitePreviewResponse {
  invite: InviteInfoResponse;
  chat: GroupInfoResponse;
  already_member: boolean;
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
  chat_id: string;
  invite_type: InviteType;
  target_uid?: number;
  required_chat_id?: string;
  expires_at?: string | null;
}

export interface SendInviteMessageBody {
  source_chat_id: string;
  destination_chat_id: string;
  invite_id?: string;
  expires_at?: string | null;
  client_generated_id: string;
}

export interface SendInviteMessageResponse {
  invite: InviteInfoResponse;
  message: MessageResponse;
}

export function getInvitePreview(inviteCode: string): Promise<AxiosResponse<InvitePreviewResponse>> {
  return apiClient.get('/invites/invite', { params: { invite_code: inviteCode } });
}

export function redeemInvite(body: RedeemInviteBody): Promise<AxiosResponse<RedeemInviteResponse>> {
  return apiClient.post('/invites/redeem', body);
}

export function getInvites(
  params: {
    group_id?: string;
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
