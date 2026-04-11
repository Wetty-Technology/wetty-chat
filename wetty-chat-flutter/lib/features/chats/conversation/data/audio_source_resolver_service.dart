import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_message/voice_message.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/providers/shared_preferences_provider.dart';
import '../../models/message_models.dart';

class AudioPlaybackSource {
  const AudioPlaybackSource._({
    required this.filePath,
    required this.url,
    required this.localWaveformPath,
  });

  const AudioPlaybackSource.file({
    required String filePath,
    required String localWaveformPath,
  }) : this._(
         filePath: filePath,
         url: null,
         localWaveformPath: localWaveformPath,
       );

  const AudioPlaybackSource.url({
    required String url,
    String? localWaveformPath,
  }) : this._(filePath: null, url: url, localWaveformPath: localWaveformPath);

  final String? filePath;
  final String? url;
  final String? localWaveformPath;

  bool get isFile => filePath != null;
}

class AudioSourceResolverService {
  AudioSourceResolverService(this._dio, this._preferences);

  static const String _preparedFilePrefix = 'prepared_audio_file:';
  static const String _downloadedFilePrefix = 'downloaded_audio_file:';

  final Dio _dio;
  final SharedPreferences _preferences;
  final Map<String, Future<String?>> _preparedInFlight =
      <String, Future<String?>>{};
  final Map<String, Future<String?>> _downloadInFlight =
      <String, Future<String?>>{};

  Future<AudioPlaybackSource?> resolvePlaybackSource(
    AttachmentItem attachment,
  ) async {
    if (attachment.url.isEmpty) {
      return null;
    }

    if (!_requiresTranscode(attachment)) {
      return AudioPlaybackSource.url(url: attachment.url);
    }

    final preparedFilePath = await _resolvePreparedLocalFile(attachment);
    if (preparedFilePath == null) {
      return null;
    }
    return AudioPlaybackSource.file(
      filePath: preparedFilePath,
      localWaveformPath: preparedFilePath,
    );
  }

  Future<String?> resolveWaveformInputPath(AttachmentItem attachment) async {
    if (attachment.url.isEmpty) {
      return null;
    }

    if (_requiresTranscode(attachment)) {
      return _resolvePreparedLocalFile(attachment);
    }

    return _resolveDownloadedLocalFile(attachment);
  }

  bool _requiresTranscode(AttachmentItem attachment) {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return false;
    }
    if (!attachment.isAudio || attachment.url.isEmpty) {
      return false;
    }

