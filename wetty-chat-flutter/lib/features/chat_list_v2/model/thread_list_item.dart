import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/thread_api_models.dart';

import 'package:chahua/features/shared/model/message/message.dart';

part 'thread_list_item.freezed.dart';

@freezed
abstract class ThreadListItem with _$ThreadListItem {
  const ThreadListItem._();

  const factory ThreadListItem({
    required String chatId,
    required String chatName,
    String? chatAvatar,
    required ConversationMessageV2 threadRootMessage,
    @Default([]) List<Sender> participants,
    MessagePreview? lastReply,
    @Default(0) int replyCount,
    DateTime? lastReplyAt,
    @Default(0) int unreadCount,
    DateTime? subscribedAt,
  }) = _ThreadListItem;

  /// Thread root message ID used as the unique key for this thread.
  int get threadRootId => threadRootMessage.serverMessageId ?? 0;

  factory ThreadListItem.fromDto(ThreadListItemDto dto) => ThreadListItem(
    chatId: dto.chatId.toString(),
    chatName: dto.chatName,
    chatAvatar: dto.chatAvatar,
    threadRootMessage: ConversationMessageV2.fromMessageItemDto(
      dto.threadRootMessage,
    ),
    participants: dto.participants.map(Sender.fromDto).toList(),
    lastReply: dto.lastReply == null
        ? null
        : MessagePreview.fromThreadReplyPreviewDto(dto.lastReply!),
    replyCount: dto.replyCount,
    lastReplyAt: dto.lastReplyAt,
    unreadCount: dto.unreadCount,
    subscribedAt: dto.subscribedAt,
  );
}
