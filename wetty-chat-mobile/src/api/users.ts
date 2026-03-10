import apiClient from './client';

export interface User {
    uid: number;
    username: string;
}

export const usersApi = {
    getCurrentUser: async (): Promise<User> => {
        const response = await apiClient.get<User>('/users/me');
        return response.data;
    },
};
