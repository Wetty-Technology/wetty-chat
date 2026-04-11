import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'voice_message_method_channel.dart';

/// Public API for the voice_message plugin.
///
/// Provides static methods for OGG/Opus transcoding and waveform extraction.
class VoiceMessage {
  VoiceMessage._();

  /// Convert an OGG/Opus file to M4A/AAC.
  static Future<void> convertOggToM4a({
    required String srcPath,
    required String destPath,
  }) =>
      VoiceMessagePlatform.instance.convertOggToM4a(
        srcPath: srcPath,
        destPath: destPath,
      );

  /// Convert an M4A/AAC file to OGG/Opus.
  static Future<void> convertM4aToOgg({
    required String srcPath,
    required String destPath,
  }) =>
      VoiceMessagePlatform.instance.convertM4aToOgg(
        srcPath: srcPath,
        destPath: destPath,
      );

  /// Extract waveform from an audio file as normalized peak amplitudes (0–255).
  ///
  /// Supports M4A, AAC, MP3, WAV (via AVAudioFile) and OGG (via OGGDecoder).
  /// Returns [samplesCount] values, each in range 0–255.
  static Future<List<int>> extractWaveform({
    required String path,
    int samplesCount = 35,
  }) =>
      VoiceMessagePlatform.instance.extractWaveform(
        path: path,
        samplesCount: samplesCount,
      );
}

/// Platform interface for the voice_message plugin.
abstract class VoiceMessagePlatform extends PlatformInterface {
  VoiceMessagePlatform() : super(token: _token);

  static final Object _token = Object();

  static VoiceMessagePlatform _instance = MethodChannelVoiceMessage();

  static VoiceMessagePlatform get instance => _instance;

  static set instance(VoiceMessagePlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  Future<void> convertOggToM4a({
    required String srcPath,
    required String destPath,
  });

  Future<void> convertM4aToOgg({
    required String srcPath,
    required String destPath,
  });

  Future<List<int>> extractWaveform({
    required String path,
    int samplesCount = 35,
  });
}
