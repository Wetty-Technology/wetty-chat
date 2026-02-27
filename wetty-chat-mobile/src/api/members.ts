import type { AxiosResponse } from 'axios';
import apiClient from './client';

export interface MemberResponse {
  uid: number;
  role: string;
  username: string | null;
}

export function getMembers(chatId: string): Promise<AxiosResponse<MemberResponse[]>> {
  return apiClient.get(`/group/${chatId}/members`);
}

export function addMember(chatId: string, uid: number): Promise<AxiosResponse<void>> {
  return apiClient.post(`/group/${chatId}/members`, { uid });
}
