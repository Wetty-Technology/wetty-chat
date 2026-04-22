import 'dart:async';

import 'package:chahua/features/chats/conversation/data/audio_playback_driver.dart';
import 'package:chahua/features/chats/conversation_v2/data/audio_source_resolver_service.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VoiceMessagePlaybackPhaseV2 {
  idle,
  loading,
  ready,
  playing,
  paused,
  completed,
  error,
}

class VoiceMessagePlaybackStateV2 {
  const VoiceMessagePlaybackStateV2({
    this.activeAttachmentId,
    this.phase = VoiceMessagePlaybackPhaseV2.idle,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration,
    this.errorMessage,
    this.cachedDurations = const <String, Duration>{},
  });

  final String? activeAttachmentId;
  final VoiceMessagePlaybackPhaseV2 phase;
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

  VoiceMessagePlaybackStateV2 copyWith({
    Object? activeAttachmentId = _sentinel,
    VoiceMessagePlaybackPhaseV2? phase,
    Duration? position,
    Duration? bufferedPosition,
    Object? duration = _sentinel,
    Object? errorMessage = _sentinel,
    Map<String, Duration>? cachedDurations,
  }) {
    return VoiceMessagePlaybackStateV2(
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

class VoiceMessagePlaybackControllerV2
    extends Notifier<VoiceMessagePlaybackStateV2> {
  late final AudioPlaybackDriver _driver;
  late final AudioSourceResolverService _audioSourceResolverService;
  StreamSubscription<AudioPlaybackStatus>? _statusSubscription;

  @override
  VoiceMessagePlaybackStateV2 build() {
    _driver = ref.watch(audioPlaybackDriverProvider);
    _audioSourceResolverService = ref.watch(audioSourceResolverServiceProvider);
    _statusSubscription = _driver.statusStream.listen(_handleStatus);
    ref.onDispose(() {
      unawaited(_statusSubscription?.cancel());
      unawaited(_driver.stop());
    });
    return const VoiceMessagePlaybackStateV2();
  }

  Future<void> togglePlayback(AttachmentItem attachment) async {
    if (state.activeAttachmentId != attachment.id) {
      await _activateAttachment(attachment);
      return;
    }

    switch (state.phase) {
      case VoiceMessagePlaybackPhaseV2.loading:
        return;
      case VoiceMessagePlaybackPhaseV2.playing:
        await _pauseCurrent();
        return;
      case VoiceMessagePlaybackPhaseV2.completed:
        await seekToAttachment(attachment, Duration.zero);
        await _resumeCurrent();
        return;
      case VoiceMessagePlaybackPhaseV2.error:
        await _activateAttachment(attachment);
        return;
      case VoiceMessagePlaybackPhaseV2.idle:
      case VoiceMessagePlaybackPhaseV2.ready:
      case VoiceMessagePlaybackPhaseV2.paused:
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

  Future<void> playFromPosition(
    AttachmentItem attachment,
    Duration position,
  ) async {
    if (attachment.url.isEmpty) {
      return;
    }

    if (state.activeAttachmentId != attachment.id) {
      state = state.copyWith(
        activeAttachmentId: attachment.id,
        phase: VoiceMessagePlaybackPhaseV2.loading,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        duration: attachment.duration ?? state.cachedDurations[attachment.id],
        errorMessage: null,
      );

      try {
        final duration = await _setSourceForAttachment(attachment);
        final effectiveDuration = duration ?? attachment.duration;
        if (effectiveDuration != null) {
          _cacheDuration(attachment.id, effectiveDuration);
        }
        final target = effectiveDuration == null
            ? position
            : _clampDuration(position, Duration.zero, effectiveDuration);
        await _driver.seek(target);
        await _driver.play();
        state = state.copyWith(position: target, errorMessage: null);
      } catch (error) {
        _setPlaybackError(error);
      }
      return;
    }

    await seekToAttachment(attachment, position);
    await _resumeCurrent();
  }

  Future<void> _activateAttachment(AttachmentItem attachment) async {
    state = state.copyWith(
      activeAttachmentId: attachment.id,
      phase: VoiceMessagePlaybackPhaseV2.loading,
      position: Duration.zero,
      bufferedPosition: Duration.zero,
      duration: attachment.duration ?? state.cachedDurations[attachment.id],
      errorMessage: null,
    );

    try {
      final duration = await _setSourceForAttachment(attachment);
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

  Future<Duration?> _setSourceForAttachment(AttachmentItem attachment) async {
    final source = await _audioSourceResolverService.resolvePlaybackSource(
      attachment,
    );
    if (source == null) {
      throw StateError('Unable to resolve playable audio source.');
    }

    if (source.isFile) {
      return _driver.setSourceFilePath(source.filePath!);
    }
    return _driver.setSourceUrl(source.url!);
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
      AudioPlaybackDriverPhase.buffering => VoiceMessagePlaybackPhaseV2.loading,
      AudioPlaybackDriverPhase.completed =>
        VoiceMessagePlaybackPhaseV2.completed,
      AudioPlaybackDriverPhase.ready =>
        status.isPlaying
            ? VoiceMessagePlaybackPhaseV2.playing
            : state.phase == VoiceMessagePlaybackPhaseV2.loading &&
                  status.position == Duration.zero
            ? VoiceMessagePlaybackPhaseV2.ready
            : VoiceMessagePlaybackPhaseV2.paused,
      AudioPlaybackDriverPhase.idle =>
        state.phase == VoiceMessagePlaybackPhaseV2.loading
            ? VoiceMessagePlaybackPhaseV2.loading
            : VoiceMessagePlaybackPhaseV2.paused,
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
    state = state.copyWith(
      duration: duration,
      cachedDurations: {...state.cachedDurations, attachmentId: duration},
    );
  }

  void _setPlaybackError(Object error) {
    state = state.copyWith(
      phase: VoiceMessagePlaybackPhaseV2.error,
      errorMessage: error.toString(),
    );
  }
}

final voiceMessagePlaybackControllerV2Provider =
    NotifierProvider<
      VoiceMessagePlaybackControllerV2,
      VoiceMessagePlaybackStateV2
    >(VoiceMessagePlaybackControllerV2.new);

const _sentinel = Object();

Duration _clampDuration(Duration value, Duration min, Duration max) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}
