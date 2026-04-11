import { useCallback, useEffect, useRef, useState } from 'react';
import { t } from '@lingui/core/macro';
import type {
  ComposeSendAudioPayload,
  ComposeUploadInput,
  ComposeUploadResult,
  RecordedVoiceDraft,
  VoiceRecorderState,
} from './types';

const MIN_VOICE_DURATION_MS = 500;

const isAbortError = (error: unknown) => error instanceof DOMException && error.name === 'AbortError';

const getSupportedVoiceMimeType = () => {
  if (typeof MediaRecorder === 'undefined' || typeof MediaRecorder.isTypeSupported !== 'function') {
    return '';
  }

  const candidates = ['audio/ogg;codecs=opus', 'audio/mp4', 'audio/mpeg'];
  return candidates.find((candidate) => MediaRecorder.isTypeSupported(candidate)) ?? '';
};

const getVoiceFileExtension = (mimeType: string) => {
  if (mimeType.includes('ogg')) return 'ogg';
  if (mimeType.includes('mp4')) return 'm4a';
  if (mimeType.includes('mpeg')) return 'mp3';
  return 'ogg';
};

interface UseVoiceRecorderArgs {
  uploadAttachment: (input: ComposeUploadInput) => Promise<ComposeUploadResult>;
  onSend: (payload: ComposeSendAudioPayload) => void;
  onError?: (message: string) => void;
  canStartVoice: boolean;
  onBeforeStart?: () => void;
}

