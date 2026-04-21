import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/shared/presentation/sticker_image_widget.dart';
import 'package:chahua/features/chats/models/message_preview_formatter.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter/cupertino.dart';

import '../../domain/conversation_message_v2.dart';
import 'message_bubble_meta_v2.dart';
import 'message_bubble_presentation_v2.dart';
import 'message_reactions_v2.dart';
import 'message_render_spec_v2.dart';
import 'message_thread_indicator_v2.dart';

class StickerMessageBubbleV2 extends StatelessWidget {
  const StickerMessageBubbleV2({
    super.key,
    required this.message,
    required this.presentation,
    required this.isMe,
    required this.renderSpec,
    this.onTapReply,
    this.onOpenThread,
    this.onToggleReaction,
  });

  final ConversationMessageV2 message;
  final MessageBubblePresentationV2 presentation;
  final bool isMe;
  final MessageRenderSpecV2 renderSpec;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final ValueChanged<String>? onToggleReaction;

  static const double _stickerSize = 160;
  static const FontWeight _bubbleFontWeight = FontWeight.w400;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
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

    final sticker = switch (message.content) {
      StickerMessageContent(:final sticker) => sticker,
      _ => null,
    };

    final children = <Widget>[
      if (message.replyToMessage != null)
        GestureDetector(
          onTap: onTapReply,
          child: _StickerReplyQuoteV2(
            reply: message.replyToMessage!,
            presentation: presentation,
          ),
        ),
      Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: StickerImage(
              media: sticker?.media,
              emoji: sticker?.emoji,
              size: _stickerSize,
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: CupertinoColors.black.withAlpha(110),
                borderRadius: BorderRadius.circular(8),
              ),
              child: MessageBubbleMetaV2(
                message: message,
                presentation: presentation,
                isMe: isMe,
              ),
            ),
          ),
        ],
      ),
    ];

    if (renderSpec.showThreadIndicator &&
        message.threadInfo != null &&
        message.threadInfo!.replyCount > 0) {
      children.add(const SizedBox(height: 4));
      children.add(
        MessageThreadIndicatorV2(
          threadInfo: message.threadInfo!,
          isMe: isMe,
          presentation: presentation,
          onTap: renderSpec.isInteractive ? onOpenThread : null,
        ),
      );
    }

    if (renderSpec.showReactions && message.reactions.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(
        MessageReactionsV2(
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
}

class _StickerReplyQuoteV2 extends StatelessWidget {
  const _StickerReplyQuoteV2({required this.reply, required this.presentation});

  final ReplyToMessage reply;
  final MessageBubblePresentationV2 presentation;

  @override
  Widget build(BuildContext context) {
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
              fontWeight: FontWeight.w400,
              color: presentation.textColor.withAlpha(179),
            ),
          ),
        ],
      ),
    );
  }
}
