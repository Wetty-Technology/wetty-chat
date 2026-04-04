import 'message_models.dart';

class ChatListItem {
  final String id;
  final String? name;
  final String? lastMessageAt;
  final int unreadCount;
  final MessageItem? lastMessage;
  final String? mutedUntil;

  ChatListItem({
    required this.id,
    this.name,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.lastMessage,
    this.mutedUntil,
  });

  /// Create a copy of the object with the given fields replaced.
  ChatListItem copyWith({
    String? id,
    String? name,
    String? lastMessageAt,
    int? unreadCount,
    MessageItem? lastMessage,
    String? mutedUntil,
  }) {
    return ChatListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessage: lastMessage ?? this.lastMessage,
      mutedUntil: mutedUntil ?? this.mutedUntil,
    );
  }
}

class ListChatsResponse {
  final List<ChatListItem> chats;
  final String? nextCursor;

  ListChatsResponse({required this.chats, this.nextCursor});
}
