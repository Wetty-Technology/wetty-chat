import 'dart:developer';
import 'dart:io';

import 'package:chahua/core/cache/media_cache_service.dart';
import 'package:chahua/features/shared/model/message/message.dart';
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

    final preparation = VoiceMessage.playbackPreparationFor(
      contentType: attachment.kind,
      fileName: attachment.fileName,
      urlPath: Uri.tryParse(attachment.url)?.path,
    );
    final playbackFile = switch (preparation) {
      VoiceMessagePlaybackPreparation.passthrough =>
        await _mediaCacheService.getOrFetchOriginal(attachment),
      VoiceMessagePlaybackPreparation.convertOggOpusToM4a =>
        await _resolvePreparedLocalFile(attachment),
      VoiceMessagePlaybackPreparation.unsupported => null,
    };
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
          final prepared = await VoiceMessage.preparePlaybackFile(
            inputPath: originalFile.path,
            outputPath: outputFile.path,
            contentType: attachment.kind,
            fileName: attachment.fileName,
            urlPath: Uri.tryParse(attachment.url)?.path,
          );
          if (prepared == null || !prepared.isTranscoded) {
            return null;
          }
          final preparedFile = File(prepared.path);
          if (!await preparedFile.exists()) {
            return null;
          }
          return preparedFile;
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

final audioSourceResolverServiceProvider = Provider<AudioSourceResolverService>(
  (ref) {
    return AudioSourceResolverService(ref.watch(mediaCacheServiceProvider));
  },
);
