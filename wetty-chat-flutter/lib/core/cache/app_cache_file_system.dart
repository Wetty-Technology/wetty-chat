import 'package:file/file.dart' as file;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'app_cache_directory.dart';

class AppCacheFileSystem implements FileSystem {
  AppCacheFileSystem(this.cacheNamespace);

  final String cacheNamespace;
  final LocalFileSystem _fileSystem = const LocalFileSystem();
  Future<file.Directory>? _directory;

  Future<file.Directory> _resolveDirectory() async {
    final directory = await resolveAppCacheDirectory(cacheNamespace);
    return _fileSystem.directory(directory.path);
  }

  @override
  Future<file.File> createFile(String name) async {
    var directory = await (_directory ??= _resolveDirectory());
    if (!await directory.exists()) {
      _directory = _resolveDirectory();
      directory = await _directory!;
    }
    return directory.childFile(name);
  }
}
