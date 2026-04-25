import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:chahua/features/shared/model/message/message.dart';

class MediaCacheUsageSummary {
  const MediaCacheUsageSummary({required this.totalBytes});

  final int totalBytes;
}

class MediaCacheService {
  MediaCacheService({
    CacheManager? cacheManager,
    String cacheNamespace = _defaultCacheNamespace,
  }) : _cacheNamespace = cacheNamespace,
       _cacheManager =
           cacheManager ?? CacheManager(_configForNamespace(cacheNamespace));

  static const String _defaultCacheNamespace = 'chat_media_cache_v1';
  static const Duration stalePeriod = Duration(days: 30);
  static const Duration artifactMaxAge = Duration(days: 30);
  static const int maxNrOfCacheObjects = 400;
  static Config _configForNamespace(String cacheNamespace) => Config(
    cacheNamespace,
    stalePeriod: stalePeriod,
    maxNrOfCacheObjects: maxNrOfCacheObjects,
  );

  final String _cacheNamespace;
  final CacheManager _cacheManager;
  final Map<String, Future<File?>> _inFlight = <String, Future<File?>>{};

  String cacheKeyForAttachment(AttachmentItem attachment) {
    if (attachment.id.isNotEmpty) {
      return _sanitizeKey(attachment.id);
    }
    return 'url-${_stableHash(attachment.url)}';
  }

  String cacheKeyForAttachmentId(String attachmentId) =>
      _sanitizeKey(attachmentId);

  String originalKey(String cacheKey) => 'audio-original:$cacheKey';

  String derivedKey(String cacheKey, String variant) =>
      'audio-derived:$variant:$cacheKey';

  String sidecarKey(String cacheKey, String sidecarName) =>
      'audio-sidecar:$sidecarName:$cacheKey';

  Future<File?> getOrFetchOriginal(AttachmentItem attachment) async {
    if (attachment.url.isEmpty) {
      return null;
    }

    final key = originalKey(cacheKeyForAttachment(attachment));
    final existing = await _cacheManager.getFileFromCache(key);
    if (existing != null) {
      return existing.file;
    }

    final inFlight = _inFlight[key];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _cacheManager
        .getSingleFile(attachment.url, key: key)
        .then<File?>((file) => file);
    _inFlight[key] = future;
    return future.whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<File?> getOrCreateDerived({
    required AttachmentItem attachment,
    required String variant,
    required String fileExtension,
    required Future<File?> Function(File originalFile) createDerivedFile,
  }) async {
    final cacheKey = cacheKeyForAttachment(attachment);
    final key = derivedKey(cacheKey, variant);
    final existing = await _cacheManager.getFileFromCache(key);
    if (existing != null) {
      return existing.file;
    }

    final inFlight = _inFlight[key];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _createAndCacheDerived(
      attachment: attachment,
      cacheKey: key,
      fileExtension: fileExtension,
      createDerivedFile: createDerivedFile,
    );
    _inFlight[key] = future;
    return future.whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<Uint8List?> getSidecar(String key) async {
    final existing = await _cacheManager.getFileFromCache(key);
    if (existing == null) {
      return null;
    }
    return existing.file.readAsBytes();
  }

  Future<void> putSidecar({
    required String key,
    required List<int> bytes,
    required String fileExtension,
  }) async {
    await _cacheManager.putFile(
      key,
      Uint8List.fromList(bytes),
      key: key,
      maxAge: artifactMaxAge,
      fileExtension: fileExtension,
    );
  }

  Future<void> putJsonSidecar({
    required String key,
    required Map<String, dynamic> json,
  }) {
    return putSidecar(
      key: key,
      bytes: utf8.encode(jsonEncode(json)),
      fileExtension: 'json',
    );
  }

  Future<Map<String, dynamic>?> getJsonSidecar(String key) async {
    final bytes = await getSidecar(key);
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> evict(AttachmentItem attachment) async {
    final cacheKey = cacheKeyForAttachment(attachment);
    final keys = <String>[
      originalKey(cacheKey),
      derivedKey(cacheKey, 'm4a'),
      sidecarKey(cacheKey, 'waveform'),
    ];
    for (final key in keys) {
      await _cacheManager.removeFile(key);
    }
  }

  Future<MediaCacheUsageSummary> estimateUsage() async {
    final directory = await _cacheDirectory();
    final totalBytes = await _directorySize(directory);
    return MediaCacheUsageSummary(totalBytes: totalBytes);
  }

  Future<void> clearAll() async {
    _inFlight.clear();
    _cacheManager.store.emptyMemoryCache();
    await _cacheManager.emptyCache();
    final directory = await _cacheDirectory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> dispose() async {
    try {
      await _cacheManager.dispose();
    } catch (_) {
      // Cache manager disposal can race test teardown before the underlying
      // repository opens; ignore that shutdown edge case.
    }
  }

  Future<File?> _createAndCacheDerived({
    required AttachmentItem attachment,
    required String cacheKey,
    required String fileExtension,
    required Future<File?> Function(File originalFile) createDerivedFile,
  }) async {
    final originalFile = await getOrFetchOriginal(attachment);
    if (originalFile == null) {
      return null;
    }

    File? derivedFile;
    try {
      derivedFile = await createDerivedFile(originalFile);
      if (derivedFile == null || !await derivedFile.exists()) {
        return null;
      }

      final bytes = await derivedFile.readAsBytes();
      return _cacheManager.putFile(
        cacheKey,
        bytes,
        key: cacheKey,
        maxAge: artifactMaxAge,
        fileExtension: fileExtension,
      );
    } finally {
      if (derivedFile != null &&
          derivedFile.path != originalFile.path &&
          await derivedFile.exists()) {
        await derivedFile.delete();
      }
    }
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

  Future<Directory> _cacheDirectory() async {
    final temporaryDirectory = await getTemporaryDirectory();
    final directory = Directory(
      path.join(temporaryDirectory.path, _cacheNamespace),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<int> _directorySize(Directory directory) async {
    var total = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      try {
        total += await entity.length();
      } on FileSystemException {
        // Ignore files that disappear while we are measuring usage.
      }
    }
    return total;
  }
}

final mediaCacheServiceProvider = Provider<MediaCacheService>((ref) {
  final service = MediaCacheService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});
