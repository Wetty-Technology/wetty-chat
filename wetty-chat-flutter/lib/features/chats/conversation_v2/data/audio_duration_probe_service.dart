import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/cache/media_cache_service.dart';
import '../../models/message_models.dart';
import 'audio_source_resolver_service.dart';

class AudioDurationProbeService {
  AudioDurationProbeService(this._mediaCacheService);

  final MediaCacheService _mediaCacheService;
  final Map<String, Duration> _memoryCache = <String, Duration>{};
  final Map<String, Future<Duration?>> _inFlight =
      <String, Future<Duration?>>{};

  Future<Duration?> resolveForAttachment(
    AttachmentItem attachment, {
    AudioPlaybackSource? source,
  }) async {
    if (attachment.duration != null && attachment.duration! > Duration.zero) {
      return attachment.duration;
    }

    final cacheKey = _mediaCacheService.cacheKeyForAttachment(attachment);
    final memoryDuration = _memoryCache[cacheKey];
    if (memoryDuration != null) {
      return memoryDuration;
    }

    final restored = await _restore(cacheKey);
    if (restored != null) {
      _memoryCache[cacheKey] = restored;
      return restored;
    }

    final existing = _inFlight[cacheKey];
    if (existing != null) {
      return existing;
    }

    if (source == null) {
      return null;
    }

    final future = _probeAndStore(cacheKey, source);
    _inFlight[cacheKey] = future;
    return future.whenComplete(() {
      _inFlight.remove(cacheKey);
    });
  }

  Future<Duration?> _probeAndStore(
    String cacheKey,
    AudioPlaybackSource source,
  ) async {
    if (source.filePath == null && source.url == null) {
      return null;
    }

    final player = AudioPlayer();
    try {
      final duration = source.isFile
          ? await player.setFilePath(source.filePath!)
          : await player.setUrl(source.url!);
      if (duration != null && duration > Duration.zero) {
        _memoryCache[cacheKey] = duration;
        await _mediaCacheService.putJsonSidecar(
          key: _mediaCacheService.sidecarKey(cacheKey, 'duration'),
          json: <String, dynamic>{'durationMs': duration.inMilliseconds},
        );
      }
      return duration;
    } catch (error, stackTrace) {
      log(
        'Audio duration probe failed for $cacheKey',
        name: 'AudioDurationProbeService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      await player.dispose();
    }
  }

  Future<Duration?> _restore(String cacheKey) async {
    final raw = await _mediaCacheService.getJsonSidecar(
      _mediaCacheService.sidecarKey(cacheKey, 'duration'),
    );
    final durationMs = raw?['durationMs'];
    if (durationMs is! int || durationMs <= 0) {
      return null;
    }
    return Duration(milliseconds: durationMs);
  }

  void clearMemory() {
    _memoryCache.clear();
    _inFlight.clear();
  }
}

final audioDurationProbeServiceProvider = Provider<AudioDurationProbeService>((
  ref,
) {
  return AudioDurationProbeService(ref.watch(mediaCacheServiceProvider));
});
