import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/messages_api_models.dart';

import 'attachment.dart';
import 'mention.dart';
import 'reaction.dart';
import 'reply_to_message.dart';
import 'sender.dart';
import 'sticker.dart';
import 'thread_info.dart';

part 'message_item.freezed.dart';

@freezed
abstract class MessageItem with _$MessageItem {
  const factory MessageItem({
    required int id,
    String? message,
    required String messageType,
    StickerSummary? sticker,
    required Sender sender,
    required String chatId,
    DateTime? createdAt,
    @Default(false) bool isEdited,
    @Default(false) bool isDeleted,
    @Default('') String clientGeneratedId,
    int? replyRootId,
    @Default(false) bool hasAttachments,
    ReplyToMessage? replyToMessage,
    @Default([]) List<AttachmentItem> attachments,
    @Default([]) List<ReactionSummary> reactions,
    @Default([]) List<MentionInfo> mentions,
    ThreadInfo? threadInfo,
  }) = _MessageItem;

  factory MessageItem.fromDto(MessageItemDto dto) => MessageItem(
    id: dto.id,
    message: dto.message,
    messageType: dto.messageType,
    sticker: dto.sticker == null ? null : StickerSummary.fromDto(dto.sticker!),
    sender: Sender.fromDto(dto.sender),
    chatId: dto.chatId.toString(),
    createdAt: dto.createdAt,
    isEdited: dto.isEdited,
    isDeleted: dto.isDeleted,
    clientGeneratedId: dto.clientGeneratedId,
    replyRootId: dto.replyRootId,
    hasAttachments: dto.hasAttachments,
    replyToMessage: dto.replyToMessage == null
        ? null
        : ReplyToMessage.fromDto(dto.replyToMessage!),
    attachments: dto.attachments
        .map((attachment) => AttachmentItem.fromDto(attachment))
        .toList(),
    reactions: dto.reactions
        .map((reaction) => ReactionSummary.fromDto(reaction))
        .toList(),
    mentions: dto.mentions
        .map((mention) => MentionInfo.fromDto(mention))
        .toList(),
    threadInfo: dto.threadInfo == null
        ? null
        : ThreadInfo.fromDto(dto.threadInfo!),
  );
}
