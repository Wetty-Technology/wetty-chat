import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/widgets.dart';

import 'app_cache_directory.dart';
import 'app_cache_file_system.dart';

class ImageCacheService {
  ImageCacheService({
    BaseCacheManager? cacheManager,
    String cacheNamespace = _defaultCacheNamespace,
  }) : _cacheNamespace = cacheNamespace,
       _cacheManager =
           cacheManager ??
           CacheManager(
             Config(
               cacheNamespace,
               stalePeriod: stalePeriod,
               maxNrOfCacheObjects: maxNrOfCacheObjects,
               repo: CacheObjectProvider(
                 path: appCacheMetadataDatabasePath(cacheNamespace),
               ),
               fileSystem: AppCacheFileSystem(cacheNamespace),
             ),
           );

  static const String _defaultCacheNamespace = 'chat_image_cache_v1';
  static const Duration stalePeriod = Duration(days: 30);
  static const int maxNrOfCacheObjects = 400;

  final String _cacheNamespace;
  final BaseCacheManager _cacheManager;

  BaseCacheManager get cacheManager => _cacheManager;

  ImageProvider<Object> providerForUrl(String imageUrl) {
    return CachedNetworkImageProvider(imageUrl, cacheManager: _cacheManager);
  }

  Future<int> estimateUsageBytes() async {
    final directory = await _cacheDirectory();
    return _directorySize(directory);
  }

  Future<void> clearAll() async {
    await _cacheManager.emptyCache();
    final directory = await _cacheDirectory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> dispose() async {
    if (_cacheManager is! CacheManager) {
      return;
    }
    final cacheManager = _cacheManager;
    try {
      await cacheManager.dispose();
    } catch (_) {
      // Ignore shutdown races in tests.
    }
  }

  Future<Directory> _cacheDirectory() async {
    return resolveAppCacheDirectory(_cacheNamespace);
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

final imageCacheServiceProvider = Provider<ImageCacheService>((ref) {
  final service = ImageCacheService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});
