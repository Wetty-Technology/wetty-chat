import { isHeicLikeMedia } from '@/utils/heicMedia';

export type AttachmentMimeCategory = 'image' | 'video' | 'audio' | 'other';

export function categorizeAttachmentKind(kind: string): AttachmentMimeCategory {
  if (kind.startsWith('image/')) return 'image';
  if (kind.startsWith('video/')) return 'video';
  if (kind.startsWith('audio/')) return 'audio';
  return 'other';
}

export function isImageKind(kind: string, meta?: { fileName?: string | null; url?: string | null }): boolean {
  return kind.startsWith('image/') || isHeicLikeMedia({ mimeType: kind, ...meta });
}

export function isVideoKind(kind: string): boolean {
  return kind.startsWith('video/');
}

export function isAudioKind(kind: string): boolean {
  return kind.startsWith('audio/');
}