    final descriptor = _audioDescriptorForAttachment(attachment);
    return descriptor.contains('webm') ||
        descriptor.contains('ogg') ||
        descriptor.contains('opus');
  }

  Future<String?> _resolvePreparedLocalFile(AttachmentItem attachment) {
    final cacheKey = _cacheKeyForAttachment(attachment);
    final existing = _existingFilePath(_preparedFilePrefix, cacheKey);
    if (existing != null) {
      return Future<String?>.value(existing);
    }

    final inFlight = _preparedInFlight[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _downloadAndTranscode(attachment, cacheKey);
    _preparedInFlight[cacheKey] = future;
    future.whenComplete(() {
      _preparedInFlight.remove(cacheKey);
    });
    return future;
  }

  Future<String?> _resolveDownloadedLocalFile(AttachmentItem attachment) {
    final cacheKey = _cacheKeyForAttachment(attachment);
    final existing = _existingFilePath(_downloadedFilePrefix, cacheKey);
    if (existing != null) {
      return Future<String?>.value(existing);
    }

    final inFlight = _downloadInFlight[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _downloadOriginal(attachment, cacheKey);
    _downloadInFlight[cacheKey] = future;
    future.whenComplete(() {
      _downloadInFlight.remove(cacheKey);
    });
    return future;
  }

  String? _existingFilePath(String prefix, String cacheKey) {
    final storedPath = _preferences.getString('$prefix$cacheKey');
    if (storedPath == null || storedPath.isEmpty) {
      return null;
    }
    final file = File(storedPath);
    if (!file.existsSync()) {
      _preferences.remove('$prefix$cacheKey');
      return null;
    }
    return storedPath;
  }

  Future<String?> _downloadAndTranscode(
    AttachmentItem attachment,
    String cacheKey,
  ) async {
    final originalPath = await _downloadOriginal(attachment, cacheKey);
    if (originalPath == null) {
      return null;
    }

    final directory = await _audioCacheDirectory();
    final outputFile = File('${directory.path}/$cacheKey.m4a');
    if (await outputFile.exists()) {
      _preferences.setString('$_preparedFilePrefix$cacheKey', outputFile.path);
      return outputFile.path;
    }

    try {
      await VoiceMessage.convertOggToM4a(
        srcPath: originalPath,
        destPath: outputFile.path,
      );
      if (!await outputFile.exists()) {
        log(
          'Audio transcode produced no output for ${attachment.id} (${attachment.kind})',
          name: 'AudioSourceResolverService',
        );
        return null;
      }
      _preferences.setString('$_preparedFilePrefix$cacheKey', outputFile.path);
      return outputFile.path;
    } catch (error, stackTrace) {
      log(
        'Audio transcode threw for ${attachment.id} (${attachment.kind})',
        name: 'AudioSourceResolverService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<String?> _downloadOriginal(
    AttachmentItem attachment,
    String cacheKey,
  ) async {
    final existing = _existingFilePath(_downloadedFilePrefix, cacheKey);
    if (existing != null) {
      return existing;
    }

    final extension = _fileExtensionForAttachment(attachment);
    final directory = await _audioCacheDirectory();
    final file = File('${directory.path}/$cacheKey$extension');

    try {
      await _dio.download(attachment.url, file.path);
      _preferences.setString('$_downloadedFilePrefix$cacheKey', file.path);
      return file.path;
    } catch (error, stackTrace) {
      log(
        'Audio download threw for ${attachment.id}',
        name: 'AudioSourceResolverService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<Directory> _audioCacheDirectory() async {
    final baseDirectory = await getApplicationSupportDirectory();
    final directory = Directory('${baseDirectory.path}/voice-cache');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _fileExtensionForAttachment(AttachmentItem attachment) {
    final fileName = attachment.fileName.toLowerCase();
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex >= 0 && dotIndex < fileName.length - 1) {
      return fileName.substring(dotIndex);
    }

    final descriptor = _audioDescriptorForAttachment(attachment);
    if (descriptor.contains('webm')) {
      return '.webm';
    }
    if (descriptor.contains('ogg') || descriptor.contains('opus')) {
      return '.ogg';
    }
    if (descriptor.contains('mpeg') || descriptor.contains('mp3')) {
      return '.mp3';
    }
    if (descriptor.contains('wav')) {
      return '.wav';
    }
    if (descriptor.contains('aac')) {
      return '.aac';
    }
    return '.m4a';
  }

  String _audioDescriptorForAttachment(AttachmentItem attachment) {
    final uriPath = Uri.tryParse(attachment.url)?.path.toLowerCase() ?? '';
    return '${attachment.kind.toLowerCase()}|${attachment.fileName.toLowerCase()}|$uriPath';
  }

  String _cacheKeyForAttachment(AttachmentItem attachment) {
    if (attachment.id.isNotEmpty) {
      return _sanitizeKey(attachment.id);
    }
    return 'audio-${_stableHash(attachment.url)}';
  }

  String _sanitizeKey(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in utf8.encode(value)) {
      final isAlphaNumeric =
          (codeUnit >= 48 && codeUnit <= 57) ||
          (codeUnit >= 65 && codeUnit <= 90) ||
          (codeUnit >= 97 && codeUnit <= 122);
      buffer.writeCharCode(isAlphaNumeric ? codeUnit : 95);
    }
    return buffer.toString();
  }

  int _stableHash(String value) {
    var hash = 0xcbf29ce484222325;
    for (final codeUnit in utf8.encode(value)) {
      hash ^= codeUnit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash;
  }

}

final audioSourceResolverServiceProvider = Provider<AudioSourceResolverService>(
  (ref) {
    return AudioSourceResolverService(
      ref.watch(dioProvider),
      ref.watch(sharedPreferencesProvider),
    );
  },
);
