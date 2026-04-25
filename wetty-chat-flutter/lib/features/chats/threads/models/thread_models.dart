import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/thread_api_models.dart';
import 'package:chahua/features/chats/models/message_api_mapper.dart';

import '../../models/message_models.dart';

part 'thread_models.freezed.dart';

@freezed
abstract class ThreadParticipant with _$ThreadParticipant {
  const factory ThreadParticipant({
    required int uid,
    String? name,
    String? avatarUrl,
  }) = _ThreadParticipant;

  factory ThreadParticipant.fromDto(ThreadParticipantDto dto) =>
      ThreadParticipant(uid: dto.uid, name: dto.name, avatarUrl: dto.avatarUrl);
}

@freezed
abstract class ThreadReplyPreview with _$ThreadReplyPreview {
  const factory ThreadReplyPreview({
    int? messageId,
    String? clientGeneratedId,
    required ThreadParticipant sender,
    String? message,
    @Default('text') String messageType,
    String? stickerEmoji,
    String? firstAttachmentKind,
    @Default(false) bool isDeleted,
    @Default([]) List<MentionInfo> mentions,
  }) = _ThreadReplyPreview;

  factory ThreadReplyPreview.fromDto(ThreadReplyPreviewDto dto) =>
      ThreadReplyPreview(
        messageId: dto.id,
        clientGeneratedId: dto.clientGeneratedId.isEmpty
            ? null
            : dto.clientGeneratedId,
        sender: ThreadParticipant.fromDto(dto.sender),
        message: dto.message,
        messageType: dto.messageType,
        stickerEmoji: dto.stickerEmoji,
        firstAttachmentKind: dto.firstAttachmentKind,
        isDeleted: dto.isDeleted,
        mentions: dto.mentions.map((mention) => mention.toDomain()).toList(),
      );
}

@freezed
abstract class ThreadListItem with _$ThreadListItem {
  const ThreadListItem._();

  const factory ThreadListItem({
    required String chatId,
    required String chatName,
    String? chatAvatar,
    required MessageItem threadRootMessage,
    @Default([]) List<ThreadParticipant> participants,
    ThreadReplyPreview? lastReply,
    @Default(0) int replyCount,
    DateTime? lastReplyAt,
    @Default(0) int unreadCount,
    DateTime? subscribedAt,
  }) = _ThreadListItem;

  /// Thread root message ID used as the unique key for this thread.
  int get threadRootId => threadRootMessage.id;

  factory ThreadListItem.fromDto(ThreadListItemDto dto) => ThreadListItem(
    chatId: dto.chatId.toString(),
    chatName: dto.chatName,
    chatAvatar: dto.chatAvatar,
    threadRootMessage: dto.threadRootMessage.toDomain(),
    participants: dto.participants
        .map((participant) => ThreadParticipant.fromDto(participant))
        .toList(),
    lastReply: dto.lastReply == null
        ? null
        : ThreadReplyPreview.fromDto(dto.lastReply!),
    replyCount: dto.replyCount,
    lastReplyAt: dto.lastReplyAt,
    unreadCount: dto.unreadCount,
    subscribedAt: dto.subscribedAt,
  );
}
