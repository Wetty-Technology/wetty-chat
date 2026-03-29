import { useCallback, useEffect, useRef, useState } from 'react';
import { t } from '@lingui/core/macro';
import type { ComposeSendAudioPayload, ComposeUploadInput, ComposeUploadResult, VoiceRecorderState } from './types';

const VOICE_CANCEL_THRESHOLD_PX = 72;
const VOICE_LOCK_THRESHOLD_PX = 60;
const MIN_VOICE_DURATION_MS = 500;

const isAbortError = (error: unknown) => error instanceof DOMException && error.name === 'AbortError';

const getSupportedVoiceMimeType = () => {
  if (typeof MediaRecorder === 'undefined' || typeof MediaRecorder.isTypeSupported !== 'function') {
    return '';
  }

  const candidates = ['audio/webm;codecs=opus', 'audio/mp4', 'audio/webm', 'audio/ogg;codecs=opus'];
  return candidates.find((candidate) => MediaRecorder.isTypeSupported(candidate)) ?? '';
};

const getVoiceFileExtension = (mimeType: string) => {
  if (mimeType.includes('mp4')) return 'm4a';
  if (mimeType.includes('ogg')) return 'ogg';
  return 'webm';
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
  const voiceGestureRef = useRef<{
    pointerId: number | null;
    startX: number;
    startY: number;
    active: boolean;
    finishAfterStart: 'send' | 'cancel' | null;
  }>({ pointerId: null, startX: 0, startY: 0, active: false, finishAfterStart: null });
  const voiceUploadAbortControllerRef = useRef<AbortController | null>(null);

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

  const resetVoiceGesture = useCallback(() => {
    voiceGestureRef.current = {
      pointerId: null,
      startX: 0,
      startY: 0,
      active: false,
      finishAfterStart: null,
    };
  }, []);

  const resetVoiceRecorder = useCallback(() => {
    voiceUploadAbortControllerRef.current?.abort();
    voiceUploadAbortControllerRef.current = null;
    voiceChunksRef.current = [];
    voiceMediaRecorderRef.current = null;
    stopVoiceStream();
    setVoiceRecorder(null);
    resetVoiceGesture();
  }, [resetVoiceGesture, stopVoiceStream]);

  const finishVoiceRecording = useCallback(
    (mode: 'send' | 'cancel') => {
      const current = voiceRecorderRef.current;
      if (!current) {
        resetVoiceGesture();
        return;
      }

      const recorder = voiceMediaRecorderRef.current;
      if (current.phase === 'requesting') {
        voiceGestureRef.current.finishAfterStart = mode;
        return;
      }

      if (mode === 'cancel') {
        voiceChunksRef.current = [];
      }

      voiceGestureRef.current.active = false;
      voiceGestureRef.current.pointerId = null;
      voiceGestureRef.current.finishAfterStart = null;

      const nextDurationMs = Date.now() - current.startedAt;
      setVoiceRecorder({
        ...current,
        phase: mode === 'send' ? 'uploading' : 'recording',
        durationMs: nextDurationMs,
        cancelArmed: false,
        uploadProgress: 0,
      });

      if (!recorder || recorder.state === 'inactive') {
        if (mode === 'cancel') {
          resetVoiceRecorder();
        }
        return;
      }

      if (mode === 'cancel') {
        recorder.onstop = () => {
          resetVoiceRecorder();
        };
      }

      recorder.stop();
    },
    [resetVoiceGesture, resetVoiceRecorder],
  );

  const startVoiceRecording = useCallback(async () => {
    if (
      typeof navigator === 'undefined' ||
      !navigator.mediaDevices?.getUserMedia ||
      typeof MediaRecorder === 'undefined'
    ) {
      reportVoiceError(t`Voice recording is not supported on this device.`);
      resetVoiceGesture();
      return;
    }

    const requestedAt = Date.now();
    setVoiceRecorder({
      phase: 'requesting',
      startedAt: requestedAt,
      durationMs: 0,
      cancelArmed: false,
      uploadProgress: 0,
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
        voiceMediaRecorderRef.current = null;
        stopVoiceStream();

        if (recordedChunks.length === 0) {
          setVoiceRecorder(null);
          return;
        }

        if (durationMs < MIN_VOICE_DURATION_MS) {
          voiceChunksRef.current = [];
          setVoiceRecorder(null);
          reportVoiceError(t`Recording is too short.`);
          return;
        }

        const blobType = recorder.mimeType || mimeType || 'audio/webm';
        const file = new File([new Blob(recordedChunks, { type: blobType })], `voice-${Date.now()}.${getVoiceFileExtension(blobType)}`, {
          type: blobType,
          lastModified: Date.now(),
        });
        const uploadAbortController = new AbortController();
        voiceUploadAbortControllerRef.current = uploadAbortController;

        setVoiceRecorder({
          phase: 'uploading',
          startedAt,
          durationMs,
          cancelArmed: false,
          uploadProgress: 0,
        });

        try {
          const result = await uploadAttachment({
            file,
            signal: uploadAbortController.signal,
            onProgress: (progress) => {
              setVoiceRecorder((currentVoice) =>
                currentVoice == null
                  ? null
                  : {
                      ...currentVoice,
                      uploadProgress: progress,
                    },
              );
            },
          });

          onSend({
            kind: 'audio',
            durationMs,
            attachmentId: result.attachmentId,
            uploadedAttachment: {
              attachmentId: result.attachmentId,
              file,
              mimeType: blobType,
              size: file.size,
            },
          });
          setVoiceRecorder(null);
        } catch (error) {
          if (!isAbortError(error) && !uploadAbortController.signal.aborted) {
            console.error('Failed to upload voice message:', error);
            reportVoiceError(t`Failed to send voice message.`);
          }
          setVoiceRecorder(null);
        } finally {
          voiceUploadAbortControllerRef.current = null;
          voiceChunksRef.current = [];
        }
      };

      recorder.start();
      setVoiceRecorder({
        phase: 'recording',
        startedAt,
        durationMs: 0,
        cancelArmed: false,
        uploadProgress: 0,
      });

      const deferredFinish = voiceGestureRef.current.finishAfterStart;
      if (deferredFinish) {
        finishVoiceRecording(deferredFinish);
      }
    } catch (error) {
      console.error('Failed to access microphone:', error);
      stopVoiceStream();
      setVoiceRecorder(null);
      resetVoiceGesture();
      reportVoiceError(t`Microphone access was denied.`);
    }
  }, [finishVoiceRecording, onSend, reportVoiceError, resetVoiceGesture, stopVoiceStream, uploadAttachment]);

  useEffect(() => {
    if (!voiceRecorder || (voiceRecorder.phase !== 'recording' && voiceRecorder.phase !== 'locked')) {
      return;
    }

    const timer = window.setInterval(() => {
      setVoiceRecorder((current) =>
        current == null
          ? null
          : {
              ...current,
              durationMs: Date.now() - current.startedAt,
            },
      );
    }, 200);

    return () => window.clearInterval(timer);
  }, [voiceRecorder]);

  const handleVoicePointerDown = useCallback(
    (event: React.PointerEvent<HTMLElement>) => {
      if (!canStartVoice) {
        return;
      }

      event.preventDefault();
      onBeforeStart?.();
      voiceGestureRef.current = {
        pointerId: event.pointerId,
        startX: event.clientX,
        startY: event.clientY,
        active: true,
        finishAfterStart: null,
      };
      void startVoiceRecording();
    },
    [canStartVoice, onBeforeStart, startVoiceRecording],
  );

  useEffect(() => {
    const handlePointerMove = (event: PointerEvent) => {
      const gesture = voiceGestureRef.current;
      const current = voiceRecorderRef.current;
      if (!gesture.active || gesture.pointerId !== event.pointerId || current?.phase !== 'recording') {
        return;
      }

      const deltaX = event.clientX - gesture.startX;
      const deltaY = event.clientY - gesture.startY;

      if (deltaY <= -VOICE_LOCK_THRESHOLD_PX) {
        setVoiceRecorder((voice) =>
          voice == null
            ? null
            : {
                ...voice,
                phase: 'locked',
                cancelArmed: false,
              },
        );
        voiceGestureRef.current.active = false;
        voiceGestureRef.current.pointerId = null;
        return;
      }

      const cancelArmed = deltaX <= -VOICE_CANCEL_THRESHOLD_PX;
      if (cancelArmed !== current.cancelArmed) {
        setVoiceRecorder({
          ...current,
          cancelArmed,
        });
      }
    };

    const handlePointerFinish = (event: PointerEvent) => {
      const gesture = voiceGestureRef.current;
      if (gesture.pointerId == null || gesture.pointerId !== event.pointerId) {
        return;
      }

      const current = voiceRecorderRef.current;
      if (!current) {
        resetVoiceGesture();
        return;
      }

      if (current.phase === 'requesting') {
        voiceGestureRef.current.finishAfterStart = 'cancel';
        return;
      }

      if (current.phase !== 'recording') {
        return;
      }

      finishVoiceRecording(current.cancelArmed ? 'cancel' : 'send');
    };

    window.addEventListener('pointermove', handlePointerMove);
    window.addEventListener('pointerup', handlePointerFinish);
    window.addEventListener('pointercancel', handlePointerFinish);
    return () => {
      window.removeEventListener('pointermove', handlePointerMove);
      window.removeEventListener('pointerup', handlePointerFinish);
      window.removeEventListener('pointercancel', handlePointerFinish);
    };
  }, [finishVoiceRecording, resetVoiceGesture]);

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
    handleVoicePointerDown,
    finishVoiceRecording,
  };
}
