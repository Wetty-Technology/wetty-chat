import 'message_models.dart';

class ChatListItem {
  final String id;
  final String? name;
  final String? lastMessageAt;
  final int unreadCount;
  final MessageItem? lastMessage;

  ChatListItem({
    required this.id,
    this.name,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.lastMessage,
  });

  factory ChatListItem.fromJson(Map<String, dynamic> json) {
    final lastMsgJson = json['last_message'] as Map<String, dynamic>?;
    return ChatListItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String?,
      lastMessageAt: json['last_message_at'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      lastMessage: lastMsgJson != null
          ? MessageItem.fromJson(lastMsgJson)
          : null,
    );
  }
}

class ListChatsResponse {
  final List<ChatListItem> chats;
  final String? nextCursor;

  ListChatsResponse({required this.chats, this.nextCursor});

  factory ListChatsResponse.fromJson(Map<String, dynamic> json) {
    final list = json['chats'] as List<dynamic>? ?? [];
    return ListChatsResponse(
      chats: list
          .map((e) => ChatListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor']?.toString(),
    );
  }
}
