import 'dart:math' as math;

import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/chat_timestamp_formatter.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_message.dart'
    show ConversationDeliveryState;
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:flutter/cupertino.dart';

class MessageBubblePresentationV2 {
  static const double maxRowWidthFactor = 0.80;
  static const double rowHorizontalPadding = 24;
  static const double avatarSlotWidth = 36;
  static const double avatarGap = 8;
  static const double statusIconSize = 14;
  static const double statusIconGap = 4;
  static const double senderHeaderBadgeGap = 4;
  static const double senderHeaderBadgeSize = 11;
  static const double senderHeaderBodyGap = 4;
  static const double senderHeaderReservedHeight = 24;
  static const double threadIndicatorIconSize = 12;
  static const double threadIndicatorIconGap = 4;

  const MessageBubblePresentationV2({
    required this.senderName,
    required this.timeText,
    required this.maxBubbleWidth,
    required this.bubbleColor,
    required this.textColor,
    required this.metaColor,
    required this.linkColor,
    required this.timeSpacerWidth,
    required this.minBubbleContentHeight,
  });

  factory MessageBubblePresentationV2.fromContext({
    required BuildContext context,
    required ConversationMessageV2 message,
    required bool isMe,
    required double chatMessageFontSize,
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
      linkColor: isMe ? colors.chatLinkOnSent : colors.chatLinkOnReceived,
      timeSpacerWidth:
          measureMetaWidth(
            context,
            message,
            formatChatMessageTime(context, message.createdAt),
            isMe: isMe,
          ) +
          8,
      minBubbleContentHeight: chatMessageFontSize * 1.28,
    );
  }

  final String senderName;
  final String timeText;
  final double maxBubbleWidth;
  final Color bubbleColor;
  final Color textColor;
  final Color metaColor;
  final Color linkColor;
  final double timeSpacerWidth;
  final double minBubbleContentHeight;

  static double measureMetaWidth(
    BuildContext context,
    ConversationMessageV2 message,
    String timeStr, {
    required bool isMe,
  }) {
    final metaText = message.isEdited ? 'edited $timeStr' : timeStr;
    final metaPainter = TextPainter(
      text: TextSpan(
        text: metaText,
        style: appBubbleMetaTextStyle(
          context,
          fontSize: AppFontSizes.bubbleMeta,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    if (_showsDeliveryStatus(message, isMe: isMe)) {
      return metaPainter.width + statusIconGap + statusIconSize;
    }

    return metaPainter.width;
  }

  static bool _showsDeliveryStatus(
    ConversationMessageV2 message, {
    required bool isMe,
  }) => isMe && message.deliveryState != ConversationDeliveryState.failed;
}
