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
      // TODO: add lastMessagePreview and lastMessageSenderName
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

// Sender object (nested in message responses)
class Sender {
  final int uid;
  final String? name;

  Sender({required this.uid, this.name});

  factory Sender.fromJson(Map<String, dynamic> json) {
    return Sender(
      uid: json['uid'] as int? ?? 0,
      name: json['name'] as String?,
    );
  }
}

// Message list API response models
class MessageItem {
  final String id;
  final String? message;
  final String messageType;
  final Sender sender;
  final String chatId;
  final String createdAt;
  final bool isEdited;
  final bool isDeleted;
  final String clientGeneratedId;
  final String? replyRootId;
  final bool hasAttachments;

  MessageItem({
    required this.id,
    this.message,
    required this.messageType,
    required this.sender,
    required this.chatId,
    required this.createdAt,
    required this.isEdited,
    required this.isDeleted,
    required this.clientGeneratedId,
    this.replyRootId,
    required this.hasAttachments,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    return MessageItem(
      id: json['id']?.toString() ?? '',
      message: json['message'] as String?,
      messageType: json['message_type'] as String? ?? 'text',
      sender: Sender.fromJson(json['sender'] as Map<String, dynamic>? ?? {}),
      chatId: json['chat_id']?.toString() ?? '',
      createdAt: json['created_at'] as String? ?? '',
      isEdited: json['is_edited'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      clientGeneratedId: json['client_generated_id'] as String? ?? '',
      replyRootId: json['reply_root_id']?.toString(),
      hasAttachments: json['has_attachments'] as bool? ?? false,
    );
  }
}

class ListMessagesResponse {
  final List<MessageItem> messages;
  final String? nextCursor;
  final String? prevCursor;

  ListMessagesResponse({
    required this.messages,
    this.nextCursor,
    this.prevCursor,
  });

  factory ListMessagesResponse.fromJson(Map<String, dynamic> json) {
    final list = json['messages'] as List<dynamic>? ?? [];
    return ListMessagesResponse(
      messages: list
          .map((e) => MessageItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor']?.toString(),
      prevCursor: json['prev_cursor']?.toString(),
    );
  }
}
