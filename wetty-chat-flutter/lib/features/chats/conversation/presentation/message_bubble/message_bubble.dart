import 'package:flutter/cupertino.dart';

import '../../domain/conversation_message.dart';
import '../../../../../app/theme/style_config.dart';
import '../../../models/message_models.dart';
import 'message_bubble_content.dart';
import 'message_bubble_presentation.dart';
import 'sticker_message_bubble.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.presentation,
    required this.chatMessageFontSize,
    required this.isMe,
    required this.showSenderName,
    required this.currentUserId,
    this.onTapSticker,
    this.onTapReply,
    this.onOpenThread,
    this.onOpenAttachment,
    this.onToggleReaction,
    this.onTapMention,
  });

  final ConversationMessage message;
  final MessageBubblePresentation presentation;
  final double chatMessageFontSize;
  final bool isMe;
  final bool showSenderName;
  final int? currentUserId;
  final VoidCallback? onTapSticker;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final ValueChanged<AttachmentItem>? onOpenAttachment;
  final ValueChanged<String>? onToggleReaction;
  final void Function(int uid, MentionInfo? mention)? onTapMention;

  static const FontWeight _bubbleFontWeight = FontWeight.w400;

  @override
  Widget build(BuildContext context) {
    if (message.messageType == 'sticker') {
      return _buildStickerBubble();
    }
    return _buildStandardBubble(context);
  }

  Widget _buildStickerBubble() {
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: presentation.maxBubbleWidth),
        child: StickerMessageBubble(
          message: message,
          presentation: presentation,
          isMe: isMe,
          onTapSticker: onTapSticker,
          onTapReply: onTapReply,
          onOpenThread: onOpenThread,
          onToggleReaction: onToggleReaction,
        ),
      ),
    );
  }

  Widget _buildStandardBubble(BuildContext context) {
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
              currentUserId: currentUserId,
              onTapReply: onTapReply,
              onOpenThread: onOpenThread,
              onOpenAttachment: onOpenAttachment,
              onToggleReaction: onToggleReaction,
              onTapMention: onTapMention,
            ),
          ),
        ),
      ),
    );
  }
}
