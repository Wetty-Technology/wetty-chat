import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:flutter/cupertino.dart';

import 'message_bubble_content_v2.dart';
import 'message_bubble_presentation_v2.dart';
import 'message_render_spec_v2.dart';
import 'sticker_message_bubble_v2.dart';

class MessageBubbleV2 extends StatelessWidget {
  const MessageBubbleV2({
    super.key,
    required this.message,
    required this.isMe,
    required this.chatMessageFontSize,
    required this.showSenderName,
    this.onTapReply,
    this.onOpenThread,
  });

  final ConversationMessageV2 message;
  final bool isMe;
  final double chatMessageFontSize;
  final bool showSenderName;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;

  static const FontWeight _bubbleFontWeight = FontWeight.w400;

  @override
  Widget build(BuildContext context) {
    final presentation = MessageBubblePresentationV2.fromContext(
      context: context,
      message: message,
      isMe: isMe,
      chatMessageFontSize: chatMessageFontSize,
    );
    final renderSpec = MessageRenderSpecV2.timeline(
      message: message,
      showSenderName: showSenderName,
      showThreadIndicator: onOpenThread != null,
      // TODO(conversation_v2): revisit renderSpec interactivity so thread taps,
      // reactions, attachment opens, and future overlay gestures can be enabled
      // independently instead of sharing one coarse flag.
      isInteractive: true,
    );

    if (message.content is StickerMessageContent) {
      return IntrinsicWidth(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: presentation.maxBubbleWidth),
          child: StickerMessageBubbleV2(
            message: message,
            presentation: presentation,
            isMe: isMe,
            renderSpec: renderSpec,
            onTapReply: onTapReply,
            onOpenThread: onOpenThread,
          ),
        ),
      );
    }

    const bubbleRadius = Radius.circular(18);
    const tailRadius = Radius.circular(4);
    final borderRadius = BorderRadius.only(
      topLeft: bubbleRadius,
      topRight: bubbleRadius,
      bottomLeft: !isMe ? tailRadius : bubbleRadius,
      bottomRight: isMe ? tailRadius : bubbleRadius,
    );

    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: presentation.maxBubbleWidth),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: presentation.bubbleColor,
            borderRadius: borderRadius,
          ),
          child: DefaultTextStyle(
            style: appBubbleTextStyle(
              context,
              color: presentation.textColor,
              fontSize: chatMessageFontSize,
              height: 1.28,
              fontWeight: _bubbleFontWeight,
            ),
            child: MessageBubbleContentV2(
              message: message,
              presentation: presentation,
              chatMessageFontSize: chatMessageFontSize,
              isMe: isMe,
              renderSpec: renderSpec,
              onTapReply: onTapReply,
              onOpenThread: onOpenThread,
            ),
          ),
        ),
      ),
    );
  }
}
