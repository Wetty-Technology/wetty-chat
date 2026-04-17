import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/presentation/message_bubble/message_bubble_presentation_v2.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:chahua/features/chats/models/message_preview_formatter.dart';
import 'package:flutter/cupertino.dart';

class MessageBubbleV2 extends StatelessWidget {
  const MessageBubbleV2({super.key, required this.message, required this.isMe});

  final ConversationMessageV2 message;
  final bool isMe;

  static const FontWeight _bubbleFontWeight = FontWeight.w400;

  @override
  Widget build(BuildContext context) {
    final presentation = MessageBubblePresentationV2.fromContext(
      context: context,
      message: message,
      isMe: isMe,
    );

    const bubbleRadius = Radius.circular(18);
    const tailRadius = Radius.circular(4);
    final borderRadius = BorderRadius.only(
      topLeft: bubbleRadius,
      topRight: bubbleRadius,
      bottomLeft: !isMe ? tailRadius : bubbleRadius,
      bottomRight: isMe ? tailRadius : bubbleRadius,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: presentation.maxBubbleWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: presentation.bubbleColor,
          borderRadius: borderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SenderHeaderV2(
                senderName: presentation.senderName,
                textColor: presentation.textColor,
              ),
              const SizedBox(height: 4),
              if (message.replyToMessage != null) ...[
                _ReplyPreviewV2(
                  reply: message.replyToMessage!,
                  presentation: presentation,
                  isMe: isMe,
                ),
                const SizedBox(height: 6),
              ],
              if (message.isDeleted)
                Text(
                  '[Deleted]',
                  style: appBubbleTextStyle(
                    context,
                    color: presentation.metaColor,
                    fontSize: AppFontSizes.bubbleText,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Text(
                  _messageText(message.content),
                  style: appBubbleTextStyle(
                    context,
                    color: presentation.textColor,
                    fontSize: AppFontSizes.bubbleText,
                    height: 1.28,
                    fontWeight: _bubbleFontWeight,
                  ),
                ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: _MessageMetaV2(
                  message: message,
                  presentation: presentation,
                  isMe: isMe,
                ),
              ),
              if (message.threadInfo != null) ...[
                const SizedBox(height: 6),
                _ThreadIndicatorV2(
                  replyCount: message.threadInfo!.replyCount,
                  isMe: isMe,
                  textColor: presentation.textColor,
                ),
              ],
              if (message.reactions.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ReactionsRowV2(reactions: message.reactions, isMe: isMe),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _messageText(MessageContent content) => switch (content) {
    TextMessageContent(:final text) => text,
    AudioMessageContent(:final text, :final audio) =>
      text ?? '[Audio] ${audio.fileName}',
    FileMessageContent(:final text, :final attachments) =>
      text ?? '[Files] ${attachments.length} attachment(s)',
    StickerMessageContent(:final sticker) =>
      '[Sticker] ${sticker.emoji ?? sticker.name ?? 'sticker'}',
    InviteMessageContent(:final text) => text ?? '[Invite]',
    SystemMessageContent(:final text) => text,
  };
}

class _SenderHeaderV2 extends StatelessWidget {
  const _SenderHeaderV2({required this.senderName, required this.textColor});

  final String senderName;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      senderName,
      style: appBubbleTextStyle(
        context,
        fontWeight: FontWeight.w700,
        fontSize: AppFontSizes.body,
        color: textColor,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ReplyPreviewV2 extends StatelessWidget {
  const _ReplyPreviewV2({
    required this.reply,
    required this.presentation,
    required this.isMe,
  });

  final ReplyToMessage reply;
  final MessageBubblePresentationV2 presentation;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final quoteBackgroundColor = isMe
        ? CupertinoColors.white.withValues(alpha: 0.10)
        : CupertinoColors.black.withValues(alpha: 0.06);
    final quoteBorderColor = isMe
        ? CupertinoColors.white.withValues(alpha: 0.50)
        : CupertinoColors.activeBlue.resolveFrom(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: quoteBackgroundColor,
        border: Border(left: BorderSide(color: quoteBorderColor, width: 3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reply.sender.name ?? 'User ${reply.sender.uid}',
                  style: appBubbleTextStyle(
                    context,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: presentation.textColor.withValues(alpha: 0.85),
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
                    color: presentation.textColor.withValues(alpha: 0.70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageMetaV2 extends StatelessWidget {
  const _MessageMetaV2({
    required this.message,
    required this.presentation,
    required this.isMe,
  });

  final ConversationMessageV2 message;
  final MessageBubblePresentationV2 presentation;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final deliveryIndicator = switch (message.deliveryState) {
      ConversationDeliveryState.sending => Icon(
        CupertinoIcons.checkmark_alt_circle,
        size: MessageBubblePresentationV2.statusIconSize,
        color: presentation.metaColor,
      ),
      ConversationDeliveryState.sent => Icon(
        CupertinoIcons.checkmark_alt_circle,
        size: MessageBubblePresentationV2.statusIconSize,
        color: presentation.metaColor,
      ),
      ConversationDeliveryState.confirmed => Icon(
        CupertinoIcons.checkmark_alt_circle_fill,
        size: MessageBubblePresentationV2.statusIconSize,
        color: presentation.metaColor,
      ),
      _ => null,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Text(
              'edited',
              style: appBubbleTextStyle(
                context,
                color: presentation.metaColor,
                fontSize: AppFontSizes.bubbleMeta,
              ),
            ),
          ),
        Text(
          presentation.timeText,
          style: appBubbleTextStyle(
            context,
            color: presentation.metaColor,
            fontSize: AppFontSizes.bubbleMeta,
          ),
        ),
        if (isMe && deliveryIndicator != null) ...[
          const SizedBox(width: MessageBubblePresentationV2.statusIconGap),
          deliveryIndicator,
        ],
      ],
    );
  }
}

class _ThreadIndicatorV2 extends StatelessWidget {
  const _ThreadIndicatorV2({
    required this.replyCount,
    required this.isMe,
    required this.textColor,
  });

  final int replyCount;
  final bool isMe;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final borderColor = isMe
        ? CupertinoColors.white.withValues(alpha: 0.2)
        : CupertinoColors.black.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Opacity(
        opacity: 0.8,
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Icon(CupertinoIcons.chat_bubble_2, size: 12, color: textColor),
            const SizedBox(width: 4),
            Text(
              '$replyCount repl${replyCount == 1 ? 'y' : 'ies'}',
              style: appBubbleTextStyle(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionsRowV2 extends StatelessWidget {
  const _ReactionsRowV2({required this.reactions, required this.isMe});

  final List<ReactionSummary> reactions;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: reactions
          .map((reaction) {
            final background = isMe
                ? (reaction.reactedByMe == true
                      ? colors.chatReactionSentActive
                      : colors.chatReactionSent)
                : (reaction.reactedByMe == true
                      ? colors.chatReactionReceivedActive
                      : colors.chatReactionReceived);
            final foreground = isMe || reaction.reactedByMe == true
                ? colors.textOnAccent
                : colors.textPrimary;

            return DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '${reaction.emoji} ${reaction.count}',
                  style: appBubbleTextStyle(
                    context,
                    color: foreground,
                    fontSize: AppFontSizes.meta,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}
