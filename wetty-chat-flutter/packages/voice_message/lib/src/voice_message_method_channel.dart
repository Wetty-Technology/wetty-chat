import 'package:flutter/services.dart';

import 'voice_message_platform_interface.dart';

/// Method channel implementation of [VoiceMessagePlatform].
class MethodChannelVoiceMessage extends VoiceMessagePlatform {
  final _channel = const MethodChannel('voice_message');

  @override
  VoiceMessageCapabilities get capabilities => const VoiceMessageCapabilities(
    canConvertOggToM4a: true,
    canConvertM4aToOgg: true,
    canExtractWaveform: true,
    canPreparePlayback: true,
  );

  @override
  VoiceMessagePlaybackPreparation playbackPreparationFor({
    String? contentType,
    String? fileName,
    String? urlPath,
  }) {
    if (_needsOggOpusToM4aTranscode(
      contentType: contentType,
      fileName: fileName,
      urlPath: urlPath,
    )) {
      return capabilities.canConvertOggToM4a
          ? VoiceMessagePlaybackPreparation.convertOggOpusToM4a
          : VoiceMessagePlaybackPreparation.unsupported;
    }
    return VoiceMessagePlaybackPreparation.passthrough;
  }

  @override
  Future<void> convertOggToM4a({
    required String srcPath,
    required String destPath,
  }) async {
    await _channel.invokeMethod<void>('convertOggToM4a', {
      'srcPath': srcPath,
      'destPath': destPath,
    });
  }

  @override
  Future<void> convertM4aToOgg({
    required String srcPath,
    required String destPath,
  }) async {
    await _channel.invokeMethod<void>('convertM4aToOgg', {
      'srcPath': srcPath,
      'destPath': destPath,
    });
  }

  @override
  Future<List<int>> extractWaveform({
    required String path,
    int samplesCount = 35,
  }) async {
    final result = await _channel.invokeListMethod<int>('extractWaveform', {
      'path': path,
      'samplesCount': samplesCount,
    });
    return result ?? [];
  }

  bool _needsOggOpusToM4aTranscode({
    String? contentType,
    String? fileName,
    String? urlPath,
  }) {
    final normalizedContentType = contentType?.toLowerCase() ?? '';
    final extension = _audioFileExtension(fileName, urlPath);
    if (normalizedContentType.contains('webm') || extension == 'webm') {
      return true;
    }
    if (normalizedContentType.contains('ogg') ||
        normalizedContentType.contains('opus') ||
        extension == 'ogg' ||
        extension == 'oga' ||
        extension == 'opus') {
      return true;
    }
    return false;
  }

  String? _audioFileExtension(String? fileName, String? urlPath) {
    for (final candidate in <String?>[fileName, urlPath]) {
      final trimmed = candidate?.trim().toLowerCase();
      if (trimmed == null || trimmed.isEmpty) {
        continue;
      }
      final dotIndex = trimmed.lastIndexOf('.');
      if (dotIndex == -1 || dotIndex == trimmed.length - 1) {
        continue;
      }
      return trimmed.substring(dotIndex + 1);
    }
    return null;
  }
}
