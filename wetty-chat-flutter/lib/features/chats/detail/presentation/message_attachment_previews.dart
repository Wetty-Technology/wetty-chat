import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../models/message_models.dart';
import '../data/media_preview_cache.dart';

class MessageImageAttachmentPreview extends StatefulWidget {
  const MessageImageAttachmentPreview({
    super.key,
    required this.attachment,
    required this.onTap,
    required this.fallback,
  });

  final AttachmentItem attachment;
  final VoidCallback onTap;
  final Widget fallback;

  @override
  State<MessageImageAttachmentPreview> createState() =>
      _MessageImageAttachmentPreviewState();
}

class _MessageImageAttachmentPreviewState
    extends State<MessageImageAttachmentPreview> {
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
    return MediaPreviewCache.instance.loadImageThumbnail(widget.attachment.url);
  }

  void _handleDecodeError(File file) {
    if (_decodeRetryCount >= _maxDecodeRetries) {
      unawaited(
        MediaPreviewCache.instance.invalidateImageThumbnail(
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
      MediaPreviewCache.instance.invalidateImageThumbnail(
        widget.attachment.url,
      ),
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
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 160,
          height: 160,
          child: _disableCachePreview
              ? _RawAttachmentImage(
                  url: widget.attachment.url,
                  width: 160,
                  height: 160,
                  fallback: widget.fallback,
                )
              : FutureBuilder<File?>(
                  future: _thumbnailFuture,
                  builder: (context, snapshot) {
                    final file = snapshot.data;
                    if (file != null) {
                      return Image.file(
                        file,
                        width: 160,
                        height: 160,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) {
                          _handleDecodeError(file);
                          return _RawAttachmentImage(
                            url: widget.attachment.url,
                            width: 160,
                            height: 160,
                            fallback: widget.fallback,
                          );
                        },
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey5.resolveFrom(
                            context,
                          ),
                        ),
                        child: const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                      );
                    }
                    return _RawAttachmentImage(
                      url: widget.attachment.url,
                      width: 160,
                      height: 160,
                      fallback: widget.fallback,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _RawAttachmentImage extends StatelessWidget {
  const _RawAttachmentImage({
    required this.url,
    required this.width,
    required this.height,
    required this.fallback,
  });

  final String url;
  final double width;
  final double height;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (MediaPreviewCache.instance.isKnownInvalidImageUrl(url)) {
      return fallback;
    }

    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      headers: attachmentRequestHeadersForUrl(url),
      errorBuilder: (_, _, _) {
        MediaPreviewCache.instance.markInvalidImageUrl(url);
        return fallback;
      },
    );
  }
}
