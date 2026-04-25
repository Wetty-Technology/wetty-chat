import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/core/api/models/thread_api_models.dart';

import 'attachment.dart';
import 'mention.dart';
import 'reaction.dart';
import 'sender.dart';
import 'sticker.dart';

part 'message_preview.freezed.dart';

@freezed
abstract class MessagePreview with _$MessagePreview {
  const MessagePreview._();

  const factory MessagePreview({
    int? messageId,
    String? clientGeneratedId,
    required Sender sender,
    String? message,
    @Default('text') String messageType,
    StickerSummary? sticker,
    String? stickerEmoji,
    @Default([]) List<AttachmentItem> attachments,
    @Default([]) List<ReactionSummary> reactions,
    String? firstAttachmentKind,
    @Default(false) bool isDeleted,
    @Default([]) List<MentionInfo> mentions,
  }) = _MessagePreview;

  String? get previewStickerEmoji => sticker?.emoji ?? stickerEmoji;

  factory MessagePreview.fromReplyToMessageDto(ReplyToMessageDto dto) =>
      MessagePreview(
        messageId: dto.id,
        sender: Sender.fromDto(dto.sender),
        message: dto.message,
        messageType: dto.messageType,
        sticker: dto.sticker == null
            ? null
            : StickerSummary.fromDto(dto.sticker!),
        attachments: dto.attachments
            .map((attachment) => AttachmentItem.fromDto(attachment))
            .toList(),
        firstAttachmentKind: dto.firstAttachmentKind,
        isDeleted: dto.isDeleted,
        mentions: dto.mentions.map(MentionInfo.fromDto).toList(),
      );

  factory MessagePreview.fromThreadReplyPreviewDto(ThreadReplyPreviewDto dto) =>
      MessagePreview(
        messageId: dto.id,
        clientGeneratedId: dto.clientGeneratedId.isEmpty
            ? null
            : dto.clientGeneratedId,
        sender: Sender.fromDto(dto.sender),
        message: dto.message,
        messageType: dto.messageType,
        stickerEmoji: dto.stickerEmoji,
        firstAttachmentKind: dto.firstAttachmentKind,
        isDeleted: dto.isDeleted,
        mentions: dto.mentions.map(MentionInfo.fromDto).toList(),
      );
}
