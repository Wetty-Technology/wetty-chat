import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:flutter/cupertino.dart';

class MessageLongPressDetailsV2 {
  const MessageLongPressDetailsV2({
    required this.message,
    required this.bubbleRect,
    required this.isMe,
    required this.sourceShowsSenderName,
    Rect? visibleRect,
  }) : visibleRect = visibleRect ?? bubbleRect;

  MessageLongPressDetailsV2 copyWith({
    ConversationMessageV2? message,
    Rect? bubbleRect,
    bool? isMe,
    bool? sourceShowsSenderName,
    Rect? visibleRect,
  }) {
    final nextBubbleRect = bubbleRect ?? this.bubbleRect;
    return MessageLongPressDetailsV2(
      message: message ?? this.message,
      bubbleRect: nextBubbleRect,
      isMe: isMe ?? this.isMe,
      sourceShowsSenderName:
          sourceShowsSenderName ?? this.sourceShowsSenderName,
      visibleRect: visibleRect ?? nextBubbleRect,
    );
  }

  final ConversationMessageV2 message;
  final Rect bubbleRect;
  final bool isMe;
  final bool sourceShowsSenderName;
  final Rect visibleRect;
}
