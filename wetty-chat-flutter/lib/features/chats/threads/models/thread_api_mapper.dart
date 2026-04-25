import 'package:chahua/core/api/models/thread_api_models.dart';

import '../../models/message_api_mapper.dart';
import 'thread_models.dart';

extension ThreadParticipantDtoMapper on ThreadParticipantDto {
  ThreadParticipant toDomain() =>
      ThreadParticipant(uid: uid, name: name, avatarUrl: avatarUrl);
}

extension ThreadReplyPreviewDtoMapper on ThreadReplyPreviewDto {
  ThreadReplyPreview toDomain() => ThreadReplyPreview(
    messageId: id,
    clientGeneratedId: clientGeneratedId.isEmpty ? null : clientGeneratedId,
    sender: sender.toDomain(),
    message: message,
    messageType: messageType,
    stickerEmoji: stickerEmoji,
    firstAttachmentKind: firstAttachmentKind,
    isDeleted: isDeleted,
    mentions: mentions.map((mention) => mention.toDomain()).toList(),
  );
}

extension ThreadListItemDtoMapper on ThreadListItemDto {
  ThreadListItem toDomain() => ThreadListItem(
    chatId: chatId.toString(),
    chatName: chatName,
    chatAvatar: chatAvatar,
    threadRootMessage: threadRootMessage.toDomain(),
    participants: participants
        .map((participant) => participant.toDomain())
        .toList(),
    lastReply: lastReply?.toDomain(),
    replyCount: replyCount,
    lastReplyAt: lastReplyAt,
    unreadCount: unreadCount,
    subscribedAt: subscribedAt,
  );
}
