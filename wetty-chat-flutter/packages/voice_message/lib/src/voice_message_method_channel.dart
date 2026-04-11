import 'package:flutter/services.dart';

import 'voice_message_platform_interface.dart';

/// Method channel implementation of [VoiceMessagePlatform].
class MethodChannelVoiceMessage extends VoiceMessagePlatform {
  final _channel = const MethodChannel('voice_message');

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
}
