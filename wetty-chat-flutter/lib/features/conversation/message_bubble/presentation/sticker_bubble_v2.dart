import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/shared/presentation/sticker_image_widget.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:chahua/features/conversation/shared/presentation/conversation_presentation_scope.dart';
import 'package:flutter/cupertino.dart';

import '../domain/bubble_theme_v2.dart';
import 'parts/media_footer_chip.dart';
import 'parts/meta_footer.dart';
import 'parts/reactions.dart';
import 'parts/reply_quote.dart';
import 'parts/thread_indicator.dart';

class StickerBubbleV2 extends StatelessWidget {
  const StickerBubbleV2({
    super.key,
    required this.message,
    this.onTapReply,
    this.onOpenThread,
    this.onToggleReaction,
  });

  final ConversationMessageV2 message;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final ValueChanged<String>? onToggleReaction;

  static const double _stickerSize = 160;
  static const FontWeight _bubbleFontWeight = FontWeight.w400;

  @override
  Widget build(BuildContext context) {
    final theme = BubbleThemeV2.of(context);
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: theme.maxBubbleWidth),
        child: _buildContent(context, theme),
      ),
    );
  }

  Widget _buildContent(BuildContext context, BubbleThemeV2 theme) {
    final isThreadView =
        ConversationPresentationScope.maybeOf(context)?.isThreadView ?? false;
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
            child: MediaFooterChip(child: MetaFooter(message: message)),
          ),
        ],
      ),
    ];

    final threadInfo = message.threadInfo;
    if (!isThreadView && threadInfo != null && threadInfo.replyCount > 0) {
      children.add(const SizedBox(height: 4));
      children.add(
        ThreadIndicator(threadInfo: threadInfo, onTap: onOpenThread),
      );
    }

    if (message.reactions.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(
        BubbleReactions(
          reactions: message.reactions,
          interactive: false,
          onToggleReaction: onToggleReaction,
        ),
      );
    }

    return Column(
      crossAxisAlignment: theme.isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
