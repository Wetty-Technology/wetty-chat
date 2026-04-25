import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:chahua/core/cache/media_cache_service.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_message/voice_message.dart';

import 'audio_source_resolver_service.dart';

class AudioWaveformSnapshot {
  const AudioWaveformSnapshot({required this.duration, required this.samples});

  final Duration? duration;
  final List<int> samples;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (duration != null) 'durationMs': duration!.inMilliseconds,
    'samples': samples,
  };

  static AudioWaveformSnapshot? fromJson(Map<String, dynamic> json) {
    final durationMs = json['durationMs'];
    final samples = json['samples'];
    if (samples is! List) {
      return null;
    }
    final normalizedSamples = AudioWaveformCacheService.normalizeSampleCount(
      samples.whereType<num>().map((sample) => sample.toInt()).toList(),
    );
    if (normalizedSamples.isEmpty) {
      return null;
    }
    return AudioWaveformSnapshot(
      duration: durationMs is int ? Duration(milliseconds: durationMs) : null,
      samples: normalizedSamples,
    );
  }
}

class AudioWaveformCacheService {
  AudioWaveformCacheService(
    this._mediaCacheService,
    this._audioSourceResolverService,
  );

  static const int targetBarCount = 35;

  final MediaCacheService _mediaCacheService;
  final AudioSourceResolverService _audioSourceResolverService;
  final Map<String, AudioWaveformSnapshot> _memoryCache =
      <String, AudioWaveformSnapshot>{};
  final Map<String, Future<AudioWaveformSnapshot?>> _inFlight =
      <String, Future<AudioWaveformSnapshot?>>{};

  Future<AudioWaveformSnapshot?> resolveForAttachment(
    AttachmentItem attachment, {
    Duration? preferredDuration,
    String? waveformInputPath,
  }) async {
    final cacheKey = _cacheKeyForAttachment(attachment);
    final immediate = _snapshotFromAttachment(attachment, preferredDuration);
    if (immediate != null) {
      await _store(cacheKey, immediate);
      return immediate;
    }

    final cached = _memoryCache[cacheKey] ?? await _restore(cacheKey);
    if (cached != null) {
      final hydrated = _withPreferredDuration(cached, preferredDuration);
      _memoryCache[cacheKey] = hydrated;
      if (hydrated.duration != cached.duration) {
        await _store(cacheKey, hydrated);
      }
      return hydrated;
    }

    final existing = _inFlight[cacheKey];
    if (existing != null) {
      return existing;
    }

    final future = _extractAndCache(
      attachment,
      cacheKey,
      preferredDuration: preferredDuration,
      waveformInputPath: waveformInputPath,
    );
    _inFlight[cacheKey] = future;
    future.whenComplete(() {
      _inFlight.remove(cacheKey);
    });
    return future;
  }

  Future<AudioWaveformSnapshot?> primeFromLocalRecording({
    required String attachmentId,
    required String audioFilePath,
    required Duration duration,
  }) async {
    final cacheKey = _mediaCacheService.cacheKeyForAttachmentId(attachmentId);
    final snapshot = await _extractFromFile(
      audioFilePath: audioFilePath,
      duration: duration,
    );
    if (snapshot != null) {
      await _store(cacheKey, snapshot);
    }
    return snapshot;
  }

  Future<AudioWaveformSnapshot?> primeFromAttachmentMetadata({
    required String attachmentId,
    required Duration duration,
    required List<int> samples,
  }) async {
    final cacheKey = _mediaCacheService.cacheKeyForAttachmentId(attachmentId);
    final normalizedSamples = normalizeSampleCount(samples);
    if (normalizedSamples.isEmpty) {
      return null;
    }

    final snapshot = AudioWaveformSnapshot(
      duration: duration,
      samples: normalizedSamples,
    );
    await _store(cacheKey, snapshot);
    return snapshot;
  }

