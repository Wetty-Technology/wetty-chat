import 'dart:io';
import 'dart:typed_data';

import 'package:chahua/core/cache/media_cache_service.dart';
import 'package:chahua/features/audio/application/audio_source_resolver_service.dart';
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

  test('returns null for empty attachment urls', () async {
    final harness = _createHarness('audio-source-empty-url');

    final source = await harness.service.resolvePlaybackSource(
      const AttachmentItem(
        id: 'audio-1',
        url: '',
        kind: 'audio/ogg',
        size: 0,
        fileName: 'audio-1.ogg',
      ),
    );

    expect(source, isNull);
  });

  test('returns original cached file for passthrough preparation', () async {
    VoiceMessagePlatform.instance = _FakeVoiceMessagePlatform(
      preparation: VoiceMessagePlaybackPreparation.passthrough,
    );
    final harness = _createHarness('audio-source-passthrough');
    const attachment = AttachmentItem(
      id: 'audio-pass',
      url: 'https://example.com/audio-pass.m4a',
      kind: 'audio/mp4',
      size: 4,
      fileName: 'audio-pass.m4a',
    );
    final original = await _putOriginal(harness, attachment, <int>[1, 2, 3, 4]);

    final source = await harness.service.resolvePlaybackSource(attachment);

    expect(source, isNotNull);
    expect(source!.filePath, original.path);
    expect(source.localWaveformPath, original.path);
  });

  test(
    'returns derived file when package prepares playback transcode',
    () async {
      VoiceMessagePlatform.instance = _FakeVoiceMessagePlatform(
        preparation: VoiceMessagePlaybackPreparation.convertOggOpusToM4a,
        convertedBytes: const <int>[9, 8, 7, 6],
      );
      final harness = _createHarness('audio-source-derived');
      const attachment = AttachmentItem(
        id: 'audio-derived',
        url: 'https://example.com/audio-derived.ogg',
        kind: 'audio/ogg',
        size: 4,
        fileName: 'audio-derived.ogg',
      );
      await _putOriginal(harness, attachment, <int>[1, 2, 3, 4]);

      final source = await harness.service.resolvePlaybackSource(attachment);

      expect(source, isNotNull);
      expect(source!.filePath, endsWith('.m4a'));
      expect(await File(source.filePath!).readAsBytes(), <int>[9, 8, 7, 6]);
    },
  );

  test(
    'returns null when required playback preparation is unsupported',
    () async {
      VoiceMessagePlatform.instance = _FakeVoiceMessagePlatform(
        preparation: VoiceMessagePlaybackPreparation.unsupported,
      );
      final harness = _createHarness('audio-source-unsupported');
      const attachment = AttachmentItem(
        id: 'audio-unsupported',
        url: 'https://example.com/audio-unsupported.ogg',
        kind: 'audio/ogg',
        size: 4,
        fileName: 'audio-unsupported.ogg',
      );

      final source = await harness.service.resolvePlaybackSource(attachment);

      expect(source, isNull);
    },
  );
}

_ServiceHarness _createHarness(String namespace) {
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
  return _ServiceHarness(
    mediaCacheService: mediaCacheService,
    cacheManager: cacheManager,
    service: AudioSourceResolverService(mediaCacheService),
  );
}

Future<File> _putOriginal(
  _ServiceHarness harness,
  AttachmentItem attachment,
  List<int> bytes,
) async {
  final service = harness.mediaCacheService;
  final cacheKey = service.cacheKeyForAttachment(attachment);
  return harness.cacheManager.putFile(
    service.originalKey(cacheKey),
    Uint8List.fromList(bytes),
    key: service.originalKey(cacheKey),
    fileExtension: 'audio',
  );
}

class _ServiceHarness {
  const _ServiceHarness({
    required this.mediaCacheService,
    required this.cacheManager,
    required this.service,
  });

  final MediaCacheService mediaCacheService;
  final CacheManager cacheManager;
  final AudioSourceResolverService service;
}

class _FakeVoiceMessagePlatform extends VoiceMessagePlatform {
  _FakeVoiceMessagePlatform({
    required this.preparation,
    this.convertedBytes = const <int>[1],
  });

  final VoiceMessagePlaybackPreparation preparation;
  final List<int> convertedBytes;

  @override
  VoiceMessageCapabilities get capabilities => const VoiceMessageCapabilities(
    canConvertOggToM4a: true,
    canConvertM4aToOgg: false,
    canExtractWaveform: false,
    canPreparePlayback: true,
  );

  @override
  VoiceMessagePlaybackPreparation playbackPreparationFor({
    String? contentType,
    String? fileName,
    String? urlPath,
  }) => preparation;

  @override
  Future<void> convertOggToM4a({
    required String srcPath,
    required String destPath,
  }) async {
    await File(destPath).writeAsBytes(convertedBytes);
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
  }) async => const <int>[];
}
