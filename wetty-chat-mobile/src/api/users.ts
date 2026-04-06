import apiClient from './client';

export interface User {
  uid: number;
  username: string;
  avatarUrl?: string | null;
  gender: number;
}

export const usersApi = {
  getCurrentUser: async (): Promise<User> => {
    const response = await apiClient.get<User>('/users/me');
    return response.data;
  },
  getUserSettings: async (): Promise<Record<string, unknown>> => {
    const response = await apiClient.get<Record<string, unknown>>('/users/me/settings');
    return response.data;
  },
  patchUserSettings: async (preferences: Record<string, unknown>): Promise<Record<string, unknown>> => {
    const response = await apiClient.patch<Record<string, unknown>>('/users/me/settings', { preferences });
    return response.data;
  },
};
