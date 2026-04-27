import 'package:chahua/core/settings/app_settings_store.dart';
import 'package:chahua/features/conversation/media/presentation/attachment_viewer_request.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/bubble_theme_v2.dart';
import 'sticker_bubble_v2.dart';
import 'system_bubble_v2.dart';
import 'text/text_bubble_v2.dart';
import 'voice_bubble_v2.dart';

class MessageItem extends ConsumerWidget {
  const MessageItem({
    super.key,
    required this.message,
    required this.isMe,
    required this.isInteractive,
    required this.showSenderName,
    this.timelineViewportWidth,
    this.onToggleReaction,
    this.onTapReply,
    this.onOpenThread,
    this.onOpenAttachment,
  });

  final ConversationMessageV2 message;
  final bool isMe;
  final bool isInteractive;
  final bool showSenderName;
  final double? timelineViewportWidth;
  final ValueChanged<String>? onToggleReaction;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final ValueChanged<MessageAttachmentOpenRequest>? onOpenAttachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatMessageFontSize = ref.watch(appSettingsProvider).fontSize;
    return BubbleThemeV2.fromContext(
      context: context,
      message: message,
      isMe: isMe,
      isInteractive: isInteractive,
      chatMessageFontSize: chatMessageFontSize,
      timelineViewportWidth: timelineViewportWidth,
      child: switch (message.content) {
        SystemMessageContent() => SystemBubbleV2(message: message),
        StickerMessageContent() => StickerBubbleV2(
          message: message,
          onTapReply: onTapReply,
          onOpenThread: onOpenThread,
          onToggleReaction: onToggleReaction,
        ),
        AudioMessageContent() => VoiceBubbleV2(
          message: message,
          showSenderName: showSenderName,
          onTapReply: onTapReply,
          onOpenThread: onOpenThread,
          onToggleReaction: onToggleReaction,
        ),
        TextMessageContent() || InviteMessageContent() => TextBubbleV2(
          message: message,
          showSenderName: showSenderName,
          onTapReply: onTapReply,
          onOpenThread: onOpenThread,
          onToggleReaction: onToggleReaction,
          onOpenAttachment: onOpenAttachment,
        ),
      },
    );
  }
}