  AudioWaveformSnapshot? _snapshotFromAttachment(
    AttachmentItem attachment,
    Duration? preferredDuration,
  ) {
    final duration = attachment.duration ?? preferredDuration;
    final samples = attachment.waveformSamples;
    if (samples == null || samples.isEmpty) {
      return null;
    }
    return AudioWaveformSnapshot(
      duration: duration,
      samples: normalizeSampleCount(samples),
    );
  }

  Future<AudioWaveformSnapshot?> _restore(String cacheKey) async {
    final raw = await _mediaCacheService.getJsonSidecar(
      _mediaCacheService.sidecarKey(cacheKey, 'waveform'),
    );
    if (raw == null) {
      return null;
    }
    try {
      return AudioWaveformSnapshot.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _store(String cacheKey, AudioWaveformSnapshot snapshot) async {
    _memoryCache[cacheKey] = snapshot;
    await _mediaCacheService.putJsonSidecar(
      key: _mediaCacheService.sidecarKey(cacheKey, 'waveform'),
      json: snapshot.toJson(),
    );
  }

  Future<AudioWaveformSnapshot?> _extractAndCache(
    AttachmentItem attachment,
    String cacheKey, {
    required Duration? preferredDuration,
    String? waveformInputPath,
  }) async {
    final resolvedWaveformInputPath =
        waveformInputPath ??
        await _audioSourceResolverService.resolveWaveformInputPath(attachment);
    if (resolvedWaveformInputPath == null ||
        resolvedWaveformInputPath.isEmpty) {
      return null;
    }

    try {
      final snapshot = await _extractFromFile(
        audioFilePath: resolvedWaveformInputPath,
        duration: attachment.duration ?? preferredDuration,
      );
      if (snapshot != null) {
        await _store(cacheKey, snapshot);
      }
      return snapshot;
    } catch (error, stackTrace) {
      log(
        'Waveform extraction failed for ${attachment.id}',
        name: 'AudioWaveformCacheService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<AudioWaveformSnapshot?> _extractFromFile({
    required String audioFilePath,
    Duration? duration,
  }) async {
    final samples = await VoiceMessage.extractWaveform(
      path: audioFilePath,
      samplesCount: targetBarCount,
    );
    if (samples.isEmpty) {
      return null;
    }

    return AudioWaveformSnapshot(duration: duration, samples: samples);
  }

  AudioWaveformSnapshot _withPreferredDuration(
    AudioWaveformSnapshot snapshot,
    Duration? preferredDuration,
  ) {
    if (preferredDuration == null || snapshot.duration == preferredDuration) {
      return snapshot;
    }
    if (snapshot.duration != null && snapshot.duration! > Duration.zero) {
      return snapshot;
    }
    return AudioWaveformSnapshot(
      duration: preferredDuration,
      samples: snapshot.samples,
    );
  }

  static List<int> normalizeSampleCount(List<int> samples) {
    final cleaned = samples
        .map((sample) => sample.clamp(0, 255))
        .cast<int>()
        .toList(growable: false);
    if (cleaned.isEmpty) {
      return const <int>[];
    }
    if (cleaned.length == targetBarCount) {
      return cleaned;
    }

    return List<int>.generate(targetBarCount, (index) {
      final start = (index * cleaned.length / targetBarCount).floor();
      final end = math.max(
        start + 1,
        ((index + 1) * cleaned.length / targetBarCount).ceil(),
      );
      var peak = 0;
      for (var sampleIndex = start; sampleIndex < end; sampleIndex++) {
        peak = math.max(peak, cleaned[sampleIndex]);
      }
      return peak;
    }, growable: false);
  }

  String _cacheKeyForAttachment(AttachmentItem attachment) {
    return _mediaCacheService.cacheKeyForAttachment(attachment);
  }

  void clearMemory() {
    _memoryCache.clear();
    _inFlight.clear();
  }
}

final audioWaveformCacheServiceProvider = Provider<AudioWaveformCacheService>((
  ref,
) {
  return AudioWaveformCacheService(
    ref.watch(mediaCacheServiceProvider),
    ref.watch(audioSourceResolverServiceProvider),
  );
});
