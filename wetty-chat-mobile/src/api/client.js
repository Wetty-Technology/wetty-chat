import axios from 'axios';

/**
 * Base URL for API requests.
 * - Development: /api (same-origin; Vite proxies to backend at localhost:3000).
 * - Production: VITE_API_BASE_URL (must be set in build env).
 * TODO: X-User-Id should later come from auth state (e.g. store after login).
 */

const apiClient = axios.create({ baseURL: '/api' });

// Placeholder until real auth: backend requires X-User-Id (i32).
const PLACEHOLDER_USER_ID = 1;

apiClient.interceptors.request.use((config) => {
  config.headers['X-User-Id'] = String(PLACEHOLDER_USER_ID);
  return config;
});

export default apiClient;
