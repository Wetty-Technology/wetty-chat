import 'package:chahua/core/cache/media_cache_service.dart';
import 'package:chahua/features/audio/application/audio_source_resolver_service.dart';
import 'package:chahua/features/audio/application/audio_waveform_cache_service.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_message/src/voice_message_platform_interface.dart';

import '../../../test_utils/path_provider_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setUpPathProviderMock);
  tearDownAll(tearDownPathProviderMock);

  late VoiceMessagePlatform originalPlatform;

  setUp(() {
    originalPlatform = VoiceMessagePlatform.instance;
  });

  tearDown(() {
    VoiceMessagePlatform.instance = originalPlatform;
  });

  test('uses attachment waveform metadata before local extraction', () async {
    final fakePlatform = _FakeVoiceMessagePlatform(samples: <int>[9, 9, 9]);
    VoiceMessagePlatform.instance = fakePlatform;
    final harness = _createHarness('audio-waveform-metadata');

    final snapshot = await harness.service.resolveForAttachment(
      const AttachmentItem(
        id: 'audio-metadata',
        url: 'https://example.com/audio.ogg',
        kind: 'audio/ogg',
        size: 3,
        fileName: 'audio.ogg',
        waveformSamples: <int>[1, 2, 3],
      ),
      waveformInputPath: '/tmp/audio.ogg',
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.samples.length, AudioWaveformCacheService.targetBarCount);
    expect(fakePlatform.extractCount, 0);
  });

  test(
    'restores and hydrates waveform sidecar with preferred duration',
    () async {
      final harness = _createHarness('audio-waveform-sidecar');
      const attachment = AttachmentItem(
        id: 'audio-sidecar',
        url: 'https://example.com/audio.ogg',
        kind: 'audio/ogg',
        size: 3,
        fileName: 'audio.ogg',
      );
      final cacheKey = harness.mediaCacheService.cacheKeyForAttachment(
        attachment,
      );
      await harness.mediaCacheService.putJsonSidecar(
        key: harness.mediaCacheService.sidecarKey(cacheKey, 'waveform'),
        json: <String, dynamic>{
          'samples': <int>[4, 5, 6],
        },
      );

      final snapshot = await harness.service.resolveForAttachment(
        attachment,
        preferredDuration: const Duration(seconds: 7),
        waveformInputPath: '/tmp/audio.ogg',
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.duration, const Duration(seconds: 7));
      expect(snapshot.samples.length, AudioWaveformCacheService.targetBarCount);
    },
  );

  test(
    'returns null when package waveform extraction is unsupported',
    () async {
      VoiceMessagePlatform.instance = UnsupportedVoiceMessagePlatform();
      final harness = _createHarness('audio-waveform-unsupported');

      final snapshot = await harness.service.resolveForAttachment(
        const AttachmentItem(
          id: 'audio-unsupported-waveform',
          url: 'https://example.com/audio.ogg',
          kind: 'audio/ogg',
          size: 3,
          fileName: 'audio.ogg',
        ),
        waveformInputPath: '/tmp/audio.ogg',
      );

      expect(snapshot, isNull);
    },
  );

  test('shares one in-flight local extraction', () async {
    final fakePlatform = _FakeVoiceMessagePlatform(
      samples: <int>[8, 7, 6],
      delay: const Duration(milliseconds: 20),
    );
    VoiceMessagePlatform.instance = fakePlatform;
    final harness = _createHarness('audio-waveform-inflight');
    const attachment = AttachmentItem(
      id: 'audio-inflight-waveform',
      url: 'https://example.com/audio.ogg',
      kind: 'audio/ogg',
      size: 3,
      fileName: 'audio.ogg',
    );

    final results = await Future.wait([
      harness.service.resolveForAttachment(
        attachment,
        waveformInputPath: '/tmp/audio.ogg',
      ),
      harness.service.resolveForAttachment(
        attachment,
        waveformInputPath: '/tmp/audio.ogg',
      ),
    ]);

    expect(results[0], isNotNull);
    expect(results[1], isNotNull);
    expect(fakePlatform.extractCount, 1);
  });
}

_WaveformHarness _createHarness(String namespace) {
  final cacheManager = CacheManager(
    Config(
      namespace,
      stalePeriod: const Duration(days: 1),
      maxNrOfCacheObjects: 20,
    ),
  );
  final mediaCacheService = MediaCacheService(
    cacheNamespace: namespace,
    cacheManager: cacheManager,
  );
  addTearDown(mediaCacheService.dispose);
  addTearDown(mediaCacheService.clearAll);
  return _WaveformHarness(
    mediaCacheService: mediaCacheService,
    service: AudioWaveformCacheService(
      mediaCacheService,
      AudioSourceResolverService(mediaCacheService),
    ),
  );
}

class _WaveformHarness {
  const _WaveformHarness({
    required this.mediaCacheService,
    required this.service,
  });

  final MediaCacheService mediaCacheService;
  final AudioWaveformCacheService service;
}

class _FakeVoiceMessagePlatform extends VoiceMessagePlatform {
  _FakeVoiceMessagePlatform({
    required this.samples,
    this.delay = Duration.zero,
  });

  final List<int> samples;
  final Duration delay;
  int extractCount = 0;

  @override
  VoiceMessageCapabilities get capabilities => const VoiceMessageCapabilities(
    canConvertOggToM4a: false,
    canConvertM4aToOgg: false,
    canExtractWaveform: true,
    canPreparePlayback: true,
  );

  @override
  VoiceMessagePlaybackPreparation playbackPreparationFor({
    String? contentType,
    String? fileName,
    String? urlPath,
  }) => VoiceMessagePlaybackPreparation.passthrough;

  @override
  Future<void> convertOggToM4a({
    required String srcPath,
    required String destPath,
  }) {
    throw const VoiceMessageUnsupportedException('convertOggToM4a');
  }

  @override
  Future<void> convertM4aToOgg({
    required String srcPath,
    required String destPath,
  }) {
    throw const VoiceMessageUnsupportedException('convertM4aToOgg');
  }

  @override
  Future<List<int>> extractWaveform({
    required String path,
    int samplesCount = 35,
  }) async {
    extractCount += 1;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return samples;
  }
}
