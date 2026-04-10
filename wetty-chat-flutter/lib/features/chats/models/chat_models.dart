import 'message_models.dart';

class ChatListItem {
  final String id;
  final String? name;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String? lastReadMessageId;
  final MessageItem? lastMessage;
  final DateTime? mutedUntil;

  ChatListItem({
    required this.id,
    this.name,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.lastReadMessageId,
    this.lastMessage,
    this.mutedUntil,
  });

  /// Create a copy of the object with the given fields replaced.
  ChatListItem copyWith({
    String? id,
    String? name,
    DateTime? lastMessageAt,
    int? unreadCount,
    Object? lastReadMessageId = _sentinel,
    MessageItem? lastMessage,
    Object? mutedUntil = _sentinel,
  }) {
    return ChatListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      lastReadMessageId: lastReadMessageId == _sentinel
          ? this.lastReadMessageId
          : lastReadMessageId as String?,
      lastMessage: lastMessage ?? this.lastMessage,
      mutedUntil:
          mutedUntil == _sentinel ? this.mutedUntil : mutedUntil as DateTime?,
    );
  }
}

class ListChatsResponse {
  final List<ChatListItem> chats;
  final String? nextCursor;

  ListChatsResponse({required this.chats, this.nextCursor});
}

const _sentinel = Object();
