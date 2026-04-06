import '../../../core/api/models/chats_api_models.dart';
import 'chat_models.dart';
import 'message_api_mapper.dart';

extension ChatListItemDtoMapper on ChatListItemDto {
  ChatListItem toDomain() => ChatListItem(
    id: id.toString(),
    name: name,
    lastMessageAt: lastMessageAt,
    unreadCount: unreadCount,
    lastReadMessageId: lastReadMessageId,
    lastMessage: lastMessage?.toDomain(),
    mutedUntil: mutedUntil,
  );
}
