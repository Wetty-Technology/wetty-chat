import 'dart:developer';
import 'dart:io';

import 'package:chahua/core/cache/media_cache_service.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:voice_message/voice_message.dart';

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
  AudioSourceResolverService(this._mediaCacheService);

  final MediaCacheService _mediaCacheService;

  Future<AudioPlaybackSource?> resolvePlaybackSource(
    AttachmentItem attachment,
  ) async {
    if (attachment.url.isEmpty) {
      return null;
    }

    final playbackFile = _requiresTranscode(attachment)
        ? await _resolvePreparedLocalFile(attachment)
        : await _mediaCacheService.getOrFetchOriginal(attachment);
    if (playbackFile == null) {
      return null;
    }
    return AudioPlaybackSource.file(
      filePath: playbackFile.path,
      localWaveformPath: playbackFile.path,
    );
  }

  Future<String?> resolveWaveformInputPath(AttachmentItem attachment) async {
    final source = await resolvePlaybackSource(attachment);
    return source?.localWaveformPath;
  }

  bool _requiresTranscode(AttachmentItem attachment) {
    return audioAttachmentNeedsAppleTranscode(
      attachment,
      isApplePlatform: Platform.isIOS || Platform.isMacOS,
    );
  }

  Future<File?> _resolvePreparedLocalFile(AttachmentItem attachment) async {
    try {
      return await _mediaCacheService.getOrCreateDerived(
        attachment: attachment,
        variant: 'm4a',
        fileExtension: 'm4a',
        createDerivedFile: (originalFile) async {
          final tempDirectory = await getTemporaryDirectory();
          final cacheKey = _mediaCacheService.cacheKeyForAttachment(attachment);
          final outputFile = File('${tempDirectory.path}/$cacheKey.m4a');
          await VoiceMessage.convertOggToM4a(
            srcPath: originalFile.path,
            destPath: outputFile.path,
          );
          if (!await outputFile.exists()) {
            return null;
          }
          return outputFile;
        },
      );
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
}

@visibleForTesting
bool audioAttachmentNeedsAppleTranscode(
  AttachmentItem attachment, {
  required bool isApplePlatform,
}) {
  if (!isApplePlatform || !attachment.isAudio || attachment.url.isEmpty) {
    return false;
  }

  final kind = attachment.kind.toLowerCase();
  final fileName = attachment.fileName.toLowerCase();
  final urlPath = Uri.tryParse(attachment.url)?.path.toLowerCase() ?? '';
  final extension = _audioFileExtension(fileName, urlPath);

  if (kind.contains('webm') || extension == 'webm') {
    return true;
  }
  if (kind.contains('ogg') ||
      extension == 'ogg' ||
      extension == 'oga' ||
      extension == 'opus') {
    return true;
  }

  return false;
}

String? _audioFileExtension(String fileName, String urlPath) {
  final candidates = <String>[fileName, urlPath];
  for (final candidate in candidates) {
    final trimmed = candidate.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final dotIndex = trimmed.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == trimmed.length - 1) {
      continue;
    }
    return trimmed.substring(dotIndex + 1).toLowerCase();
  }
  return null;
}

final audioSourceResolverServiceProvider = Provider<AudioSourceResolverService>(
  (ref) {
    return AudioSourceResolverService(ref.watch(mediaCacheServiceProvider));
  },
);
