import 'dart:math' as math;

import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter/cupertino.dart';

import '../../../domain/bubble_theme_v2.dart';
import 'attachment_gallery_layout_plan.dart';
import 'message_attachment_previews.dart';
import 'video_popup_player.dart';

class VisualAttachmentGallery extends StatelessWidget {
  const VisualAttachmentGallery({
    super.key,
    required this.attachments,
    required this.theme,
    required this.maxWidth,
    this.overlayFooter,
  });

  final List<AttachmentItem> attachments;
  final BubbleThemeV2 theme;
  final double maxWidth;
  final Widget? overlayFooter;

  static const double _tileSpacing = 8;

  @override
  Widget build(BuildContext context) {
    final layoutPlan = _buildLayoutPlan(attachments, maxWidth: maxWidth);
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: layoutPlan.width,
        height: layoutPlan.height,
        child: Stack(
          children: [
            for (final tile in layoutPlan.tiles)
              Positioned(
                top: tile.topInset,
                right: 0,
                child: _BubbleAttachmentPreview(
                  attachment: tile.attachment,
                  theme: theme,
                  width: tile.width,
                  height: tile.height,
                ),
              ),
            if (overlayFooter != null)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.black.withAlpha(110),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DefaultTextStyle.merge(
                    style: appBubbleTextStyle(
                      context,
                      color: CupertinoColors.white,
                      fontSize: AppFontSizes.bubbleMeta,
                      fontWeight: FontWeight.w400,
                    ),
                    child: IconTheme.merge(
                      data: const IconThemeData(
                        color: CupertinoColors.white,
                        size: 14,
                      ),
                      child: overlayFooter!,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  AttachmentGalleryLayoutPlan _buildLayoutPlan(
    List<AttachmentItem> attachments, {
    required double maxWidth,
  }) {
    final tiles = <AttachmentGalleryTilePlan>[];
    var currentTopInset = 0.0;
    var maxResolvedWidth = 0.0;

    for (var index = 0; index < attachments.length; index++) {
      final attachment = attachments[index];
      final resolvedSize = _resolveTileSize(attachment, maxWidth: maxWidth);
      tiles.add(
        AttachmentGalleryTilePlan(
          attachment: attachment,
          width: resolvedSize.width,
          height: resolvedSize.height,
          topInset: currentTopInset,
        ),
      );
      maxResolvedWidth = math.max(maxResolvedWidth, resolvedSize.width);
      currentTopInset += resolvedSize.height;
      if (index < attachments.length - 1) {
        currentTopInset += _tileSpacing;
      }
    }

    return AttachmentGalleryLayoutPlan(
      width: maxResolvedWidth,
      height: currentTopInset,
      tiles: tiles,
    );
  }

  ({double width, double height}) _resolveTileSize(
    AttachmentItem attachment, {
    required double maxWidth,
  }) {
    final layout = computeAttachmentPreviewLayout(
      attachment,
      maxWidth: maxWidth,
    );
    final fallbackWidth = maxWidth.clamp(0, 220).toDouble();
    final fallbackHeight = 220.0;
    return (
      width: layout?.width ?? fallbackWidth,
      height: layout?.height ?? fallbackHeight,
    );
  }
}

class _BubbleAttachmentPreview extends StatelessWidget {
  const _BubbleAttachmentPreview({
    required this.attachment,
    required this.theme,
    required this.width,
    required this.height,
  });

  final AttachmentItem attachment;
  final BubbleThemeV2 theme;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (attachment.isVideo && attachment.url.isNotEmpty) {
      return VideoAttachmentPreview(
        attachment: attachment,
        maxWidth: width,
        maxHeight: height,
        onTap: () {},
      );
    }
    if (attachment.isImage && attachment.url.isNotEmpty) {
      return MessageImageAttachmentPreview(
        attachment: attachment,
        onTap: () {},
        fallback: _FileAttachmentTile(attachment: attachment, theme: theme),
        maxWidth: width,
        maxHeight: height,
      );
    }
    return _FileAttachmentTile(attachment: attachment, theme: theme);
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