export function useVoiceRecorder({
  uploadAttachment,
  onSend,
  onError,
  canStartVoice,
  onBeforeStart,
}: UseVoiceRecorderArgs) {
  const [voiceRecorder, setVoiceRecorder] = useState<VoiceRecorderState | null>(null);
  const voiceRecorderRef = useRef<VoiceRecorderState | null>(null);
  const voiceMediaRecorderRef = useRef<MediaRecorder | null>(null);
  const voiceStreamRef = useRef<MediaStream | null>(null);
  const voiceChunksRef = useRef<Blob[]>([]);
  const deferredActionRef = useRef<'complete' | 'send' | 'cancel' | null>(null);
  const voiceUploadAbortControllerRef = useRef<AbortController | null>(null);

  const setVoiceRecorderState = useCallback((next: VoiceRecorderState | null) => {
    voiceRecorderRef.current = next;
    setVoiceRecorder(next);
  }, []);

  useEffect(() => {
    voiceRecorderRef.current = voiceRecorder;
  }, [voiceRecorder]);

  const reportVoiceError = useCallback(
    (message: string) => {
      onError?.(message);
    },
    [onError],
  );

  const stopVoiceStream = useCallback(() => {
    voiceStreamRef.current?.getTracks().forEach((track) => track.stop());
    voiceStreamRef.current = null;
  }, []);

  const resetVoiceRecorder = useCallback(() => {
    voiceUploadAbortControllerRef.current?.abort();
    voiceUploadAbortControllerRef.current = null;
    voiceChunksRef.current = [];
    voiceMediaRecorderRef.current = null;
    deferredActionRef.current = null;
    stopVoiceStream();
    setVoiceRecorderState(null);
  }, [setVoiceRecorderState, stopVoiceStream]);

  const uploadAndSendDraft = useCallback(
    async (draft: RecordedVoiceDraft) => {
      const uploadAbortController = new AbortController();
      voiceUploadAbortControllerRef.current = uploadAbortController;
      setVoiceRecorderState({
        phase: 'uploading',
        ...draft,
        uploadProgress: 0,
      });

      try {
        const result = await uploadAttachment({
          file: draft.file,
          signal: uploadAbortController.signal,
          onProgress: (progress) => {
            setVoiceRecorder((currentVoice) =>
              currentVoice?.phase !== 'uploading'
                ? currentVoice
                : {
                    ...currentVoice,
                    uploadProgress: progress,
                  },
            );
          },
        });

        onSend({
          kind: 'audio',
          durationMs: draft.durationMs,
          attachmentId: result.attachmentId,
          uploadedAttachment: {
            attachmentId: result.attachmentId,
            file: draft.file,
            mimeType: draft.mimeType,
            size: draft.size,
          },
        });
        setVoiceRecorder(null);
      } catch (error) {
        if (!isAbortError(error) && !uploadAbortController.signal.aborted) {
          console.error('Failed to upload voice message:', error);
          reportVoiceError(t`Failed to send voice message.`);
          setVoiceRecorderState({
            phase: 'recorded',
            ...draft,
            uploadProgress: 0,
          });
        } else {
          setVoiceRecorderState(null);
        }
      } finally {
        voiceUploadAbortControllerRef.current = null;
      }
    },
    [onSend, reportVoiceError, setVoiceRecorderState, uploadAttachment],
  );

  const finalizeVoiceRecording = useCallback(
    (action: 'complete' | 'send' | 'cancel') => {
      const current = voiceRecorderRef.current;
      if (!current) {
        deferredActionRef.current = null;
        return;
      }

      if (current.phase === 'requesting') {
        deferredActionRef.current = action;
        return;
      }

      if (current.phase !== 'recording') {
        if (action === 'send' && current.phase === 'recorded') {
          void uploadAndSendDraft(current);
        } else if (action === 'cancel' && current.phase === 'recorded') {
          resetVoiceRecorder();
        }
        return;
      }

      deferredActionRef.current = action;
      setVoiceRecorderState({
        phase: 'recording',
        startedAt: current.startedAt,
        durationMs: Date.now() - current.startedAt,
      });

      const recorder = voiceMediaRecorderRef.current;
      if (!recorder || recorder.state === 'inactive') {
        if (action === 'cancel') {
          resetVoiceRecorder();
        }
        return;
      }

      recorder.stop();
    },
    [resetVoiceRecorder, setVoiceRecorderState, uploadAndSendDraft],
  );

  const startVoiceRecording = useCallback(async () => {
    if (!canStartVoice || voiceRecorderRef.current != null) {
      return;
    }

    if (
      typeof navigator === 'undefined' ||
      !navigator.mediaDevices?.getUserMedia ||
      typeof MediaRecorder === 'undefined'
    ) {
      reportVoiceError(t`Voice recording is not supported on this device.`);
      return;
    }

    const requestedAt = Date.now();
    setVoiceRecorderState({
      phase: 'requesting',
      startedAt: requestedAt,
      durationMs: 0,
    });

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      voiceStreamRef.current = stream;
      voiceChunksRef.current = [];

      const mimeType = getSupportedVoiceMimeType();
      const recorder = mimeType ? new MediaRecorder(stream, { mimeType }) : new MediaRecorder(stream);
      voiceMediaRecorderRef.current = recorder;
      const startedAt = Date.now();

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          voiceChunksRef.current.push(event.data);
        }
      };

      recorder.onstop = async () => {
        const current = voiceRecorderRef.current;
        const durationMs = current ? Math.max(current.durationMs, Date.now() - startedAt) : Date.now() - startedAt;
        const recordedChunks = voiceChunksRef.current;
        const finalAction = deferredActionRef.current ?? 'complete';
        deferredActionRef.current = null;
        voiceMediaRecorderRef.current = null;
        stopVoiceStream();
        voiceChunksRef.current = [];

        if (finalAction === 'cancel' || recordedChunks.length === 0) {
          setVoiceRecorderState(null);
          return;
        }

        if (durationMs < MIN_VOICE_DURATION_MS) {
          setVoiceRecorderState(null);
          reportVoiceError(t`Recording is too short.`);
          return;
        }

        const blobType = recorder.mimeType || mimeType || 'audio/ogg';
        const file = new File(
          [new Blob(recordedChunks, { type: blobType })],
          `voice-${Date.now()}.${getVoiceFileExtension(blobType)}`,
          {
            type: blobType,
            lastModified: Date.now(),
          },
        );
        const draft: RecordedVoiceDraft = {
          file,
          mimeType: blobType,
          size: file.size,
          durationMs,
        };

        if (finalAction === 'send') {
          await uploadAndSendDraft(draft);
          return;
        }

        setVoiceRecorderState({
          phase: 'recorded',
          ...draft,
          uploadProgress: 0,
        });
      };

      recorder.start();
      setVoiceRecorderState({
        phase: 'recording',
        startedAt,
        durationMs: 0,
      });

      const deferredAction = deferredActionRef.current;
      if (deferredAction) {
        finalizeVoiceRecording(deferredAction);
      }
    } catch (error) {
      console.error('Failed to access microphone:', error);
      stopVoiceStream();
      deferredActionRef.current = null;
      setVoiceRecorderState(null);
      reportVoiceError(t`Microphone access was denied.`);
    }
  }, [
    canStartVoice,
    finalizeVoiceRecording,
    reportVoiceError,
    setVoiceRecorderState,
    stopVoiceStream,
    uploadAndSendDraft,
  ]);

  useEffect(() => {
    if (!voiceRecorder || voiceRecorder.phase !== 'recording') {
      return;
    }

    const timer = window.setInterval(() => {
      setVoiceRecorder((current) =>
        current == null || current.phase !== 'recording'
          ? null
          : {
              ...current,
              durationMs: Date.now() - current.startedAt,
            },
      );
    }, 200);

    return () => window.clearInterval(timer);
  }, [voiceRecorder]);

  const handleVoiceStart = useCallback(() => {
    if (!canStartVoice) {
      return;
    }

    onBeforeStart?.();
    void startVoiceRecording();
  }, [canStartVoice, onBeforeStart, startVoiceRecording]);

  const completeVoiceRecording = useCallback(() => {
    finalizeVoiceRecording('complete');
  }, [finalizeVoiceRecording]);

  const cancelVoiceRecording = useCallback(() => {
    finalizeVoiceRecording('cancel');
  }, [finalizeVoiceRecording]);

  const sendVoiceRecording = useCallback(() => {
    finalizeVoiceRecording('send');
  }, [finalizeVoiceRecording]);

  useEffect(
    () => () => {
      voiceUploadAbortControllerRef.current?.abort();
      if (voiceMediaRecorderRef.current?.state && voiceMediaRecorderRef.current.state !== 'inactive') {
        voiceMediaRecorderRef.current.stop();
      }
      voiceStreamRef.current?.getTracks().forEach((track) => track.stop());
    },
    [],
  );

  return {
    voiceRecorder,
    voiceActive: voiceRecorder != null,
    startVoiceRecording: handleVoiceStart,
    completeVoiceRecording,
    cancelVoiceRecording,
    sendVoiceRecording,
  };
}
