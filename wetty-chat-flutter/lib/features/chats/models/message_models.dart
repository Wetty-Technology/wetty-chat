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

  factory Sender.fromJson(Map<String, dynamic> json) {
    return Sender(
      uid: json['uid'] as int? ?? 0,
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
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
      size: (json['size'] as num?)?.toInt() ?? 0,
      fileName: json['fileName'] as String? ?? '',
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );
  }
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

  factory ReplyToMessage.fromJson(Map<String, dynamic> json) {
    return ReplyToMessage(
      id: parseSnowflakeId(json['id']),
      message: json['message'] as String?,
      sender: Sender.fromJson(json['sender'] as Map<String, dynamic>? ?? {}),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }
}

class ThreadInfo {
  final int replyCount;

  const ThreadInfo({required this.replyCount});

  factory ThreadInfo.fromJson(Map<String, dynamic> json) {
    return ThreadInfo(replyCount: json['replyCount'] as int? ?? 0);
  }
}

class MessageItem {
  final int id;
  final String? message;
  final String messageType;
  final Sender sender;
  final String chatId;
  final String createdAt;
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

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    final replyJson = json['replyToMessage'] as Map<String, dynamic>?;
    final attachmentList = json['attachments'] as List<dynamic>? ?? [];
    final threadInfoJson = json['threadInfo'] as Map<String, dynamic>?;

    return MessageItem(
      id: parseSnowflakeId(json['id']),
      message: json['message'] as String?,
      messageType: json['messageType'] as String? ?? 'text',
      sender: Sender.fromJson(json['sender'] as Map<String, dynamic>? ?? {}),
      chatId: json['chatId']?.toString() ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      isEdited: json['isEdited'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      clientGeneratedId: json['clientGeneratedId'] as String? ?? '',
      replyRootId: json['replyRootId'] != null
          ? parseSnowflakeId(json['replyRootId'])
          : null,
      hasAttachments: json['hasAttachments'] as bool? ?? false,
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
      nextCursor: json['nextCursor']?.toString(),
      prevCursor: json['prevCursor']?.toString(),
    );
  }
}
