import type { AxiosResponse } from 'axios';
import apiClient from './client';
import type { GroupInfoResponse } from './group';

export interface InviteInfoResponse {
  id: string;
  code: string;
  chat_id: string;
  invite_type: string;
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

export function getInvitePreview(inviteCode: string): Promise<AxiosResponse<InvitePreviewResponse>> {
  return apiClient.get('/invites/invite', { params: { invite_code: inviteCode } });
}

export function redeemInvite(body: RedeemInviteBody): Promise<AxiosResponse<RedeemInviteResponse>> {
  return apiClient.post('/invites/redeem', body);
}
