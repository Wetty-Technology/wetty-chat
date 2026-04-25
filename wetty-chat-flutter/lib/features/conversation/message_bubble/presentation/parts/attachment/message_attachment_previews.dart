import 'package:flutter/cupertino.dart';

import 'package:chahua/core/cache/app_cached_network_image.dart';
import 'package:chahua/features/shared/model/message/message.dart';

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
    this.fit = BoxFit.contain,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.frameWidth,
    this.frameHeight,
  });

  final AttachmentItem attachment;
  final VoidCallback onTap;
  final Widget fallback;
  final double maxWidth;
  final double maxHeight;
  final String? heroTag;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double? frameWidth;
  final double? frameHeight;

  @override
  Widget build(BuildContext context) {
    final layout = computeAttachmentPreviewLayout(
      attachment,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    final previewWidth =
        frameWidth ?? layout?.width ?? maxWidth.clamp(0, 220).toDouble();
    final previewHeight =
        frameHeight ?? layout?.height ?? maxHeight.clamp(0, 220).toDouble();
    final cacheWidth = (previewWidth * 2).round();

    Widget preview = DecoratedBox(
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
          fit: fit,
          placeholder: (context, url) =>
              const Center(child: CupertinoActivityIndicator()),
          errorWidget: (context, url, error) => fallback,
        ),
      ),
    );
    if (borderRadius != null) {
      preview = ClipRRect(borderRadius: borderRadius!, child: preview);
    }
    if (heroTag != null) {
      preview = Hero(tag: heroTag!, child: preview);
    }

    return GestureDetector(onTap: onTap, child: preview);
  }
}
