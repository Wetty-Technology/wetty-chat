import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';

enum MessageRenderSurfaceV2 { timeline }

class MessageRenderSpecV2 {
  const MessageRenderSpecV2({
    required this.surface,
    required this.showSenderName,
    required this.showReplyQuote,
    required this.showAttachments,
    required this.showBody,
    required this.showMeta,
    required this.showThreadIndicator,
    required this.showReactions,
    required this.isInteractive,
  });

  factory MessageRenderSpecV2.timeline({
    required ConversationMessageV2 message,
    required bool showSenderName,
    required bool showThreadIndicator,
    required bool isInteractive,
  }) {
    final content = message.content;
    final hasAttachments = switch (content) {
      AudioMessageContent() => true,
      FileMessageContent(:final attachments) => attachments.isNotEmpty,
      _ => false,
    };
    final hasBody = switch (content) {
      TextMessageContent(:final text) => text.trim().isNotEmpty,
      AudioMessageContent(:final text) => text?.trim().isNotEmpty ?? false,
      FileMessageContent(:final text) => text?.trim().isNotEmpty ?? false,
      InviteMessageContent(:final text) => text?.trim().isNotEmpty ?? false,
      SystemMessageContent(:final text) => text.trim().isNotEmpty,
      StickerMessageContent() => false,
    };

    return MessageRenderSpecV2(
      surface: MessageRenderSurfaceV2.timeline,
      showSenderName: showSenderName,
      showReplyQuote: message.replyToMessage != null,
      showAttachments: hasAttachments,
      showBody: hasBody,
      showMeta: !message.isDeleted,
      showThreadIndicator:
          message.threadInfo != null &&
          message.threadInfo!.replyCount > 0 &&
          showThreadIndicator,
      showReactions: message.reactions.isNotEmpty,
      isInteractive: isInteractive,
    );
  }

  final MessageRenderSurfaceV2 surface;
  final bool showSenderName;
  final bool showReplyQuote;
  final bool showAttachments;
  final bool showBody;
  final bool showMeta;
  final bool showThreadIndicator;
  final bool showReactions;
  final bool isInteractive;
}
