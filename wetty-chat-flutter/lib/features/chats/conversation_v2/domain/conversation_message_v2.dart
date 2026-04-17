import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/models/message_models.dart';

class ConversationMessageV2 {
  const ConversationMessageV2({
    required this.clientGeneratedId,
    required this.sender,
    required this.content,
    this.serverMessageId,
    this.createdAt,
    this.isEdited = false,
    this.isDeleted = false,
    this.replyToMessage,
    this.reactions = const <ReactionSummary>[],
    this.threadInfo,
    this.deliveryState = ConversationDeliveryState.sent,
  });

  final int? serverMessageId;
  final String clientGeneratedId;
  final Sender sender;
  final DateTime? createdAt;
  final bool isEdited;
  final bool isDeleted;
  final ReplyToMessage? replyToMessage;
  final List<ReactionSummary> reactions;
  final ThreadInfo? threadInfo;
  final ConversationDeliveryState deliveryState;
  final MessageContent content;

  String get stableKey {
    if (clientGeneratedId.isNotEmpty) {
      return 'client:$clientGeneratedId';
    }
    if (serverMessageId != null) {
      return 'server:$serverMessageId';
    }
    throw StateError('ConversationMessageV2 has no stable identity');
  }
}

sealed class MessageContent {
  const MessageContent();
}

class TextMessageContent extends MessageContent {
  const TextMessageContent({
    required this.text,
    this.mentions = const <MentionInfo>[],
  });

  final String text;
  final List<MentionInfo> mentions;
}

class AudioMessageContent extends MessageContent {
  const AudioMessageContent({
    required this.audio,
    this.text,
    this.mentions = const <MentionInfo>[],
  });

  final AttachmentItem audio;
  final String? text;
  final List<MentionInfo> mentions;
}

class FileMessageContent extends MessageContent {
  const FileMessageContent({
    this.text,
    this.attachments = const <AttachmentItem>[],
    this.mentions = const <MentionInfo>[],
  });

  final String? text;
  final List<AttachmentItem> attachments;
  final List<MentionInfo> mentions;
}

class StickerMessageContent extends MessageContent {
  const StickerMessageContent({required this.sticker});

  final StickerSummary sticker;
}

class InviteMessageContent extends MessageContent {
  const InviteMessageContent({
    this.text,
    this.mentions = const <MentionInfo>[],
  });

  final String? text;
  final List<MentionInfo> mentions;
}

class SystemMessageContent extends MessageContent {
  const SystemMessageContent({required this.text});

  final String text;
}
