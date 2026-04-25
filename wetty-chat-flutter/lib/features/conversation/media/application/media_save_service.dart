import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../../core/cache/media_cache_service.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/dio_client.dart';
import 'package:chahua/features/shared/model/message/message.dart';

class MediaSaveException implements Exception {
  const MediaSaveException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MediaSaveService {
  const MediaSaveService(this._mediaCacheService, this._dio);

  final MediaCacheService _mediaCacheService;
  final Dio _dio;

  Future<void> saveAttachment(AttachmentItem attachment) async {
    if (!attachment.isImage && !attachment.isVideo) {
      throw const MediaSaveException('Only images and videos can be saved.');
    }

    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        throw const MediaSaveException(
          'Photo library access is required to save media.',
        );
      }
    }

    final file = await _resolveLocalFile(attachment);
    if (attachment.isImage) {
      await Gal.putImage(file.path);
      return;
    }
    await Gal.putVideo(file.path);
  }

  Future<File> _resolveLocalFile(AttachmentItem attachment) async {
    try {
      final cached = await _mediaCacheService.getOrFetchOriginal(attachment);
      if (cached != null && await cached.exists()) {
        return cached;
      }
    } catch (_) {
      // Fall back to an authenticated download below.
    }

    if (attachment.url.isEmpty) {
      throw const MediaSaveException(
        'This attachment does not have a media URL.',
      );
    }

    final tempDirectory = await getTemporaryDirectory();
    final fileExtension = _resolveExtension(attachment);
    final fileName =
        '${attachment.id.isNotEmpty ? attachment.id : DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final file = File(path.join(tempDirectory.path, fileName));

    try {
      await _dio.download(
        attachment.url,
        file.path,
        options: Options(headers: ApiSession.authHeaders),
      );
      return file;
    } on DioException {
      throw const MediaSaveException('Failed to download media for saving.');
    }
  }

  String _resolveExtension(AttachmentItem attachment) {
    final fileNameExtension = path.extension(attachment.fileName);
    if (fileNameExtension.isNotEmpty) {
      return fileNameExtension.replaceFirst('.', '');
    }

    if (attachment.isImage) {
      return switch (attachment.kind) {
        'image/png' => 'png',
        'image/gif' => 'gif',
        'image/webp' => 'webp',
        _ => 'jpg',
      };
    }

    return switch (attachment.kind) {
      'video/quicktime' => 'mov',
      'video/webm' => 'webm',
      _ => 'mp4',
    };
  }
}

final mediaSaveServiceProvider = Provider<MediaSaveService>((ref) {
  return MediaSaveService(
    ref.watch(mediaCacheServiceProvider),
    ref.watch(dioProvider),
  );
});
