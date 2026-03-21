import type { AxiosResponse } from 'axios';
import apiClient from './client';

export interface GroupInfoResponse {
  id: string;
  name: string;
  description: string | null;
  avatar: string | null;
  visibility: string;
  created_at: string;
  muted_until: string | null;
}

export interface UpdateGroupInfoBody {
  name?: string;
  description?: string;
  avatar?: string;
  visibility?: string;
}

export interface MemberResponse {
  uid: number;
  role: string;
  joined_at: string;
  username: string | null;
  avatar_url: string | null;
}

export interface ListMembersResponse {
  members: MemberResponse[];
  next_cursor: number | null;
  can_manage_members: boolean;
}

export interface AddMemberBody {
  uid: number;
  role?: string;
}

export interface UpdateMemberRoleBody {
  role: string;
}

export function getGroupInfo(chatId: string | number): Promise<AxiosResponse<GroupInfoResponse>> {
  return apiClient.get(`/group/${chatId}`);
}

export function updateGroupInfo(chatId: string | number, body: UpdateGroupInfoBody): Promise<AxiosResponse<GroupInfoResponse>> {
  return apiClient.patch(`/group/${chatId}`, body);
}

export function getMembers(
  chatId: string | number,
  params: { limit?: number; after?: number } = {},
): Promise<AxiosResponse<ListMembersResponse>> {
  return apiClient.get(`/group/${chatId}/members`, { params });
}

export function addMember(chatId: string | number, body: AddMemberBody): Promise<AxiosResponse<MemberResponse>> {
  return apiClient.post(`/group/${chatId}/members`, body);
}

export function removeMember(chatId: string | number, uid: number): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/group/${chatId}/members/${uid}`);
}

export function updateMemberRole(chatId: string | number, uid: number, body: UpdateMemberRoleBody): Promise<AxiosResponse<MemberResponse>> {
  return apiClient.patch(`/group/${chatId}/members/${uid}`, body);
}

export function muteChat(chatId: string | number, body: { duration_seconds?: number | null } = {}): Promise<AxiosResponse<{ muted_until: string }>> {
  return apiClient.put(`/group/${chatId}/mute`, body);
}

export function unmuteChat(chatId: string | number): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/group/${chatId}/mute`);
}
