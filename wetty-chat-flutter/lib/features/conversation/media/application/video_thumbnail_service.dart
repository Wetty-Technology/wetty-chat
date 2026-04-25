import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../../core/cache/media_cache_service.dart';
import '../../../../core/network/dio_client.dart';
import 'package:chahua/features/shared/model/message/message.dart';

class VideoThumbnailService {
  VideoThumbnailService(this._mediaCacheService, this._dio);

  static const int _thumbnailMaxWidth = 512;
  static const int _thumbnailQuality = 70;
  static const String _thumbnailVariant = 'video-thumbnail';
  static const String _thumbnailSidecarName = 'video-thumbnail-jpeg';

  final MediaCacheService _mediaCacheService;
  final Dio _dio;
  final Map<String, Future<Uint8List?>> _inFlight =
      <String, Future<Uint8List?>>{};

  Future<Uint8List?> getThumbnailBytes(AttachmentItem attachment) async {
    if (!attachment.isVideo || attachment.url.isEmpty) {
      return null;
    }

    final cacheKey = _thumbnailCacheKey(attachment);
    final cached = await _mediaCacheService.getSidecar(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final inFlight = _inFlight[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _generateAndCacheThumbnail(attachment, cacheKey);
    _inFlight[cacheKey] = future;
    return future.whenComplete(() {
      _inFlight.remove(cacheKey);
    });
  }

  String _thumbnailCacheKey(AttachmentItem attachment) {
    final attachmentKey = _mediaCacheService.cacheKeyForAttachment(attachment);
    return _mediaCacheService.sidecarKey(attachmentKey, _thumbnailSidecarName);
  }

  Future<Uint8List?> _generateAndCacheThumbnail(
    AttachmentItem attachment,
    String cacheKey,
  ) async {
    final source = await _resolveSourceFile(attachment);
    if (source == null) {
      return null;
    }

    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: source.file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: _thumbnailMaxWidth,
        quality: _thumbnailQuality,
      );
      if (bytes == null || bytes.isEmpty) {
        return null;
      }

      await _mediaCacheService.putSidecar(
        key: cacheKey,
        bytes: bytes,
        fileExtension: 'jpg',
      );
      return bytes;
    } finally {
      if (source.deleteWhenDone && await source.file.exists()) {
        await source.file.delete();
      }
    }
  }

  Future<_ResolvedVideoSource?> _resolveSourceFile(
    AttachmentItem attachment,
  ) async {
    try {
      final cachedOriginal = await _mediaCacheService.getOrFetchOriginal(
        attachment,
      );
      if (cachedOriginal != null && await cachedOriginal.exists()) {
        return _ResolvedVideoSource(
          file: cachedOriginal,
          deleteWhenDone: false,
        );
      }
    } catch (_) {
      // Fall back to an authenticated download below.
    }

    final tempDirectory = await getTemporaryDirectory();
    final attachmentKey = _mediaCacheService.cacheKeyForAttachment(attachment);
    final extension = _videoExtension(attachment);
    final file = File(
      path.join(
        tempDirectory.path,
        'video_thumbnail_${attachmentKey}_$_thumbnailVariant.$extension',
      ),
    );

    try {
      await _dio.download(attachment.url, file.path);
      if (!await file.exists()) {
        return null;
      }
      return _ResolvedVideoSource(file: file, deleteWhenDone: true);
    } on DioException {
      if (await file.exists()) {
        await file.delete();
      }
      return null;
    }
  }

  String _videoExtension(AttachmentItem attachment) {
    final extension = path.extension(attachment.fileName);
    if (extension.isNotEmpty) {
      return extension.replaceFirst('.', '');
    }

    return switch (attachment.kind) {
      'video/quicktime' => 'mov',
      'video/webm' => 'webm',
      _ => 'mp4',
    };
  }
}

class _ResolvedVideoSource {
  const _ResolvedVideoSource({
    required this.file,
    required this.deleteWhenDone,
  });

  final File file;
  final bool deleteWhenDone;
}

final videoThumbnailServiceProvider = Provider<VideoThumbnailService>((ref) {
  return VideoThumbnailService(
    ref.watch(mediaCacheServiceProvider),
    ref.watch(dioProvider),
  );
});

final videoThumbnailBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, AttachmentItem>((ref, attachment) {
      return ref
          .watch(videoThumbnailServiceProvider)
          .getThumbnailBytes(attachment);
    });
