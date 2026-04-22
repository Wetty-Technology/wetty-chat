import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/shared/presentation/sticker_image_widget.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:flutter/cupertino.dart';

import 'bubble_theme_v2.dart';
import 'parts/meta_footer.dart';
import 'parts/reactions.dart';
import 'parts/reply_quote.dart';
import 'parts/thread_indicator.dart';

class StickerBubbleV2 extends StatelessWidget {
  const StickerBubbleV2({
    super.key,
    required this.message,
    required this.theme,
    required this.isMe,
    this.onTapReply,
    this.onOpenThread,
    this.onToggleReaction,
  });

  final ConversationMessageV2 message;
  final BubbleThemeV2 theme;
  final bool isMe;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final ValueChanged<String>? onToggleReaction;

  static const double _stickerSize = 160;
  static const FontWeight _bubbleFontWeight = FontWeight.w400;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: theme.maxBubbleWidth),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (message.isDeleted) {
      return Text(
        '[Deleted]',
        style: appBubbleTextStyle(
          context,
          color: theme.metaColor,
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
        ReplyQuote(
          reply: message.replyToMessage!,
          textColor: theme.textColor,
          isMe: isMe,
          variant: ReplyQuoteVariant.overSticker,
          onTap: onTapReply,
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
              child: MetaFooter(message: message, theme: theme, isMe: isMe),
            ),
          ),
        ],
      ),
    ];

    final threadInfo = message.threadInfo;
    if (threadInfo != null && threadInfo.replyCount > 0) {
      children.add(const SizedBox(height: 4));
      children.add(
        ThreadIndicator(
          threadInfo: threadInfo,
          isMe: isMe,
          textColor: theme.textColor,
          onTap: onOpenThread,
        ),
      );
    }

    if (message.reactions.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(
        BubbleReactions(
          reactions: message.reactions,
          maxBubbleWidth: theme.maxBubbleWidth,
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
