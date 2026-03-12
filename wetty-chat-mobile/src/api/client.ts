import axios, { HttpStatusCode } from 'axios';
import { getCurrentUserId } from '@/js/current-user';

/**
 * Base URL for API requests.
 * - Development: /_api (same-origin; Vite proxies to backend at localhost:3000).
 * - Production: VITE_API_BASE_URL (must be set in build env).
 */

const apiClient = axios.create({ baseURL: import.meta.env.BASE_URL + '_api' });

apiClient.interceptors.request.use((config) => {
  if (import.meta.env.DEV) {
    config.headers['X-User-Id'] = String(getCurrentUserId());
  }
  return config;
});

if (import.meta.env.PROD && __AUTH_REDIRECT_URL__) {
  apiClient.interceptors.response.use((fulfilled) => {
    return fulfilled
  }, (error) => {
    if (error.response?.status === HttpStatusCode.Unauthorized) {
      window.location.href = __AUTH_REDIRECT_URL__;
    }
    return Promise.reject(error);
  });
}

export default apiClient;
