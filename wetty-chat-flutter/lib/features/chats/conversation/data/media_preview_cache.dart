import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import '../../../../core/network/api_config.dart';

Map<String, String>? attachmentRequestHeadersForUrl(String url) {
  final mediaUri = Uri.tryParse(url);
  final apiUri = Uri.tryParse(apiBaseUrl);
  if (mediaUri == null || apiUri == null) {
    return null;
  }

  final sameHost =
      mediaUri.scheme == apiUri.scheme && mediaUri.host == apiUri.host;
  if (!sameHost) {
    return null;
  }

  final uid = ApiSession.currentUserId;
  return <String, String>{
    'X-User-Id': uid.toString(),
    'X-Client-Id': uid.toString(),
  };
}

class MediaPreviewCache {
  MediaPreviewCache._();

  static final MediaPreviewCache instance = MediaPreviewCache._();

  static const Duration maxAge = Duration(days: 7);
  static const Duration retryCooldown = Duration(minutes: 1);
  static const int imageThumbnailMaxDimension = 320;
  static const int imageViewerMaxDimension = 2048;
  static const int avatarThumbnailMaxDimension = 96;
  static const String _cacheFolderName = 'wetty_chat_media_previews';

  final Map<String, Future<File?>> _pending = <String, Future<File?>>{};
  final Map<String, DateTime> _recentFailures = <String, DateTime>{};
  final Set<String> _knownInvalidImageUrls = <String>{};
  Future<void>? _cleanupFuture;

  void initialize() {
    _cleanupFuture ??= Future<void>(() async {
      await _cleanupExpiredFiles();
    });
  }

  Future<File?> loadImageThumbnail(String url) {
    return loadImagePreview(url, maxDimension: imageThumbnailMaxDimension);
  }

  bool isKnownInvalidImageUrl(String url) {
    return _knownInvalidImageUrls.contains(url);
  }

  void markInvalidImageUrl(String url) {
    if (url.isEmpty) {
      return;
    }
    _knownInvalidImageUrls.add(url);
  }

  Future<void> invalidateImageThumbnail(
    String url, {
    bool markFailure = false,
  }) {
    return _invalidateFile(
      namespace: 'image_preview_$imageThumbnailMaxDimension',
      url: url,
      extension: 'png',
      markFailure: markFailure,
    );
  }

  Future<File?> loadAvatarThumbnail(String url) {
    return loadImagePreview(url, maxDimension: avatarThumbnailMaxDimension);
  }

  Future<void> invalidateAvatarThumbnail(
    String url, {
    bool markFailure = false,
  }) {
    return _invalidateFile(
      namespace: 'image_preview_$avatarThumbnailMaxDimension',
      url: url,
      extension: 'png',
      markFailure: markFailure,
    );
  }

  Future<File?> loadImagePreview(String url, {required int maxDimension}) {
    return _loadFile(
      namespace: 'image_preview_$maxDimension',
      url: url,
      extension: 'png',
      generator: () => _downloadImagePreview(url, maxDimension: maxDimension),
    );
  }

  Future<File?> loadVideoPreview(
    String url,
    Future<Uint8List?> Function() generator,
  ) {
    return _loadFile(
      namespace: 'video_preview',
      url: url,
      extension: 'jpg',
      generator: generator,
    );
  }

  Future<void> invalidateVideoPreview(String url, {bool markFailure = false}) {
    return _invalidateFile(
      namespace: 'video_preview',
      url: url,
      extension: 'jpg',
      markFailure: markFailure,
    );
  }

  Future<File?> _loadFile({
    required String namespace,
    required String url,
    required String extension,
    required Future<Uint8List?> Function() generator,
  }) async {
    if (isKnownInvalidImageUrl(url)) {
      return null;
    }

    final cachePath = await _cachePath(namespace: namespace, url: url);
    final file = File('$cachePath.$extension');
    final pendingKey = '$namespace::$url';
    if (await file.exists()) {
      final stat = await file.stat();
      if (stat.size > 0) {
        _clearFailure(pendingKey);
        return file;
      }
      await file.delete();
    }

    if (_isInFailureCooldown(pendingKey)) {
      return null;
    }

    final pending = _pending[pendingKey];
    if (pending != null) {
      return pending;
    }

    final future = _writeGeneratedFile(file, generator, failureKey: pendingKey);
    _pending[pendingKey] = future;
    return future.whenComplete(() {
      _pending.remove(pendingKey);
    });
  }

