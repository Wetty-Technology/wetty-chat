import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:chahua/features/chats/models/message_preview_formatter.dart';
import 'package:flutter/cupertino.dart';

enum ReplyQuoteVariant { inBubble, overSticker }

class ReplyQuote extends StatelessWidget {
  const ReplyQuote({
    super.key,
    required this.reply,
    required this.textColor,
    required this.isMe,
    this.variant = ReplyQuoteVariant.inBubble,
    this.onTap,
  });

  final ReplyToMessage reply;
  final Color textColor;
  final bool isMe;
  final ReplyQuoteVariant variant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final replySender = reply.sender.name ?? 'User ${reply.sender.uid}';
    final (backgroundColor, borderColor) = switch (variant) {
      ReplyQuoteVariant.inBubble => (
        isMe
            ? CupertinoColors.white.withAlpha(26)
            : CupertinoColors.black.withAlpha(15),
        isMe
            ? CupertinoColors.white.withAlpha(128)
            : CupertinoColors.activeBlue.resolveFrom(context),
      ),
      ReplyQuoteVariant.overSticker => (
        CupertinoColors.black.withAlpha(20),
        CupertinoColors.systemGrey,
      ),
    };

    final quote = Container(
      width: variant == ReplyQuoteVariant.inBubble ? double.infinity : null,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(left: BorderSide(color: borderColor, width: 3)),
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
              color: textColor.withAlpha(217),
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
              color: textColor.withAlpha(179),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return quote;
    }
    return GestureDetector(onTap: onTap, child: quote);
  }
}
