import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/models/message_models.dart';
import '../../data/services/media_preview_cache.dart';

Future<void> showVideoPlayerPopup(
  BuildContext context,
  AttachmentItem attachment,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Video player',
    barrierColor: CupertinoColors.black.withAlpha(190),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, animation, secondaryAnimation) =>
        _VideoPopupPlayerDialog(attachment: attachment),
    transitionBuilder: (_, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.98,
            end: 1,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
  );
}

class VideoAttachmentPreview extends StatefulWidget {
  const VideoAttachmentPreview({
    super.key,
    required this.attachment,
    required this.onTap,
  });

  final AttachmentItem attachment;
  final VoidCallback onTap;

  @override
  State<VideoAttachmentPreview> createState() => _VideoAttachmentPreviewState();
}

class _VideoAttachmentPreviewState extends State<VideoAttachmentPreview> {
  static const int _maxDecodeRetries = 1;

  late Future<File?> _thumbnailFuture;
  int _decodeRetryCount = 0;
  bool _disableCachePreview = false;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _loadThumbnail();
  }

  Future<File?> _loadThumbnail() {
    return MediaPreviewCache.instance.loadVideoPreview(
      widget.attachment.url,
      () => _VideoThumbnailCache.instance.load(widget.attachment.url),
    );
  }

  void _handleDecodeError(File file) {
    if (_decodeRetryCount >= _maxDecodeRetries) {
      unawaited(
        MediaPreviewCache.instance.invalidateVideoPreview(
          widget.attachment.url,
          markFailure: true,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _disableCachePreview = true;
      });
      return;
    }

    _decodeRetryCount += 1;
    unawaited(
      MediaPreviewCache.instance.invalidateVideoPreview(widget.attachment.url),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _thumbnailFuture = _loadThumbnail();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _preferredAspectRatio(widget.attachment);
    final width = ratio >= 1 ? 220.0 : 168.0;
    final height = width / ratio;

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<File?>(
                future: _thumbnailFuture,
                builder: (context, snapshot) {
                  if (_disableCachePreview) {
                    return _VideoPlaceholder(attachment: widget.attachment);
                  }
                  final file = snapshot.data;
                  if (file != null) {
                    return Image.file(
                      file,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) {
                        _handleDecodeError(file);
                        return _VideoPlaceholder(attachment: widget.attachment);
                      },
                    );
                  }
                  return _VideoPlaceholder(attachment: widget.attachment);
                },
              ),
              Container(color: CupertinoColors.black.withAlpha(36)),
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: CupertinoColors.black.withAlpha(110),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CupertinoColors.white.withAlpha(70),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.play_fill,
                    color: CupertinoColors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPopupPlayerDialog extends StatefulWidget {
  const _VideoPopupPlayerDialog({required this.attachment});

  final AttachmentItem attachment;

  @override
  State<_VideoPopupPlayerDialog> createState() =>
      _VideoPopupPlayerDialogState();
}

class _VideoPopupPlayerDialogState extends State<_VideoPopupPlayerDialog> {
  late final Player _player;
  late final VideoController _controller;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Object? _error;
  bool _isPreparing = true;

  bool get _isMobilePlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: PlayerConfiguration(
        logLevel: kDebugMode ? MPVLogLevel.debug : MPVLogLevel.error,
      ),
    );
    _controller = VideoController(_player);
    _bindDebugStreams();
    unawaited(_open());
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _open() async {
    try {
      await _player.setVolume(100);
      await _player.open(
        Media(
          widget.attachment.url,
          httpHeaders: attachmentRequestHeadersForUrl(widget.attachment.url),
        ),
      );
    } catch (error) {
      _log('open failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _isPreparing = false;
      });
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isPreparing = false;
    });
  }

  void _bindDebugStreams() {
    _subscriptions.addAll([
      _player.stream.error.listen((error) {
        _log('player error: $error');
        if (!mounted) {
          return;
        }
        setState(() {
          _error ??= error;
        });
      }),
      _player.stream.log.listen((event) {
        _log('mpv ${event.level}/${event.prefix}: ${event.text.trim()}');
      }),
      _player.stream.width.listen((width) {
        if (width != null && width > 0) {
          _log('video width=$width');
        }
      }),
      _player.stream.height.listen((height) {
        if (height != null && height > 0) {
          _log('video height=$height');
        }
      }),
    ]);
  }

  void _log(String message) {
    debugPrint('[VideoPlayer url=${widget.attachment.url}] $message');
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.attachment.fileName.isEmpty
        ? 'Video'
        : widget.attachment.fileName;
    final size = MediaQuery.sizeOf(context);
    final aspectRatio = _preferredAspectRatio(widget.attachment);

    final controlsTheme = MaterialDesktopVideoControlsThemeData(
      visibleOnMount: true,
      topButtonBar: [
        material.IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(material.Icons.close),
          color: material.Colors.white,
          tooltip: 'Close',
        ),
      ],
      seekBarPositionColor: const Color(0xFFE25B47),
      seekBarThumbColor: const Color(0xFFE25B47),
    );

    final playerView = _error != null
        ? _PlayerError(error: _error.toString())
        : _isPreparing
        ? const _PlayerLoading()
        : MaterialDesktopVideoControlsTheme(
            normal: controlsTheme,
            fullscreen: controlsTheme,
            child: Video(
              controller: _controller,
              controls: AdaptiveVideoControls,
              fit: BoxFit.contain,
            ),
          );

    if (_isMobilePlatform) {
      return material.Material(
        color: material.Colors.black,
        child: SafeArea(
          child: SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: aspectRatio,
                      child: material.Material(
                        color: material.Colors.black,
                        child: playerView,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    minimumSize: const Size(40, 40),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.back,
                          color: CupertinoColors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'MiSans',
                              color: CupertinoColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dialogWidth = size.width * 0.82;
    final dialogHeight = size.height * 0.82;

    return material.Material(
      type: material.MaterialType.transparency,
      child: Center(
        child: Container(
          width: dialogWidth.clamp(520.0, 1120.0),
          height: dialogHeight.clamp(320.0, 820.0),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withAlpha(70),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'MiSans',
                          color: CupertinoColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(
                        CupertinoIcons.clear,
                        color: CupertinoColors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: material.Material(
                  color: material.Colors.black,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: aspectRatio,
                      child: playerView,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.attachment});

  final AttachmentItem attachment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF272727), Color(0xFF151515)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Text(
              attachment.fileName.isEmpty ? 'Video' : attachment.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'MiSans',
                color: CupertinoColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerError extends StatelessWidget {
  const _PlayerError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: CupertinoColors.white,
              size: 34,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to play this video',
              style: TextStyle(
                fontFamily: 'MiSans',
                color: CupertinoColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'MiSans',
                color: CupertinoColors.systemGrey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerLoading extends StatelessWidget {
  const _PlayerLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoActivityIndicator(radius: 14),
          SizedBox(height: 12),
          Text(
            'Loading video...',
            style: TextStyle(
              fontFamily: 'MiSans',
              color: CupertinoColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoThumbnailCache {
  _VideoThumbnailCache._();

  static final _VideoThumbnailCache instance = _VideoThumbnailCache._();

  final Map<String, Uint8List?> _cache = <String, Uint8List?>{};
  final Map<String, Future<Uint8List?>> _pending =
      <String, Future<Uint8List?>>{};

  Future<Uint8List?> load(String url) {
    if (_cache.containsKey(url)) {
      return Future<Uint8List?>.value(_cache[url]);
    }
    final pending = _pending[url];
    if (pending != null) {
      return pending;
    }
    final future = _generate(url);
    _pending[url] = future;
    return future.whenComplete(() {
      _pending.remove(url);
    });
  }

  Future<Uint8List?> _generate(String url) async {
    final player = Player(
      configuration: PlayerConfiguration(
        logLevel: kDebugMode ? MPVLogLevel.debug : MPVLogLevel.error,
      ),
    );
    try {
      await player.setVolume(0);
      await player.open(
        Media(url, httpHeaders: attachmentRequestHeadersForUrl(url)),
      );
      await Future.any<Object?>(<Future<Object?>>[
        player.stream.width.firstWhere((value) => (value ?? 0) > 0),
        Future<Object?>.delayed(const Duration(seconds: 2)),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final bytes = await player.screenshot(format: 'image/jpeg');
      _cache[url] = bytes;
      return bytes;
    } catch (_) {
      _cache[url] = null;
      return null;
    } finally {
      await player.dispose();
    }
  }
}

double _preferredAspectRatio(AttachmentItem attachment) {
  final width = attachment.width;
  final height = attachment.height;
  if (width != null && height != null && width > 0 && height > 0) {
    return width / height;
  }
  return 16 / 9;
}
