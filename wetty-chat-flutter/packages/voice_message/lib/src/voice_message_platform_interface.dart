import 'package:flutter/foundation.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'voice_message_method_channel.dart';

class VoiceMessageCapabilities {
  const VoiceMessageCapabilities({
    required this.canConvertOggToM4a,
    required this.canConvertM4aToOgg,
    required this.canExtractWaveform,
    required this.canPreparePlayback,
  });

  final bool canConvertOggToM4a;
  final bool canConvertM4aToOgg;
  final bool canExtractWaveform;
  final bool canPreparePlayback;

  bool get isAnyOperationSupported =>
      canConvertOggToM4a ||
      canConvertM4aToOgg ||
      canExtractWaveform ||
      canPreparePlayback;
}

enum VoiceMessagePlaybackPreparation {
  passthrough,
  convertOggOpusToM4a,
  unsupported,
}

class VoiceMessagePreparedPlaybackFile {
  const VoiceMessagePreparedPlaybackFile({
    required this.path,
    required this.isTranscoded,
  });

  final String path;
  final bool isTranscoded;
}

class VoiceMessageUnsupportedException implements Exception {
  const VoiceMessageUnsupportedException(this.operation);

  final String operation;

  @override
  String toString() => 'VoiceMessageUnsupportedException: $operation';
}

/// Public API for the voice_message plugin.
///
/// Provides static methods for OGG/Opus transcoding and waveform extraction.
class VoiceMessage {
  VoiceMessage._();

  static VoiceMessageCapabilities get capabilities =>
      VoiceMessagePlatform.instance.capabilities;

  static VoiceMessagePlaybackPreparation playbackPreparationFor({
    String? contentType,
    String? fileName,
    String? urlPath,
  }) => VoiceMessagePlatform.instance.playbackPreparationFor(
    contentType: contentType,
    fileName: fileName,
    urlPath: urlPath,
  );

  static Future<VoiceMessagePreparedPlaybackFile?> preparePlaybackFile({
    required String inputPath,
    required String outputPath,
    String? contentType,
    String? fileName,
    String? urlPath,
  }) => VoiceMessagePlatform.instance.preparePlaybackFile(
    inputPath: inputPath,
    outputPath: outputPath,
    contentType: contentType,
    fileName: fileName,
    urlPath: urlPath,
  );

  /// Convert an OGG/Opus file to M4A/AAC.
  static Future<void> convertOggToM4a({
    required String srcPath,
    required String destPath,
  }) => VoiceMessagePlatform.instance.convertOggToM4a(
    srcPath: srcPath,
    destPath: destPath,
  );

  /// Convert an M4A/AAC file to OGG/Opus.
  static Future<void> convertM4aToOgg({
    required String srcPath,
    required String destPath,
  }) => VoiceMessagePlatform.instance.convertM4aToOgg(
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
  }) => VoiceMessagePlatform.instance.extractWaveform(
    path: path,
    samplesCount: samplesCount,
  );

  static Future<List<int>?> tryExtractWaveform({
    required String path,
    int samplesCount = 35,
  }) => VoiceMessagePlatform.instance.tryExtractWaveform(
    path: path,
    samplesCount: samplesCount,
  );
}

/// Platform interface for the voice_message plugin.
abstract class VoiceMessagePlatform extends PlatformInterface {
  VoiceMessagePlatform() : super(token: _token);

  static final Object _token = Object();

  static VoiceMessagePlatform _instance = createDefaultPlatform();

  @visibleForTesting
  static VoiceMessagePlatform createDefaultPlatform({
    TargetPlatform? targetPlatform,
    bool isWeb = kIsWeb,
  }) {
    if (isWeb) {
      return UnsupportedVoiceMessagePlatform();
    }
    final target = targetPlatform ?? defaultTargetPlatform;
    return switch (target) {
      TargetPlatform.iOS || TargetPlatform.macOS => MethodChannelVoiceMessage(),
      _ => UnsupportedVoiceMessagePlatform(),
    };
  }

  static VoiceMessagePlatform get instance => _instance;

  static set instance(VoiceMessagePlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  VoiceMessageCapabilities get capabilities;

  VoiceMessagePlaybackPreparation playbackPreparationFor({
    String? contentType,
    String? fileName,
    String? urlPath,
  });

  Future<VoiceMessagePreparedPlaybackFile?> preparePlaybackFile({
    required String inputPath,
    required String outputPath,
    String? contentType,
    String? fileName,
    String? urlPath,
  }) async {
    return switch (playbackPreparationFor(
      contentType: contentType,
      fileName: fileName,
      urlPath: urlPath,
    )) {
      VoiceMessagePlaybackPreparation.passthrough =>
        VoiceMessagePreparedPlaybackFile(path: inputPath, isTranscoded: false),
      VoiceMessagePlaybackPreparation.convertOggOpusToM4a =>
        await _convertOggOpusPlaybackFile(
          inputPath: inputPath,
          outputPath: outputPath,
        ),
      VoiceMessagePlaybackPreparation.unsupported => null,
    };
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

  Future<List<int>?> tryExtractWaveform({
    required String path,
    int samplesCount = 35,
  }) async {
    if (!capabilities.canExtractWaveform) {
      return null;
    }
    final samples = await extractWaveform(
      path: path,
      samplesCount: samplesCount,
    );
    return samples.isEmpty ? null : samples;
  }

  Future<VoiceMessagePreparedPlaybackFile?> _convertOggOpusPlaybackFile({
    required String inputPath,
    required String outputPath,
  }) async {
    if (!capabilities.canConvertOggToM4a) {
      return null;
    }
    await convertOggToM4a(srcPath: inputPath, destPath: outputPath);
    return VoiceMessagePreparedPlaybackFile(
      path: outputPath,
      isTranscoded: true,
    );
  }
}

class UnsupportedVoiceMessagePlatform extends VoiceMessagePlatform {
  @override
  VoiceMessageCapabilities get capabilities => const VoiceMessageCapabilities(
    canConvertOggToM4a: false,
    canConvertM4aToOgg: false,
    canExtractWaveform: false,
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
  }) async {
    throw const VoiceMessageUnsupportedException('convertOggToM4a');
  }

  @override
  Future<void> convertM4aToOgg({
    required String srcPath,
    required String destPath,
  }) async {
    throw const VoiceMessageUnsupportedException('convertM4aToOgg');
  }

  @override
  Future<List<int>> extractWaveform({
    required String path,
    int samplesCount = 35,
  }) async {
    throw const VoiceMessageUnsupportedException('extractWaveform');
  }
}
