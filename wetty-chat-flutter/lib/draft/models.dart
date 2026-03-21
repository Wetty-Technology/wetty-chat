// Chat list API response models
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

// Sender object (nested in message responses)
class Sender {
  final int uid;
  final String? name;

  Sender({required this.uid, this.name});

  factory Sender.fromJson(Map<String, dynamic> json) {
    return Sender(uid: json['uid'] as int? ?? 0, name: json['name'] as String?);
  }
}

// Reply-to message (nested in message responses)
class ReplyToMessage {
  final String id;
  final String? message;
  final Sender sender;
  final bool isDeleted;

  ReplyToMessage({
    required this.id,
    this.message,
    required this.sender,
    required this.isDeleted,
  });

  factory ReplyToMessage.fromJson(Map<String, dynamic> json) {
    return ReplyToMessage(
      id: json['id']?.toString() ?? '',
      message: json['message'] as String?,
      sender: Sender.fromJson(json['sender'] as Map<String, dynamic>? ?? {}),
      isDeleted: json['is_deleted'] as bool? ?? false,
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
  final ReplyToMessage? replyToMessage;

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
    this.replyToMessage,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    final replyJson = json['reply_to_message'] as Map<String, dynamic>?;
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
      replyToMessage: replyJson != null
          ? ReplyToMessage.fromJson(replyJson)
          : null,
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
