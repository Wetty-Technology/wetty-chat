import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;

import 'package:just_waveform/just_waveform.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_preferences_provider.dart';
import '../../models/message_models.dart';
import 'audio_source_resolver_service.dart';

class AudioWaveformSnapshot {
  const AudioWaveformSnapshot({required this.duration, required this.samples});

  final Duration duration;
  final List<int> samples;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'durationMs': duration.inMilliseconds,
    'samples': samples,
  };

  static AudioWaveformSnapshot? fromJson(Map<String, dynamic> json) {
    final durationMs = json['durationMs'];
    final samples = json['samples'];
    if (durationMs is! int || samples is! List) {
      return null;
    }
    final normalizedSamples = AudioWaveformCacheService.normalizeSampleCount(
      samples.whereType<num>().map((sample) => sample.toInt()).toList(),
    );
    if (normalizedSamples.isEmpty) {
      return null;
    }
    return AudioWaveformSnapshot(
      duration: Duration(milliseconds: durationMs),
      samples: normalizedSamples,
    );
  }
}

class AudioWaveformCacheService {
  AudioWaveformCacheService(
    this._preferences,
    this._audioSourceResolverService,
  );

  static const String _cachePrefix = 'voice_waveform:v2:';
  static const int targetBarCount = 35;

  final SharedPreferences _preferences;
  final AudioSourceResolverService _audioSourceResolverService;
  final Map<String, AudioWaveformSnapshot> _memoryCache =
      <String, AudioWaveformSnapshot>{};
  final Map<String, Future<AudioWaveformSnapshot?>> _inFlight =
      <String, Future<AudioWaveformSnapshot?>>{};

  Future<AudioWaveformSnapshot?> resolveForAttachment(
    AttachmentItem attachment,
  ) {
    final cacheKey = _cacheKeyForAttachment(attachment);
    final immediate = _snapshotFromAttachment(attachment);
    if (immediate != null) {
      _store(cacheKey, immediate);
      return Future<AudioWaveformSnapshot?>.value(immediate);
    }

    final cached = _memoryCache[cacheKey] ?? _restore(cacheKey);
    if (cached != null) {
      _memoryCache[cacheKey] = cached;
      return Future<AudioWaveformSnapshot?>.value(cached);
    }

    final existing = _inFlight[cacheKey];
    if (existing != null) {
      return existing;
    }

    final future = _extractAndCache(attachment, cacheKey);
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
    final snapshot = await _extractFromFile(
      audioFilePath: audioFilePath,
      duration: duration,
    );
    if (snapshot != null) {
      _store(attachmentId, snapshot);
    }
    return snapshot;
  }

  AudioWaveformSnapshot? _snapshotFromAttachment(AttachmentItem attachment) {
    final duration = attachment.duration;
    final samples = attachment.waveformSamples;
    if (duration == null || samples == null || samples.isEmpty) {
      return null;
    }
    return AudioWaveformSnapshot(
      duration: duration,
      samples: normalizeSampleCount(samples),
    );
  }

  AudioWaveformSnapshot? _restore(String cacheKey) {
    final raw = _preferences.getString('$_cachePrefix$cacheKey');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return AudioWaveformSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  void _store(String cacheKey, AudioWaveformSnapshot snapshot) {
    _memoryCache[cacheKey] = snapshot;
    _preferences.setString(
      '$_cachePrefix$cacheKey',
      jsonEncode(snapshot.toJson()),
    );
  }

  Future<AudioWaveformSnapshot?> _extractAndCache(
    AttachmentItem attachment,
    String cacheKey,
  ) async {
    final waveformInputPath = await _audioSourceResolverService
        .resolveWaveformInputPath(attachment);
    if (waveformInputPath == null || waveformInputPath.isEmpty) {
      return null;
    }

    try {
      final knownDuration = attachment.duration;
      final snapshot = await _extractFromFile(
        audioFilePath: waveformInputPath,
        duration: knownDuration,
      );
      if (snapshot != null) {
        _store(cacheKey, snapshot);
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
    final tempDirectory = await getTemporaryDirectory();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final waveformFile = File('${tempDirectory.path}/voice-$timestamp.wave');

    try {
      Waveform? waveform;
      await for (final progress in JustWaveform.extract(
        audioInFile: File(audioFilePath),
        waveOutFile: waveformFile,
        zoom: const WaveformZoom.pixelsPerSecond(96),
      )) {
        waveform = progress.waveform ?? waveform;
      }

      if (waveform == null || waveform.length <= 0) {
        return null;
      }

      final resolvedDuration = duration ?? waveform.duration;
      final samples = _compressWaveform(waveform: waveform);
      if (samples.isEmpty) {
        return null;
      }

      return AudioWaveformSnapshot(
        duration: resolvedDuration,
        samples: samples,
      );
    } finally {
      if (await waveformFile.exists()) {
        await waveformFile.delete();
      }
    }
  }

  List<int> _compressWaveform({required Waveform waveform}) {
    final maxAmplitude = waveform.flags == 0 ? 32767.0 : 127.0;

    return normalizeSampleCount(
      List<int>.generate(targetBarCount, (index) {
        final start = (index * waveform.length / targetBarCount).floor();
        final end = math.max(
          start + 1,
          ((index + 1) * waveform.length / targetBarCount).ceil(),
        );

        var peak = 0;
        for (var pixelIndex = start; pixelIndex < end; pixelIndex++) {
          final minSample = waveform.getPixelMin(pixelIndex).abs();
          final maxSample = waveform.getPixelMax(pixelIndex).abs();
          peak = math.max(peak, math.max(minSample, maxSample));
        }

        return ((peak / maxAmplitude) * 255).round().clamp(0, 255);
      }),
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
    if (attachment.id.isNotEmpty) {
      return attachment.id;
    }
    return attachment.url;
  }
}

final audioWaveformCacheServiceProvider = Provider<AudioWaveformCacheService>((
  ref,
) {
  return AudioWaveformCacheService(
    ref.watch(sharedPreferencesProvider),
    ref.watch(audioSourceResolverServiceProvider),
  );
});
