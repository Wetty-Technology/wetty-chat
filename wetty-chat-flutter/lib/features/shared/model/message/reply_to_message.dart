import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/messages_api_models.dart';

import 'attachment.dart';
import 'mention.dart';
import 'reaction.dart';
import 'user.dart';
import 'sticker.dart';

part 'reply_to_message.freezed.dart';

@freezed
abstract class ReplyToMessage with _$ReplyToMessage {
  const factory ReplyToMessage({
    required int id,
    String? message,
    @Default('text') String messageType,
    StickerSummary? sticker,
    required User sender,
    @Default(false) bool isDeleted,
    @Default([]) List<AttachmentItem> attachments,
    @Default([]) List<ReactionSummary> reactions,
    String? firstAttachmentKind,
    @Default([]) List<MentionInfo> mentions,
  }) = _ReplyToMessage;

  factory ReplyToMessage.fromDto(MessagePreviewDto dto) => ReplyToMessage(
    id: dto.id,
    message: dto.message,
    messageType: dto.messageType,
    sticker: dto.sticker?.emoji == null
        ? null
        : StickerSummary(
            id: 'message-preview-${dto.id}',
            emoji: dto.sticker!.emoji,
          ),
    sender: User.fromDto(dto.sender),
    isDeleted: dto.isDeleted,
    firstAttachmentKind: dto.firstAttachmentKind,
    mentions: dto.mentions
        .map((mention) => MentionInfo.fromDto(mention))
        .toList(),
  );
}
