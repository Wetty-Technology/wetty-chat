import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/message_models.dart';
import '../data/media_preview_cache.dart';

class AttachmentViewerPage extends StatefulWidget {
  const AttachmentViewerPage({super.key, required this.attachment});

  final AttachmentItem attachment;

  @override
  State<AttachmentViewerPage> createState() => _AttachmentViewerPageState();
}

class _AttachmentViewerPageState extends State<AttachmentViewerPage> {
  late final Future<File?> _previewFuture;

  AttachmentItem get _attachment => widget.attachment;

  @override
  void initState() {
    super.initState();
    _previewFuture = MediaPreviewCache.instance.loadImagePreview(
      _attachment.url,
      maxDimension: MediaPreviewCache.imageViewerMaxDimension,
    );
  }

  Future<void> _openExternally() async {
    if (_attachment.url.isEmpty) {
      return;
    }
    await launchUrl(
      Uri.parse(_attachment.url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _attachment.fileName.isEmpty
        ? 'Attachment'
        : _attachment.fileName;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _openExternally,
          child: const Icon(CupertinoIcons.arrow_up_right_square),
        ),
      ),
      backgroundColor: CupertinoColors.black,
      child: SafeArea(
        child: Center(
          child: _attachment.isImage
              ? FutureBuilder<File?>(
                  future: _previewFuture,
                  builder: (context, snapshot) {
                    final file = snapshot.data;
                    if (file != null) {
                      return _ZoomableImageViewport(
                        imageWidth: _attachment.width?.toDouble(),
                        imageHeight: _attachment.height?.toDouble(),
                        child: Image.file(
                          file,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, _, _) => _RawAttachmentViewerImage(
                            attachment: _attachment,
                            onOpenExternally: _openExternally,
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CupertinoActivityIndicator();
                    }
                    return _RawAttachmentViewerImage(
                      attachment: _attachment,
                      onOpenExternally: _openExternally,
                    );
                  },
                )
              : _ErrorState(
                  title: 'Preview is not available',
                  onOpenExternally: _openExternally,
                ),
        ),
      ),
    );
  }
}

class _RawAttachmentViewerImage extends StatelessWidget {
  const _RawAttachmentViewerImage({
    required this.attachment,
    required this.onOpenExternally,
  });

  final AttachmentItem attachment;
  final Future<void> Function() onOpenExternally;

  @override
  Widget build(BuildContext context) {
    if (MediaPreviewCache.instance.isKnownInvalidImageUrl(attachment.url)) {
      return _ErrorState(
        title: 'Failed to load image',
        onOpenExternally: onOpenExternally,
      );
    }

    return _ZoomableImageViewport(
      imageWidth: attachment.width?.toDouble(),
      imageHeight: attachment.height?.toDouble(),
      child: Image.network(
        attachment.url,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        headers: attachmentRequestHeadersForUrl(attachment.url),
        errorBuilder: (_, _, _) {
          MediaPreviewCache.instance.markInvalidImageUrl(attachment.url);
          return _ErrorState(
            title: 'Failed to load image',
            onOpenExternally: onOpenExternally,
          );
        },
      ),
    );
  }
}

class _ZoomableImageViewport extends StatelessWidget {
  const _ZoomableImageViewport({
    required this.child,
    this.imageWidth,
    this.imageHeight,
  });

  final Widget child;
  final double? imageWidth;
  final double? imageHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final viewportHeight = constraints.maxHeight;
        final contentWidth = imageWidth ?? viewportWidth;
        final contentHeight = imageHeight ?? viewportHeight;

        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          boundaryMargin: const EdgeInsets.all(80),
          child: SizedBox(
            width: viewportWidth,
            height: viewportHeight,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: contentWidth,
                height: contentHeight,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.title, required this.onOpenExternally});

  final String title;
  final Future<void> Function() onOpenExternally;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 36,
            color: CupertinoColors.white,
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to preview this attachment',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CupertinoColors.systemGrey2.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: onOpenExternally,
            child: const Text('Open externally'),
          ),
        ],
      ),
    );
  }
}
