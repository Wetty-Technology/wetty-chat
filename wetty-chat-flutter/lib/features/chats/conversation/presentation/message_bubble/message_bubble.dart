import 'package:flutter/cupertino.dart';

import '../../domain/conversation_message.dart';
import '../../../../../app/theme/style_config.dart';
import '../../../models/message_models.dart';
import 'message_bubble_content.dart';
import 'message_bubble_presentation.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.presentation,
    required this.chatMessageFontSize,
    required this.isMe,
    required this.showSenderName,
    this.onTapReply,
    this.onOpenThread,
    this.onOpenAttachment,
  });

  final ConversationMessage message;
  final MessageBubblePresentation presentation;
  final double chatMessageFontSize;
  final bool isMe;
  final bool showSenderName;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final ValueChanged<AttachmentItem>? onOpenAttachment;

  static const FontWeight _bubbleFontWeight = FontWeight.w400;

  @override
  Widget build(BuildContext context) {
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
            child: MessageBubbleContent(
              message: message,
              presentation: presentation,
              chatMessageFontSize: chatMessageFontSize,
              isMe: isMe,
              showSenderName: showSenderName,
              onTapReply: onTapReply,
              onOpenThread: onOpenThread,
              onOpenAttachment: onOpenAttachment,
            ),
          ),
        ),
      ),
    );
  }
}
