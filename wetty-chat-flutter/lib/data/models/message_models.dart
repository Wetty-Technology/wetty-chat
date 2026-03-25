class Sender {
  final int uid;
  final String? name;
  final String? avatarUrl;
  final int gender;

  const Sender({
    required this.uid,
    this.name,
    this.avatarUrl,
    this.gender = 0,
  });

  factory Sender.fromJson(Map<String, dynamic> json) {
    return Sender(
      uid: json['uid'] as int? ?? 0,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      gender: json['gender'] as int? ?? 0,
    );
  }
}

class AttachmentItem {
  final String id;
  final String url;
  final String kind;
  final int size;
  final String fileName;
  final int? width;
  final int? height;

  const AttachmentItem({
    required this.id,
    required this.url,
    required this.kind,
    required this.size,
    required this.fileName,
    this.width,
    this.height,
  });

  bool get isImage => kind.startsWith('image/');
  bool get isVideo => kind.startsWith('video/');

  factory AttachmentItem.fromJson(Map<String, dynamic> json) {
    return AttachmentItem(
      id: json['id']?.toString() ?? '',
      url: json['url'] as String? ?? '',
      kind: json['kind'] as String? ?? 'application/octet-stream',
      size: json['size'] as int? ?? 0,
      fileName: json['file_name'] as String? ?? '',
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }
}

class ReplyToMessage {
  final String id;
  final String? message;
  final Sender sender;
  final bool isDeleted;

  const ReplyToMessage({
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

class ThreadInfo {
  final int replyCount;

  const ThreadInfo({required this.replyCount});

  factory ThreadInfo.fromJson(Map<String, dynamic> json) {
    return ThreadInfo(replyCount: json['reply_count'] as int? ?? 0);
  }
}

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
  final List<AttachmentItem> attachments;
  final ThreadInfo? threadInfo;

  const MessageItem({
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
    this.attachments = const [],
    this.threadInfo,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    final replyJson = json['reply_to_message'] as Map<String, dynamic>?;
    final attachmentList = json['attachments'] as List<dynamic>? ?? [];
    final threadInfoJson = json['thread_info'] as Map<String, dynamic>?;

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
      attachments: attachmentList
          .map((e) => AttachmentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      threadInfo: threadInfoJson != null
          ? ThreadInfo.fromJson(threadInfoJson)
          : null,
    );
  }
}

class ListMessagesResponse {
  final List<MessageItem> messages;
  final String? nextCursor;
  final String? prevCursor;

  const ListMessagesResponse({
    required this.messages,
    this.nextCursor,
    this.prevCursor,
  });

  factory ListMessagesResponse.fromJson(Map<String, dynamic> json) {
    final list = json['messages'] as List<dynamic>? ?? [];
    return ListMessagesResponse(
      messages: list.reversed
          .map((e) => MessageItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor']?.toString(),
      prevCursor: json['prev_cursor']?.toString(),
    );
  }
}
