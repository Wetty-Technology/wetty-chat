import 'package:flutter/cupertino.dart';

import '../../../../../app/theme/style_config.dart';
import '../../../models/message_models.dart';
import '../../../models/message_preview_formatter.dart';
import '../../domain/conversation_message.dart';
import 'message_bubble_presentation.dart';
import 'message_reactions.dart';
import 'message_thread_indicator.dart';
import 'sticker_image_widget.dart';

class StickerMessageBubble extends StatelessWidget {
  const StickerMessageBubble({
    super.key,
    required this.message,
    required this.presentation,
    required this.isMe,
    this.onTapSticker,
    this.onTapReply,
    this.onOpenThread,
    this.onToggleReaction,
  });

  final ConversationMessage message;
  final MessageBubblePresentation presentation;
  final bool isMe;
  final VoidCallback? onTapSticker;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final ValueChanged<String>? onToggleReaction;

  static const double _stickerSize = 160;
  static const FontWeight _bubbleFontWeight = FontWeight.w400;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _buildDeletedSticker(context);
    }

    final children = <Widget>[
      if (message.replyToMessage != null)
        GestureDetector(
          onTap: onTapReply,
          child: _buildReplyQuote(context, message.replyToMessage!),
        ),
      _buildStickerContent(context),
    ];

    final threadInfo = message.threadInfo;
    if (threadInfo != null &&
        threadInfo.replyCount > 0 &&
        onOpenThread != null) {
      children.add(const SizedBox(height: 4));
      children.add(
        MessageThreadIndicator(
          threadInfo: threadInfo,
          isMe: isMe,
          presentation: presentation,
          onTap: onOpenThread,
        ),
      );
    }

    if (message.reactions.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(
        MessageReactions(
          reactions: message.reactions,
          maxBubbleWidth: presentation.maxBubbleWidth,
          isMe: isMe,
          isInteractive: false,
          onToggleReaction: onToggleReaction,
        ),
      );
    }

    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildStickerContent(BuildContext context) {
    final sticker = message.sticker;
    return GestureDetector(
      onTap: onTapSticker,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: StickerImage(
              media: sticker?.media,
              emoji: sticker?.emoji,
              size: _stickerSize,
            ),
          ),
          Positioned(right: 4, bottom: 4, child: _buildTimestampChip(context)),
        ],
      ),
    );
  }

  Widget _buildTimestampChip(BuildContext context) {
    final showDeliveryStatus = isMe && !message.isFailed;
    final isConfirmed = message.serverMessageId != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: CupertinoColors.black.withAlpha(110),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.isEdited)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Text('edited', style: _metaStyle(context)),
            ),
          Text(presentation.timeStr, style: _metaStyle(context)),
          if (showDeliveryStatus) ...[
            const SizedBox(width: MessageBubblePresentation.statusIconGap),
            Icon(
              isConfirmed
                  ? CupertinoIcons.checkmark_alt_circle_fill
                  : CupertinoIcons.checkmark_alt_circle,
              size: MessageBubblePresentation.statusIconSize,
              color: CupertinoColors.white.withAlpha(217),
            ),
          ],
        ],
      ),
    );
  }

  TextStyle _metaStyle(BuildContext context) {
    return appBubbleTextStyle(
      context,
      color: CupertinoColors.white.withAlpha(230),
      fontSize: AppFontSizes.bubbleMeta,
      fontWeight: _bubbleFontWeight,
    );
  }

  Widget _buildReplyQuote(BuildContext context, ReplyToMessage reply) {
    final replySender = reply.sender.name ?? 'User ${reply.sender.uid}';
    final quoteBackground = CupertinoColors.black.withAlpha(20);
    final quoteBorder = CupertinoColors.systemGrey;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: quoteBackground,
        border: Border(left: BorderSide(color: quoteBorder, width: 3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            replySender,
            style: appBubbleTextStyle(
              context,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: presentation.textColor.withAlpha(217),
            ),
          ),
          Text(
            formatReplyPreview(reply),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appBubbleTextStyle(
              context,
              fontSize: 12,
              fontWeight: _bubbleFontWeight,
              color: presentation.textColor.withAlpha(179),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedSticker(BuildContext context) {
    return Text(
      '[Deleted]',
      style: appBubbleTextStyle(
        context,
        color: presentation.metaColor,
        fontSize: AppFontSizes.bubbleText,
        fontStyle: FontStyle.italic,
        fontWeight: _bubbleFontWeight,
      ),
    );
  }
}
