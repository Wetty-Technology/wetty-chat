import apiClient from './client.js';

/**
 * @typedef {Object} ChatListItem
 * @property {number} id
 * @property {string|null} name
 * @property {string|null} last_message_at - ISO 8601
 */

/**
 * @typedef {Object} ListChatsResponse
 * @property {ChatListItem[]} chats
 * @property {number|null} next_cursor
 */

/**
 * @param {{ limit?: number, after?: number }} [params]
 * @returns {Promise<import('axios').AxiosResponse<ListChatsResponse>>}
 */
export function getChats(params = {}) {
  return apiClient.get('/chats', { params });
}

/**
 * @param {{ name?: string }} [body]
 * @returns {Promise<import('axios').AxiosResponse<{ id: number, name: string|null, created_at: string }>>}
 */
export function createChat(body = {}) {
  return apiClient.post('/chats', body);
}
