import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter/cupertino.dart';

import '../../../domain/bubble_theme_v2.dart';
import 'message_attachment_previews.dart';
import 'video_popup_player.dart';

enum BubbleAttachmentSectionVariant { visualMedia, fileList }

class BubbleAttachmentSection extends StatelessWidget {
  const BubbleAttachmentSection({
    super.key,
    required this.attachments,
    required this.theme,
    required this.variant,
    this.overlayFooter,
  });

  final List<AttachmentItem> attachments;
  final BubbleThemeV2 theme;
  final BubbleAttachmentSectionVariant variant;
  final Widget? overlayFooter;

  @override
  Widget build(BuildContext context) {
    final maxAttachmentWidth = theme.maxBubbleWidth - 24;
    if (variant == BubbleAttachmentSectionVariant.visualMedia) {
      return _VisualAttachmentSection(
        attachments: attachments,
        theme: theme,
        maxAttachmentWidth: maxAttachmentWidth,
        overlayFooter: overlayFooter,
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < attachments.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _BubbleAttachmentPreview(
              attachment: attachments[index],
              theme: theme,
              maxAttachmentWidth: maxAttachmentWidth,
            ),
          ],
        ],
      ),
    );
  }
}

class _VisualAttachmentSection extends StatelessWidget {
  const _VisualAttachmentSection({
    required this.attachments,
    required this.theme,
    required this.maxAttachmentWidth,
    this.overlayFooter,
  });

  final List<AttachmentItem> attachments;
  final BubbleThemeV2 theme;
  final double maxAttachmentWidth;
  final Widget? overlayFooter;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < attachments.length; index++) ...[
                if (index > 0) const SizedBox(height: 8),
                _BubbleAttachmentPreview(
                  attachment: attachments[index],
                  theme: theme,
                  maxAttachmentWidth: maxAttachmentWidth,
                ),
              ],
            ],
          ),
          if (overlayFooter != null)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
    );
  }
}

class _BubbleAttachmentPreview extends StatelessWidget {
  const _BubbleAttachmentPreview({
    required this.attachment,
    required this.theme,
    required this.maxAttachmentWidth,
  });

  final AttachmentItem attachment;
  final BubbleThemeV2 theme;
  final double maxAttachmentWidth;

  @override
  Widget build(BuildContext context) {
    if (attachment.isVideo && attachment.url.isNotEmpty) {
      return VideoAttachmentPreview(
        attachment: attachment,
        maxWidth: maxAttachmentWidth,
        onTap: () {},
      );
    }
    if (attachment.isImage && attachment.url.isNotEmpty) {
      return MessageImageAttachmentPreview(
        attachment: attachment,
        onTap: () {},
        fallback: _FileAttachmentTile(attachment: attachment, theme: theme),
        maxWidth: maxAttachmentWidth,
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