  Future<File?> _writeGeneratedFile(
    File file,
    Future<Uint8List?> Function() generator, {
    required String failureKey,
  }) async {
    final bytes = await generator();
    if (bytes == null || bytes.isEmpty) {
      _recordFailure(failureKey);
      return null;
    }
    if (!await _isDisplayableImageBytes(bytes)) {
      _recordFailure(failureKey);
      return null;
    }
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    await tempFile.writeAsBytes(bytes, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
    _clearFailure(failureKey);
    return file;
  }

  Future<void> _invalidateFile({
    required String namespace,
    required String url,
    required String extension,
    required bool markFailure,
  }) async {
    final key = '$namespace::$url';
    if (markFailure) {
      _recordFailure(key);
    } else {
      _clearFailure(key);
    }
    final cachePath = await _cachePath(namespace: namespace, url: url);
    final file = File('$cachePath.$extension');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> _isDisplayableImageBytes(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
      return image.width > 0 && image.height > 0;
    } catch (_) {
      return false;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  Future<Uint8List?> _downloadImagePreview(
    String url, {
    required int maxDimension,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return null;
    }

    final response = await http.get(
      uri,
      headers: attachmentRequestHeadersForUrl(url),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final contentType = response.headers['content-type'];
    if (contentType != null &&
        contentType.isNotEmpty &&
        !contentType.toLowerCase().startsWith('image/')) {
      markInvalidImageUrl(url);
      return null;
    }

    return _resizeImage(response.bodyBytes, maxDimension: maxDimension);
  }

  Future<Uint8List?> _resizeImage(
    Uint8List bytes, {
    required int maxDimension,
  }) async {
    ui.Codec? sourceCodec;
    ui.Codec? thumbnailCodec;
    ui.Image? sourceImage;
    ui.Image? thumbnailImage;
    try {
      sourceCodec = await ui.instantiateImageCodec(bytes);
      final sourceFrame = await sourceCodec.getNextFrame();
      sourceImage = sourceFrame.image;

      final width = sourceImage.width;
      final height = sourceImage.height;
      if (width <= 0 || height <= 0) {
        return null;
      }

      final longest = width > height ? width : height;
      final scale = longest > maxDimension ? maxDimension / longest : 1.0;
      final targetWidth = (width * scale).round().clamp(1, width);
      final targetHeight = (height * scale).round().clamp(1, height);

      thumbnailCodec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final thumbnailFrame = await thumbnailCodec.getNextFrame();
      thumbnailImage = thumbnailFrame.image;
      final byteData = await thumbnailImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      sourceImage?.dispose();
      thumbnailImage?.dispose();
      sourceCodec?.dispose();
      thumbnailCodec?.dispose();
    }
  }

  Future<void> _cleanupExpiredFiles() async {
    try {
      final directory = await _cacheDirectory();
      if (!await directory.exists()) {
        return;
      }

      final cutoff = DateTime.now().subtract(maxAge);
      await for (final entity in directory.list(recursive: true)) {
        if (entity is! File) {
          continue;
        }
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Ignore cache cleanup failures.
    }
  }

  bool _isInFailureCooldown(String key) {
    final failedAt = _recentFailures[key];
    if (failedAt == null) {
      return false;
    }
    if (DateTime.now().difference(failedAt) >= retryCooldown) {
      _recentFailures.remove(key);
      return false;
    }
    return true;
  }

  void _recordFailure(String key) {
    _recentFailures[key] = DateTime.now();
  }

  void _clearFailure(String key) {
    _recentFailures.remove(key);
  }

  Future<String> _cachePath({
    required String namespace,
    required String url,
  }) async {
    final dir = await _cacheDirectory();
    final key = _hashKey('$namespace::$url');
    return '${dir.path}${Platform.pathSeparator}$key';
  }

  Future<Directory> _cacheDirectory() async {
    final dir = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}$_cacheFolderName',
    );
    await dir.create(recursive: true);
    return dir;
  }

  String _hashKey(String value) {
    const int fnvOffset = 0xcbf29ce484222325;
    const int fnvPrime = 0x100000001b3;
    var hash = fnvOffset;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
