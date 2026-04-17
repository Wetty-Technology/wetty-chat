import 'dart:math' as math;

import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/chat_timestamp_formatter.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:flutter/cupertino.dart';

class MessageBubblePresentationV2 {
  const MessageBubblePresentationV2({
    required this.senderName,
    required this.timeText,
    required this.maxBubbleWidth,
    required this.bubbleColor,
    required this.textColor,
    required this.metaColor,
  });

  static const double maxRowWidthFactor = 0.80;
  static const double rowHorizontalPadding = 24;
  static const double avatarSlotWidth = 36;
  static const double avatarGap = 8;
  static const double statusIconSize = 14;
  static const double statusIconGap = 4;

  factory MessageBubblePresentationV2.fromContext({
    required BuildContext context,
    required ConversationMessageV2 message,
    required bool isMe,
  }) {
    final colors = context.appColors;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return MessageBubblePresentationV2(
      senderName: message.sender.name ?? 'User ${message.sender.uid}',
      timeText: formatChatMessageTime(context, message.createdAt),
      maxBubbleWidth: math.max(
        0,
        (screenWidth * maxRowWidthFactor) -
            rowHorizontalPadding -
            avatarSlotWidth -
            avatarGap,
      ),
      bubbleColor: isMe ? colors.chatSentBubble : colors.chatReceivedBubble,
      textColor: isMe ? colors.textOnAccent : colors.textPrimary,
      metaColor: isMe ? colors.chatSentMeta : colors.chatReceivedMeta,
    );
  }

  final String senderName;
  final String timeText;
  final double maxBubbleWidth;
  final Color bubbleColor;
  final Color textColor;
  final Color metaColor;
}
