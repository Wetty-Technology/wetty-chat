import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:chahua/features/conversation/shared/presentation/conversation_presentation_scope.dart';
import 'package:flutter/cupertino.dart';

import '../domain/bubble_theme_v2.dart';
import 'parts/attachment/bubble_attachment_section.dart';
import 'parts/linkified_text.dart';
import 'parts/meta_footer.dart';
import 'parts/reactions.dart';
import 'parts/reply_quote.dart';
import 'parts/sender_header.dart';
import 'parts/thread_indicator.dart';

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

  static const FontWeight _bubbleFontWeight = FontWeight.w400;
  static const double _emptyBubbleMinWidth = 48;

  @override
  Widget build(BuildContext context) {
    final theme = BubbleThemeV2.of(context);
    const bubbleRadius = Radius.circular(18);
    const tailRadius = Radius.circular(4);
    final borderRadius = BorderRadius.only(
      topLeft: bubbleRadius,
      topRight: bubbleRadius,
      bottomLeft: !theme.isMe ? tailRadius : bubbleRadius,
      bottomRight: theme.isMe ? tailRadius : bubbleRadius,
    );

    final bubble = IntrinsicWidth(
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
              fontWeight: _bubbleFontWeight,
            ),
            child: _buildBubbleContent(context, theme),
          ),
        ),
      ),
    );

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

  Widget _buildBubbleContent(BuildContext context, BubbleThemeV2 theme) {
    final isThreadView =
        ConversationPresentationScope.maybeOf(context)?.isThreadView ?? false;
    final attachments = _attachmentsFor(message.content);
    final hasAttachments = attachments.isNotEmpty;
    final children = <Widget>[];

    if (showSenderName) {
      children.add(
        SenderHeader(
          senderName: message.sender.name ?? 'User ${message.sender.uid}',
          gender: message.sender.gender,
        ),
      );
      children.add(const SizedBox(height: senderHeaderBodyGap));
    }

    if (message.replyToMessage != null) {
      children.add(
        ReplyQuote(reply: message.replyToMessage!, onTap: onTapReply),
      );
    }

    if (message.isDeleted) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 4));
      }
      children.add(
        Text(
          '[Deleted]',
          style: appBubbleTextStyle(
            context,
            color: theme.metaColor,
            fontSize: theme.chatMessageFontSize,
            fontStyle: FontStyle.italic,
            fontWeight: _bubbleFontWeight,
          ),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }

    if (hasAttachments) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 8));
      }
      children.add(
        BubbleAttachmentSection(attachments: attachments, theme: theme),
      );
    }

    if (children.isNotEmpty &&
        (message.replyToMessage != null || hasAttachments)) {
      children.add(const SizedBox(height: 4));
    }
    children.add(_buildMessageBody(context, theme));

    final threadInfo = message.threadInfo;
    if (!isThreadView && threadInfo != null && threadInfo.replyCount > 0) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ThreadIndicator(threadInfo: threadInfo, onTap: onOpenThread),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildMessageBody(BuildContext context, BubbleThemeV2 theme) {
    final messageText = _messageTextFor(message.content);
    final mentions = _mentionsFor(message.content);
    final metaWidget = MetaFooter(message: message);

    if (messageText.trim().isEmpty) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: _emptyBubbleMinWidth,
          minHeight: theme.minBubbleContentHeight,
        ),
        child: Align(alignment: Alignment.bottomRight, child: metaWidget),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            LinkifiedText(
              text: messageText,
              textStyle: appBubbleTextStyle(
                context,
                color: theme.textColor,
                fontSize: theme.chatMessageFontSize,
                height: 1.28,
                fontWeight: _bubbleFontWeight,
              ),
              mentions: mentions,
              currentUserId: null,
            ),
            Positioned(right: 0, bottom: 0, child: metaWidget),
          ],
        ),
      ),
    );
  }
}

String _messageTextFor(MessageContent content) => switch (content) {
  TextMessageContent(:final text) => text,
  AudioMessageContent(:final text) => text ?? '',
  FileMessageContent(:final text) => text ?? '',
  InviteMessageContent(:final text) => text ?? '',
  SystemMessageContent(:final text) => text,
  StickerMessageContent() => '',
};

List<MentionInfo> _mentionsFor(MessageContent content) => switch (content) {
  TextMessageContent(:final mentions) => mentions,
  AudioMessageContent(:final mentions) => mentions,
  FileMessageContent(:final mentions) => mentions,
  InviteMessageContent(:final mentions) => mentions,
  _ => const <MentionInfo>[],
};

List<AttachmentItem> _attachmentsFor(MessageContent content) =>
    switch (content) {
      FileMessageContent(:final attachments) => attachments,
      _ => const <AttachmentItem>[],
    };
