import type { AxiosResponse } from 'axios';
import apiClient from './client';

export interface UploadUrlRequest {
    filename: string;
    content_type: string;
    size: number;
    width?: number;
    height?: number;
}

export interface UploadUrlResponse {
    attachment_id: string;
    upload_url: string;
}

export function requestUploadUrl(
    body: UploadUrlRequest
): Promise<AxiosResponse<UploadUrlResponse>> {
    return apiClient.post('/attachments/upload-url', body);
}

export async function uploadFileToS3(
    url: string,
    file: File
): Promise<Response> {
    return fetch(url, {
        method: 'PUT',
        body: file,
        headers: {
            'Content-Type': file.type,
            'x-amz-acl': 'public-read',
        },
    });
}
