import axios, { type AxiosResponse } from 'axios';
import apiClient from './client';

export interface UploadUrlRequest {
  filename: string;
  contentType: string;
  size: number;
  width?: number;
  height?: number;
}

export interface UploadUrlResponse {
  attachmentId: string;
  uploadUrl: string;
  uploadHeaders: Record<string, string>;
}

export interface UploadFileToS3Options {
  signal?: AbortSignal;
  onProgress?: (progress: number) => void;
}

export function requestUploadUrl(body: UploadUrlRequest): Promise<AxiosResponse<UploadUrlResponse>> {
  return apiClient.post('/attachments/upload-url', body);
}

export async function uploadFileToS3(
  url: string,
  file: File,
  headers: Record<string, string>,
  options: UploadFileToS3Options = {},
): Promise<AxiosResponse<void>> {
  return axios.put(url, file, {
    headers,
    signal: options.signal,
    onUploadProgress: (event) => {
      if (!options.onProgress || !event.total) return;
      const progress = Math.max(0, Math.min(100, Math.round((event.loaded / event.total) * 100)));
      options.onProgress(progress);
    },
  });
}
