import 'package:chahua/core/api/models/messages_api_models.dart';

import 'attachment.dart';
import 'mention.dart';
import 'reaction.dart';
import 'reply_to_message.dart';
import 'sender.dart';
import 'sticker.dart';
import 'thread_info.dart';

export 'attachment.dart';
export 'mention.dart';
export 'message_item.dart';
export 'preview_formatter.dart';
export 'reaction.dart';
export 'reply_to_message.dart';
export 'sender.dart';
export 'sticker.dart';
export 'thread_info.dart';

enum ConversationDeliveryState {
  sending,
  sent,
  confirmed,
  failed,
  editing,
  deleting,
}

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
    this.deliveryState = ConversationDeliveryState.confirmed,
  });

  factory ConversationMessageV2.fromMessageItemDto(MessageItemDto dto) {
    final attachments = dto.attachments
        .map(AttachmentItem.fromDto)
        .toList(growable: false);
    final mentions = dto.mentions
        .map(MentionInfo.fromDto)
        .toList(growable: false);
    final sticker = dto.sticker == null
        ? null
        : StickerSummary.fromDto(dto.sticker!);

    return ConversationMessageV2(
      serverMessageId: dto.id,
      clientGeneratedId: dto.clientGeneratedId,
      sender: Sender.fromDto(dto.sender),
      createdAt: dto.createdAt,
      isEdited: dto.isEdited,
      isDeleted: dto.isDeleted,
      replyToMessage: dto.replyToMessage == null
          ? null
          : ReplyToMessage.fromDto(dto.replyToMessage!),
      reactions: dto.reactions
          .map(ReactionSummary.fromDto)
          .toList(growable: false),
      threadInfo: dto.threadInfo == null
          ? null
          : ThreadInfo.fromDto(dto.threadInfo!),
      deliveryState: ConversationDeliveryState.confirmed,
      content: _contentFromMessageItemDto(
        messageType: dto.messageType,
        message: dto.message,
        sticker: sticker,
        attachments: attachments,
        mentions: mentions,
      ),
    );
  }

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

  ConversationMessageV2 copyWith({
    int? serverMessageId,
    String? clientGeneratedId,
    Sender? sender,
    DateTime? createdAt,
    bool? isEdited,
    bool? isDeleted,
    ReplyToMessage? replyToMessage,
    List<ReactionSummary>? reactions,
    ThreadInfo? threadInfo,
    ConversationDeliveryState? deliveryState,
    MessageContent? content,
  }) {
    return ConversationMessageV2(
      serverMessageId: serverMessageId ?? this.serverMessageId,
      clientGeneratedId: clientGeneratedId ?? this.clientGeneratedId,
      sender: sender ?? this.sender,
      createdAt: createdAt ?? this.createdAt,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      reactions: reactions ?? this.reactions,
      threadInfo: threadInfo ?? this.threadInfo,
      deliveryState: deliveryState ?? this.deliveryState,
      content: content ?? this.content,
    );
  }

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

MessageContent _contentFromMessageItemDto({
  required String messageType,
  required String? message,
  required StickerSummary? sticker,
  required List<AttachmentItem> attachments,
  required List<MentionInfo> mentions,
}) {
  if (messageType == 'system') {
    return SystemMessageContent(text: message ?? '');
  }
  if (messageType == 'sticker') {
    if (sticker?.id == null) {
      throw StateError('Sticker messages must include a sticker id');
    }
    return StickerMessageContent(sticker: sticker!);
  }
  if (messageType == 'invite') {
    return InviteMessageContent(text: message, mentions: mentions);
  }
  if (attachments.length == 1 && attachments.single.isAudio) {
    return AudioMessageContent(
      audio: attachments.single,
      text: message,
      mentions: mentions,
    );
  }
  if (attachments.isNotEmpty) {
    return FileMessageContent(
      text: message,
      attachments: attachments,
      mentions: mentions,
    );
  }
  return TextMessageContent(text: message ?? '', mentions: mentions);
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
