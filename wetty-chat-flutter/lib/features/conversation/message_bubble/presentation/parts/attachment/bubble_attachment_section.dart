import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter/cupertino.dart';

import '../../../domain/bubble_theme_v2.dart';
import 'visual_attachment_gallery.dart';

enum BubbleAttachmentSectionVariant { visualMedia, fileList }

class BubbleAttachmentSection extends StatelessWidget {
  const BubbleAttachmentSection({
    super.key,
    required this.attachments,
    required this.theme,
    required this.variant,
    this.overlayFooter,
    this.clipBorderRadius,
  });

  final List<AttachmentItem> attachments;
  final BubbleThemeV2 theme;
  final BubbleAttachmentSectionVariant variant;
  final Widget? overlayFooter;
  final BorderRadius? clipBorderRadius;

  @override
  Widget build(BuildContext context) {
    final maxAttachmentWidth = theme.maxBubbleWidth - 24;
    if (variant == BubbleAttachmentSectionVariant.visualMedia) {
      return VisualAttachmentGallery(
        attachments: attachments,
        theme: theme,
        maxWidth: maxAttachmentWidth,
        overlayFooter: overlayFooter,
        clipBorderRadius: clipBorderRadius,
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
            _FileAttachmentTile(attachment: attachments[index], theme: theme),
          ],
        ],
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
