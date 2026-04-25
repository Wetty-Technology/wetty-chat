import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/messages_api_models.dart';

import 'attachment.dart';
import 'mention.dart';
import 'reaction.dart';
import 'sender.dart';
import 'sticker.dart';

part 'reply_to_message.freezed.dart';

@freezed
abstract class ReplyToMessage with _$ReplyToMessage {
  const factory ReplyToMessage({
    required int id,
    String? message,
    @Default('text') String messageType,
    StickerSummary? sticker,
    required Sender sender,
    @Default(false) bool isDeleted,
    @Default([]) List<AttachmentItem> attachments,
    @Default([]) List<ReactionSummary> reactions,
    String? firstAttachmentKind,
    @Default([]) List<MentionInfo> mentions,
  }) = _ReplyToMessage;

  factory ReplyToMessage.fromDto(ReplyToMessageDto dto) => ReplyToMessage(
    id: dto.id,
    message: dto.message,
    messageType: dto.messageType,
    sticker: dto.sticker == null ? null : StickerSummary.fromDto(dto.sticker!),
    sender: Sender.fromDto(dto.sender),
    isDeleted: dto.isDeleted,
    attachments: dto.attachments
        .map((attachment) => AttachmentItem.fromDto(attachment))
        .toList(),
    firstAttachmentKind: dto.firstAttachmentKind,
    mentions: dto.mentions
        .map((mention) => MentionInfo.fromDto(mention))
        .toList(),
  );
}
