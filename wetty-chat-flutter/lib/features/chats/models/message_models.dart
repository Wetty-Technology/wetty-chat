int parseSnowflakeId(Object? value) {
  if (value is int) return value;
  if (value is String) return int.parse(value);
  if (value == null) return 0;
  throw FormatException('Invalid snowflake id: $value');
}

class Sender {
  final int uid;
  final String? name;
  final String? avatarUrl;
  final int gender;

  const Sender({required this.uid, this.name, this.avatarUrl, this.gender = 0});
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
}

class ReplyToMessage {
  final int id;
  final String? message;
  final Sender sender;
  final bool isDeleted;

  const ReplyToMessage({
    required this.id,
    this.message,
    required this.sender,
    required this.isDeleted,
  });
}

class ThreadInfo {
  final int replyCount;

  const ThreadInfo({required this.replyCount});
}

class MessageItem {
  final int id;
  final String? message;
  final String messageType;
  final Sender sender;
  final String chatId;
  final DateTime? createdAt;
  final bool isEdited;
  final bool isDeleted;
  final String clientGeneratedId;
  final int? replyRootId;
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
}
