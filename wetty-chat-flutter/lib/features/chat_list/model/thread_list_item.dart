import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/thread_api_models.dart';

import 'package:chahua/features/shared/model/message/message_preview.dart';
import 'package:chahua/features/shared/model/message/user.dart';

part 'thread_list_item.freezed.dart';

@freezed
abstract class ThreadListItem with _$ThreadListItem {
  const ThreadListItem._();

  const factory ThreadListItem({
    required String chatId,
    required String chatName,
    String? chatAvatar,
    required MessagePreview threadRootMessage,
    @Default([]) List<User> participants,
    MessagePreview? lastReply,
    @Default(0) int replyCount,
    DateTime? lastReplyAt,
    @Default(0) int unreadCount,
    DateTime? subscribedAt,
  }) = _ThreadListItem;

  /// Thread root message ID used as the unique key for this thread.
  int get threadRootId => threadRootMessage.messageId;

  factory ThreadListItem.fromDto(ThreadListItemDto dto) => ThreadListItem(
    chatId: dto.chatId.toString(),
    chatName: dto.chatName,
    chatAvatar: dto.chatAvatar,
    threadRootMessage: MessagePreview.fromDto(dto.threadRootMessage),
    participants: dto.participants.map(User.fromDto).toList(),
    lastReply: dto.lastReply == null
        ? null
        : MessagePreview.fromDto(dto.lastReply!),
    replyCount: dto.replyCount,
    lastReplyAt: dto.lastReplyAt,
    unreadCount: dto.unreadCount,
    subscribedAt: dto.subscribedAt,
  );
}
