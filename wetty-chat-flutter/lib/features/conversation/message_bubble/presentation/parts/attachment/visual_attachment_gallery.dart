import 'dart:ui' as ui;

import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/core/cache/app_cached_network_image.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter/cupertino.dart';

import '../../../domain/bubble_theme_v2.dart';
import '../media_footer_chip.dart';
import 'attachment_gallery_layout_planner.dart';
import 'message_attachment_previews.dart';
import 'video_attachment_thumbnail.dart';
import 'video_popup_player.dart';

class VisualAttachmentGallery extends StatelessWidget {
  const VisualAttachmentGallery({
    super.key,
    required this.attachments,
    required this.theme,
    required this.maxWidth,
    this.overlayFooter,
    this.clipBorderRadius,
  });

  final List<AttachmentItem> attachments;
  final BubbleThemeV2 theme;
  final double maxWidth;
  final Widget? overlayFooter;
  final BorderRadius? clipBorderRadius;

  @override
  Widget build(BuildContext context) {
    final layoutPlan = buildAttachmentGalleryLayoutPlan(
      attachments,
      maxWidth: maxWidth,
    );
    Widget gallery = SizedBox(
      width: layoutPlan.width,
      height: layoutPlan.height,
      child: Stack(
        children: [
          for (final tile in layoutPlan.tiles)
            Positioned(
              left: tile.left,
              top: tile.top,
              child: _BubbleAttachmentPreview(
                attachment: tile.attachment,
                theme: theme,
                width: tile.width,
                height: tile.height,
                useFramedSingleLayout: layoutPlan.tiles.length == 1,
                showsOverflowOverlay: tile.showsOverflowOverlay,
                overflowCount: tile.overflowCount,
              ),
            ),
          if (overlayFooter != null)
            Positioned(
              right: 4,
              bottom: 4,
              child: MediaFooterChip(child: overlayFooter!),
            ),
        ],
      ),
    );
    if (clipBorderRadius != null) {
      gallery = ClipRRect(borderRadius: clipBorderRadius!, child: gallery);
    }

    return Align(alignment: Alignment.centerRight, child: gallery);
  }
}

class _BubbleAttachmentPreview extends StatelessWidget {
  const _BubbleAttachmentPreview({
    required this.attachment,
    required this.theme,
    required this.width,
    required this.height,
    required this.useFramedSingleLayout,
    required this.showsOverflowOverlay,
    required this.overflowCount,
  });

  final AttachmentItem attachment;
  final BubbleThemeV2 theme;
  final double width;
  final double height;
  final bool useFramedSingleLayout;
  final bool showsOverflowOverlay;
  final int overflowCount;

  @override
  Widget build(BuildContext context) {
    final fallback = _FileAttachmentTile(attachment: attachment, theme: theme);
    Widget child;
    if (attachment.isImage && attachment.url.isNotEmpty) {
      child = useFramedSingleLayout
          ? _FramedSingleImageAttachmentPreview(
              attachment: attachment,
              fallback: fallback,
              width: width,
              height: height,
            )
          : MessageImageAttachmentPreview(
              attachment: attachment,
              onTap: () {},
              fallback: fallback,
              maxWidth: width,
              maxHeight: height,
              frameWidth: width,
              frameHeight: height,
              borderRadius: null,
              fit: BoxFit.cover,
            );
    } else if (attachment.isVideo && attachment.url.isNotEmpty) {
      child = useFramedSingleLayout
          ? _FramedSingleVideoAttachmentPreview(
              attachment: attachment,
              width: width,
              height: height,
            )
          : VideoAttachmentPreview(
              attachment: attachment,
              maxWidth: width,
              maxHeight: height,
              frameWidth: width,
              frameHeight: height,
              borderRadius: null,
              fit: BoxFit.cover,
              onTap: () {},
            );
    } else {
      child = fallback;
    }

    if (!showsOverflowOverlay) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoColors.black.withAlpha(110),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Text(
              '+$overflowCount',
              style: appBubbleTextStyle(
                context,
                color: CupertinoColors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FramedSingleVideoAttachmentPreview extends StatelessWidget {
  const _FramedSingleVideoAttachmentPreview({
    required this.attachment,
    required this.width,
    required this.height,
  });

  final AttachmentItem attachment;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Transform.scale(
                scale: 1.08,
                child: VideoAttachmentThumbnail(
                  attachment: attachment,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoColors.black.withAlpha(72),
            ),
          ),
          VideoAttachmentPreview(
            attachment: attachment,
            onTap: () {},
            maxWidth: width,
            maxHeight: height,
            frameWidth: width,
            frameHeight: height,
            borderRadius: null,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

class _FramedSingleImageAttachmentPreview extends StatelessWidget {
  const _FramedSingleImageAttachmentPreview({
    required this.attachment,
    required this.fallback,
    required this.width,
    required this.height,
  });

  final AttachmentItem attachment;
  final Widget fallback;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cacheWidth = (width * 2).round();
    return GestureDetector(
      onTap: () {},
      child: DecoratedBox(
        decoration: const BoxDecoration(color: CupertinoColors.black),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _BlurredImageFill(
                attachment: attachment,
                fallback: fallback,
                cacheWidth: cacheWidth,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withAlpha(72),
                ),
              ),
              AppCachedNetworkImage(
                imageUrl: attachment.url,
                width: width,
                height: height,
                memCacheWidth: cacheWidth,
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                    const Center(child: CupertinoActivityIndicator()),
                errorWidget: (context, url, error) => fallback,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlurredImageFill extends StatelessWidget {
  const _BlurredImageFill({
    required this.attachment,
    required this.fallback,
    required this.cacheWidth,
  });

  final AttachmentItem attachment;
  final Widget fallback;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Transform.scale(
          scale: 1.08,
          child: AppCachedNetworkImage(
            imageUrl: attachment.url,
            memCacheWidth: cacheWidth,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => fallback,
          ),
        ),
      ),
    );
  }
}

class _FileAttachmentTile extends StatelessWidget {
  const _FileAttachmentTile({required this.attachment, required this.theme});

  final AttachmentItem attachment;
  final BubbleThemeV2 theme;

  static const FontWeight _attachmentFontWeight = FontWeight.w400;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.isMe
            ? context.appColors.chatAttachmentChipSent
            : context.appColors.chatAttachmentChipReceived,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            attachment.isAudio
                ? CupertinoIcons.mic_fill
                : attachment.isVideo
                ? CupertinoIcons.play_rectangle
                : CupertinoIcons.doc,
            size: 18,
            color: const Color(0xFF8B6D52),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.fileName.isEmpty ? 'Attachment' : attachment.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: appBubbleTextStyle(
                context,
                fontSize: AppFontSizes.bodySmall,
                fontWeight: _attachmentFontWeight,
                color: context.appColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
