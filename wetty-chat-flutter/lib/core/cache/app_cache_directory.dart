import 'dart:developer';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<Directory> resolveAppCacheDirectory(String cacheNamespace) async {
  final baseDirectory = await _resolveBaseCacheDirectory();
  final directory = Directory(path.join(baseDirectory.path, cacheNamespace));
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  return directory;
}

String appCacheMetadataDatabasePath(String cacheNamespace) {
  return path.join(
    Directory.systemTemp.path,
    cacheNamespace,
    '$cacheNamespace.db',
  );
}

Future<Directory> _resolveBaseCacheDirectory() async {
  try {
    return await getTemporaryDirectory();
  } on MissingPlatformDirectoryException catch (error, stackTrace) {
    log(
      'Falling back to system temp directory for cache storage',
      name: 'AppCacheDirectory',
      error: error,
      stackTrace: stackTrace,
    );
    return Directory.systemTemp;
  }
}
