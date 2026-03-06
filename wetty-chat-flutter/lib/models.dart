// Chat list API response models
class ChatListItem {
  final String id;
  final String? name;
  final String? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageSenderName;

  ChatListItem({
    required this.id,
    this.name,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderName,
  });

  factory ChatListItem.fromJson(Map<String, dynamic> json) {
    return ChatListItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String?,
      lastMessageAt: json['last_message_at'] as String?,
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageSenderName: json['last_message_sender_name'] as String?,
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
