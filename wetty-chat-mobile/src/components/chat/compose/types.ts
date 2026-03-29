import type { Attachment } from '@/api/messages';
import type { ImageUploadDraft } from '../UploadPreview';

export interface ReplyTo {
  messageId: string;
  username: string;
  text?: string | null;
  attachments?: Attachment[];
  isDeleted?: boolean;
}

export interface EditingMessage {
  messageId: string;
  text: string;
  attachments?: Attachment[];
}

export interface ComposeUploadInput {
  file: File;
  signal: AbortSignal;
  onProgress: (progress: number) => void;
  dimensions?: {
    width?: number;
    height?: number;
  };
}

export interface ComposeUploadResult {
  attachmentId: string;
}

export interface ComposeUploadedAttachment {
  attachmentId: string;
  file: File;
  mimeType: string;
  size: number;
  width?: number;
  height?: number;
}

export interface ComposeSendTextPayload {
  kind: 'text';
  text: string;
  attachmentIds: string[];
  existingAttachments: Attachment[];
  uploadedAttachments: ComposeUploadedAttachment[];
}

export interface ComposeSendAudioPayload {
  kind: 'audio';
  durationMs: number;
  attachmentId: string;
  uploadedAttachment: ComposeUploadedAttachment;
}

export type ComposeSendPayload = ComposeSendTextPayload | ComposeSendAudioPayload;

export interface DraftUploadRecord {
  draft: ImageUploadDraft;
  file: File;
  abortController?: AbortController;
}

export type VoiceRecorderPhase = 'requesting' | 'recording' | 'locked' | 'uploading';

export interface VoiceRecorderState {
  phase: VoiceRecorderPhase;
  startedAt: number;
  durationMs: number;
  cancelArmed: boolean;
  uploadProgress: number;
}
