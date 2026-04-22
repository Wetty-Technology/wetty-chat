import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:flutter/cupertino.dart';

import 'bubble_theme_v2.dart';
import 'sticker_bubble_v2.dart';
import 'system_bubble_v2.dart';
import 'text_bubble_v2.dart';
import 'voice_bubble_v2.dart';

class MessageBubbleV2 extends StatelessWidget {
  const MessageBubbleV2({
    super.key,
    required this.message,
    required this.isMe,
    required this.chatMessageFontSize,
    required this.showSenderName,
    this.onToggleReaction,
    this.onTapReply,
    this.onOpenThread,
  });

  final ConversationMessageV2 message;
  final bool isMe;
  final double chatMessageFontSize;
  final bool showSenderName;
  final ValueChanged<String>? onToggleReaction;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;

  @override
  Widget build(BuildContext context) {
    final theme = BubbleThemeV2.fromContext(
      context: context,
      message: message,
      isMe: isMe,
      chatMessageFontSize: chatMessageFontSize,
    );

    return switch (message.content) {
      SystemMessageContent() => SystemBubbleV2(message: message),
      StickerMessageContent() => StickerBubbleV2(
        message: message,
        theme: theme,
        isMe: isMe,
        onTapReply: onTapReply,
        onOpenThread: onOpenThread,
        onToggleReaction: onToggleReaction,
      ),
      AudioMessageContent() => VoiceBubbleV2(
        message: message,
        theme: theme,
        isMe: isMe,
        showSenderName: showSenderName,
        onTapReply: onTapReply,
        onOpenThread: onOpenThread,
        onToggleReaction: onToggleReaction,
      ),
      TextMessageContent() ||
      FileMessageContent() ||
      InviteMessageContent() => TextBubbleV2(
        message: message,
        theme: theme,
        isMe: isMe,
        chatMessageFontSize: chatMessageFontSize,
        showSenderName: showSenderName,
        onTapReply: onTapReply,
        onOpenThread: onOpenThread,
        onToggleReaction: onToggleReaction,
      ),
    };
  }
}
