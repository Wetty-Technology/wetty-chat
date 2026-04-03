import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../data/media_preview_cache.dart';

class MessageAvatar extends StatefulWidget {
  const MessageAvatar({
    super.key,
    required this.avatarUrl,
    required this.fallbackBuilder,
  });

  final String avatarUrl;
  final Widget Function() fallbackBuilder;

  @override
  State<MessageAvatar> createState() => _MessageAvatarState();
}

class _MessageAvatarState extends State<MessageAvatar> {
  static const int _maxDecodeRetries = 1;

  late Future<File?> _avatarFuture;
  int _decodeRetryCount = 0;
  bool _disableCachePreview = false;

  @override
  void initState() {
    super.initState();
    _avatarFuture = _loadAvatar();
  }

  Future<File?> _loadAvatar() {
    return MediaPreviewCache.instance.loadAvatarThumbnail(widget.avatarUrl);
  }

  void _handleDecodeError(File file) {
    if (_decodeRetryCount >= _maxDecodeRetries) {
      unawaited(
        MediaPreviewCache.instance.invalidateAvatarThumbnail(
          widget.avatarUrl,
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
      MediaPreviewCache.instance.invalidateAvatarThumbnail(widget.avatarUrl),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _avatarFuture = _loadAvatar();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_disableCachePreview) {
      return _RawAvatar(
        avatarUrl: widget.avatarUrl,
        fallbackBuilder: widget.fallbackBuilder,
      );
    }

    return FutureBuilder<File?>(
      future: _avatarFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return ClipOval(
            child: Image.file(
              file,
              width: 30,
              height: 30,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) {
                _handleDecodeError(file);
                return _RawAvatar(
                  avatarUrl: widget.avatarUrl,
                  fallbackBuilder: widget.fallbackBuilder,
                );
              },
            ),
          );
        }
        return _RawAvatar(
          avatarUrl: widget.avatarUrl,
          fallbackBuilder: widget.fallbackBuilder,
        );
      },
    );
  }
}

class _RawAvatar extends StatelessWidget {
  const _RawAvatar({required this.avatarUrl, required this.fallbackBuilder});

  final String avatarUrl;
  final Widget Function() fallbackBuilder;

  @override
  Widget build(BuildContext context) {
    if (MediaPreviewCache.instance.isKnownInvalidImageUrl(avatarUrl)) {
      return fallbackBuilder();
    }

    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: 30,
        height: 30,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        headers: attachmentRequestHeadersForUrl(avatarUrl),
        errorBuilder: (_, _, _) {
          MediaPreviewCache.instance.markInvalidImageUrl(avatarUrl);
          return fallbackBuilder();
        },
      ),
    );
  }
}
