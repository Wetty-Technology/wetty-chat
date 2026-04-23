import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:flutter/cupertino.dart';

import '../../domain/bubble_theme_v2.dart';
import '../parts/reactions.dart';
import 'text_bubble_plain_content.dart';
import 'text_bubble_visual_only_content.dart';
import 'text_bubble_visual_with_text_content.dart';

String messageTextForBubble(MessageContent content) => switch (content) {
  TextMessageContent(:final text) => text,
  AudioMessageContent(:final text) => text ?? '',
  FileMessageContent(:final text) => text ?? '',
  InviteMessageContent(:final text) => text ?? '',
  SystemMessageContent(:final text) => text,
  StickerMessageContent() => '',
};

List<MentionInfo> mentionsForBubble(MessageContent content) =>
    switch (content) {
      TextMessageContent(:final mentions) => mentions,
      AudioMessageContent(:final mentions) => mentions,
      FileMessageContent(:final mentions) => mentions,
      InviteMessageContent(:final mentions) => mentions,
      _ => const <MentionInfo>[],
    };

List<AttachmentItem> attachmentsForBubble(MessageContent content) =>
    switch (content) {
      FileMessageContent(:final attachments) => attachments,
      _ => const <AttachmentItem>[],
    };

enum _TextBubbleDisplayMode { plainText, visualOnly, visualWithText, fileMixed }

class TextBubbleV2 extends StatelessWidget {
  const TextBubbleV2({
    super.key,
    required this.message,
    required this.showSenderName,
    this.onToggleReaction,
    this.onTapReply,
    this.onOpenThread,
  });

  final ConversationMessageV2 message;
  final bool showSenderName;
  final ValueChanged<String>? onToggleReaction;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;

  _TextBubbleDisplayMode _displayMode() {
    final attachments = attachmentsForBubble(message.content);
    if (attachments.isEmpty) {
      return _TextBubbleDisplayMode.plainText;
    }

    final hasOnlyVisualAttachments = attachments.every(
      (attachment) => attachment.isImage || attachment.isVideo,
    );
    if (!hasOnlyVisualAttachments) {
      return _TextBubbleDisplayMode.fileMixed;
    }

    final hasText = messageTextForBubble(message.content).trim().isNotEmpty;
    return hasText
        ? _TextBubbleDisplayMode.visualWithText
        : _TextBubbleDisplayMode.visualOnly;
  }

  @override
  Widget build(BuildContext context) {
    final theme = BubbleThemeV2.of(context);
    final displayMode = message.isDeleted
        ? _TextBubbleDisplayMode.plainText
        : _displayMode();
    const bubbleRadius = Radius.circular(18);
    const tailRadius = Radius.circular(4);
    final borderRadius = BorderRadius.only(
      topLeft: bubbleRadius,
      topRight: bubbleRadius,
      bottomLeft: !theme.isMe ? tailRadius : bubbleRadius,
      bottomRight: theme.isMe ? tailRadius : bubbleRadius,
    );

    final bubble = switch (displayMode) {
      _TextBubbleDisplayMode.visualOnly => IntrinsicWidth(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: theme.maxBubbleWidth),
          child: TextBubbleVisualOnlyContent(
            message: message,
            theme: theme,
            onTapReply: onTapReply,
            onOpenThread: onOpenThread,
          ),
        ),
      ),
      _TextBubbleDisplayMode.visualWithText => IntrinsicWidth(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: theme.maxBubbleWidth),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: DecoratedBox(
              decoration: BoxDecoration(color: theme.bubbleColor),
              child: DefaultTextStyle(
                style: appBubbleTextStyle(
                  context,
                  color: theme.textColor,
                  fontSize: theme.chatMessageFontSize,
                  height: 1.28,
                  fontWeight: FontWeight.w400,
                ),
                child: TextBubbleVisualWithTextContent(
                  message: message,
                  theme: theme,
                  showSenderName: showSenderName,
                  onTapReply: onTapReply,
                  onOpenThread: onOpenThread,
                ),
              ),
            ),
          ),
        ),
      ),
      _ => IntrinsicWidth(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: theme.maxBubbleWidth),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: theme.bubbleColor,
              borderRadius: borderRadius,
            ),
            child: DefaultTextStyle(
              style: appBubbleTextStyle(
                context,
                color: theme.textColor,
                fontSize: theme.chatMessageFontSize,
                height: 1.28,
                fontWeight: FontWeight.w400,
              ),
              child: TextBubblePlainContent(
                message: message,
                theme: theme,
                showSenderName: showSenderName,
                onTapReply: onTapReply,
                onOpenThread: onOpenThread,
              ),
            ),
          ),
        ),
      ),
    };

    if (message.reactions.isEmpty) {
      return bubble;
    }

    return Column(
      crossAxisAlignment: theme.isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        const SizedBox(height: 8),
        BubbleReactions(
          reactions: message.reactions,
          onToggleReaction: onToggleReaction,
        ),
      ],
    );
  }
}
