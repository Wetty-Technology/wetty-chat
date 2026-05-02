import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:chahua/features/conversation/media/presentation/attachment_viewer_request.dart';
import 'package:flutter/cupertino.dart';

import '../../../domain/bubble_theme_v2.dart';
import 'visual_attachment_gallery.dart';

enum BubbleAttachmentSectionVariant { visualMedia, fileList }

class BubbleAttachmentSection extends StatelessWidget {
  const BubbleAttachmentSection({
    super.key,
    required this.attachments,
    required this.messageStableKey,
    required this.theme,
    required this.variant,
    this.maxWidth,
    this.overlayFooter,
    this.clipBorderRadius,
    this.onOpenAttachment,
  });

  final List<AttachmentItem> attachments;
  final String messageStableKey;
  final BubbleThemeV2 theme;
  final BubbleAttachmentSectionVariant variant;
  final double? maxWidth;
  final Widget? overlayFooter;
  final BorderRadius? clipBorderRadius;
  final ValueChanged<MessageAttachmentOpenRequest>? onOpenAttachment;

  MessageAttachmentOpenRequest _openRequestFor(AttachmentItem attachment) {
    return MessageAttachmentOpenRequest(
      attachment: attachment,
      viewerRequest: buildAttachmentViewerRequest(
        messageStableKey: messageStableKey,
        attachments: attachments,
        tappedAttachment: attachment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxAttachmentWidth = maxWidth ?? theme.maxBubbleWidth - 24;
    if (variant == BubbleAttachmentSectionVariant.visualMedia) {
      return VisualAttachmentGallery(
        attachments: attachments,
        messageStableKey: messageStableKey,
        theme: theme,
        maxWidth: maxAttachmentWidth,
        overlayFooter: overlayFooter,
        clipBorderRadius: clipBorderRadius,
        onOpenAttachment: onOpenAttachment,
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
            _FileAttachmentTile(
              attachment: attachments[index],
              theme: theme,
              onTap: onOpenAttachment == null
                  ? null
                  : () =>
                        onOpenAttachment!(_openRequestFor(attachments[index])),
            ),
          ],
        ],
      ),
    );
  }
}

class _FileAttachmentTile extends StatelessWidget {
  const _FileAttachmentTile({
    required this.attachment,
    required this.theme,
    this.onTap,
  });

  final AttachmentItem attachment;
  final BubbleThemeV2 theme;
  final VoidCallback? onTap;

  static const FontWeight _attachmentFontWeight = AppFontWeights.regular;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                attachment.fileName.isEmpty
                    ? 'Attachment'
                    : attachment.fileName,
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
      ),
    );
  }
}
