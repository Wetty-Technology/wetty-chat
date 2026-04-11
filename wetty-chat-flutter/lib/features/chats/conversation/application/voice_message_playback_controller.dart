import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/message_models.dart';
import '../data/audio_playback_driver.dart';

enum VoiceMessagePlaybackPhase {
  idle,
  loading,
  ready,
  playing,
  paused,
  completed,
  error,
}

class VoiceMessagePlaybackState {
  const VoiceMessagePlaybackState({
    this.activeAttachmentId,
    this.phase = VoiceMessagePlaybackPhase.idle,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration,
    this.errorMessage,
    this.cachedDurations = const <String, Duration>{},
  });

  final String? activeAttachmentId;
  final VoiceMessagePlaybackPhase phase;
  final Duration position;
  final Duration bufferedPosition;
  final Duration? duration;
  final String? errorMessage;
  final Map<String, Duration> cachedDurations;

  bool isActive(String attachmentId) => activeAttachmentId == attachmentId;

  Duration? durationFor(String attachmentId) {
    if (activeAttachmentId == attachmentId) {
      return duration ?? cachedDurations[attachmentId];
    }
    return cachedDurations[attachmentId];
  }

  VoiceMessagePlaybackState copyWith({
    Object? activeAttachmentId = _sentinel,
    VoiceMessagePlaybackPhase? phase,
    Duration? position,
    Duration? bufferedPosition,
    Object? duration = _sentinel,
    Object? errorMessage = _sentinel,
    Map<String, Duration>? cachedDurations,
  }) {
    return VoiceMessagePlaybackState(
      activeAttachmentId: activeAttachmentId == _sentinel
          ? this.activeAttachmentId
          : activeAttachmentId as String?,
      phase: phase ?? this.phase,
      position: position ?? this.position,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      duration: duration == _sentinel ? this.duration : duration as Duration?,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      cachedDurations: cachedDurations ?? this.cachedDurations,
    );
  }
}

class VoiceMessagePlaybackController
    extends Notifier<VoiceMessagePlaybackState> {
  late final AudioPlaybackDriver _driver;
  StreamSubscription<AudioPlaybackStatus>? _statusSubscription;

  @override
  VoiceMessagePlaybackState build() {
    _driver = ref.watch(audioPlaybackDriverProvider);
    _statusSubscription = _driver.statusStream.listen(_handleStatus);
    ref.onDispose(() {
      unawaited(_statusSubscription?.cancel());
      unawaited(_driver.stop());
    });
    return const VoiceMessagePlaybackState();
  }

  Future<void> togglePlayback(AttachmentItem attachment) async {
    if (state.activeAttachmentId != attachment.id) {
      await _activateAttachment(attachment);
      return;
    }

    switch (state.phase) {
      case VoiceMessagePlaybackPhase.loading:
        return;
      case VoiceMessagePlaybackPhase.playing:
        await _pauseCurrent();
        return;
      case VoiceMessagePlaybackPhase.completed:
        await seekToAttachment(attachment, Duration.zero);
        await _resumeCurrent();
        return;
      case VoiceMessagePlaybackPhase.error:
        await _activateAttachment(attachment);
        return;
      case VoiceMessagePlaybackPhase.idle:
      case VoiceMessagePlaybackPhase.ready:
      case VoiceMessagePlaybackPhase.paused:
        await _resumeCurrent();
        return;
    }
  }

  Future<void> seekToAttachment(
    AttachmentItem attachment,
    Duration position,
  ) async {
    if (state.activeAttachmentId != attachment.id) {
      return;
    }

    final targetDuration = state.durationFor(attachment.id);
    final clampedPosition = targetDuration == null
        ? position
        : _clampDuration(position, Duration.zero, targetDuration);

    try {
      await _driver.seek(clampedPosition);
      state = state.copyWith(position: clampedPosition, errorMessage: null);
    } catch (error) {
      _setPlaybackError(error);
    }
  }

  Future<void> _activateAttachment(AttachmentItem attachment) async {
    state = state.copyWith(
      activeAttachmentId: attachment.id,
      phase: VoiceMessagePlaybackPhase.loading,
      position: Duration.zero,
      bufferedPosition: Duration.zero,
      duration: state.cachedDurations[attachment.id],
      errorMessage: null,
    );

    try {
      final duration = await _driver.setSourceUrl(attachment.url);
      if (duration != null) {
        _cacheDuration(attachment.id, duration);
      }
      await _driver.play();
    } catch (error) {
      _setPlaybackError(error);
    }
  }

  Future<void> _resumeCurrent() async {
    try {
      await _driver.play();
    } catch (error) {
      _setPlaybackError(error);
    }
  }

  Future<void> _pauseCurrent() async {
    try {
      await _driver.pause();
    } catch (error) {
      _setPlaybackError(error);
    }
  }

  void _handleStatus(AudioPlaybackStatus status) {
    final activeAttachmentId = state.activeAttachmentId;
    if (activeAttachmentId == null) {
      return;
    }

    final duration = status.duration;
    if (duration != null) {
      _cacheDuration(activeAttachmentId, duration);
    }

    final nextPhase = switch (status.phase) {
      AudioPlaybackDriverPhase.loading ||
      AudioPlaybackDriverPhase.buffering => VoiceMessagePlaybackPhase.loading,
      AudioPlaybackDriverPhase.completed => VoiceMessagePlaybackPhase.completed,
      AudioPlaybackDriverPhase.ready =>
        status.isPlaying
            ? VoiceMessagePlaybackPhase.playing
            : state.phase == VoiceMessagePlaybackPhase.loading &&
                  status.position == Duration.zero
            ? VoiceMessagePlaybackPhase.ready
            : VoiceMessagePlaybackPhase.paused,
      AudioPlaybackDriverPhase.idle =>
        state.phase == VoiceMessagePlaybackPhase.loading
            ? VoiceMessagePlaybackPhase.loading
            : VoiceMessagePlaybackPhase.paused,
    };

    state = state.copyWith(
      phase: nextPhase,
      position: status.position,
      bufferedPosition: status.bufferedPosition,
      duration: duration ?? state.duration,
      errorMessage: null,
    );
  }

  void _cacheDuration(String attachmentId, Duration duration) {
    final nextDurations = Map<String, Duration>.from(state.cachedDurations);
    nextDurations[attachmentId] = duration;
    state = state.copyWith(
      cachedDurations: nextDurations,
      duration: state.activeAttachmentId == attachmentId
          ? duration
          : state.duration,
    );
  }

  void _setPlaybackError(Object error) {
    state = state.copyWith(
      phase: VoiceMessagePlaybackPhase.error,
      position: Duration.zero,
      bufferedPosition: Duration.zero,
      errorMessage: '$error',
    );
  }
}

final voiceMessagePlaybackControllerProvider =
    NotifierProvider<VoiceMessagePlaybackController, VoiceMessagePlaybackState>(
      VoiceMessagePlaybackController.new,
      isAutoDispose: true,
    );

Duration _clampDuration(Duration value, Duration min, Duration max) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

const _sentinel = Object();
