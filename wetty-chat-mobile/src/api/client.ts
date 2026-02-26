import axios from 'axios';
import { getCurrentUserId } from '@/js/current-user';

/**
 * Base URL for API requests.
 * - Development: /api (same-origin; Vite proxies to backend at localhost:3000).
 * - Production: VITE_API_BASE_URL (must be set in build env).
 */

const apiClient = axios.create({ baseURL: '/_api' });

apiClient.interceptors.request.use((config) => {
  config.headers['X-User-Id'] = String(getCurrentUserId());
  return config;
});

export default apiClient;
