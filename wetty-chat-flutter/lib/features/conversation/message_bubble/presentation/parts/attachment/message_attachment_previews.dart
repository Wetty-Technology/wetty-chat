import 'package:flutter/cupertino.dart';

import 'package:chahua/core/cache/app_cached_network_image.dart';
import 'package:chahua/features/chats/models/message_models.dart';

class AttachmentPreviewLayout {
  const AttachmentPreviewLayout({required this.width, required this.height});

  final double width;
  final double height;
}

AttachmentPreviewLayout? computeAttachmentPreviewLayout(
  AttachmentItem attachment, {
  required double maxWidth,
  double maxHeight = 300,
}) {
  final width = attachment.width?.toDouble();
  final height = attachment.height?.toDouble();
  if (width == null || height == null || width <= 0 || height <= 0) {
    return null;
  }

  final aspectRatio = width / height;
  var resolvedWidth = height > maxHeight ? maxHeight * aspectRatio : width;
  var resolvedHeight = resolvedWidth / aspectRatio;

  if (resolvedWidth > maxWidth) {
    resolvedWidth = maxWidth;
    resolvedHeight = resolvedWidth / aspectRatio;
  }

  if (resolvedHeight > maxHeight) {
    resolvedHeight = maxHeight;
    resolvedWidth = resolvedHeight * aspectRatio;
  }

  return AttachmentPreviewLayout(width: resolvedWidth, height: resolvedHeight);
}

class MessageImageAttachmentPreview extends StatelessWidget {
  const MessageImageAttachmentPreview({
    super.key,
    required this.attachment,
    required this.onTap,
    required this.fallback,
    required this.maxWidth,
    this.maxHeight = 300,
    this.heroTag,
  });

  final AttachmentItem attachment;
  final VoidCallback onTap;
  final Widget fallback;
  final double maxWidth;
  final double maxHeight;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final layout = computeAttachmentPreviewLayout(
      attachment,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    final previewWidth = layout?.width ?? maxWidth.clamp(0, 220).toDouble();
    final previewHeight = layout?.height ?? maxHeight.clamp(0, 220).toDouble();
    final cacheWidth = (previewWidth * 2).round();

    Widget preview = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
        ),
        child: SizedBox(
          width: previewWidth,
          height: previewHeight,
          child: AppCachedNetworkImage(
            imageUrl: attachment.url,
            width: previewWidth,
            height: previewHeight,
            memCacheWidth: cacheWidth,
            fit: BoxFit.contain,
            placeholder: (context, url) =>
                const Center(child: CupertinoActivityIndicator()),
            errorWidget: (context, url, error) => fallback,
          ),
        ),
      ),
    );
    if (heroTag != null) {
      preview = Hero(tag: heroTag!, child: preview);
    }

    return GestureDetector(onTap: onTap, child: preview);
  }
}
