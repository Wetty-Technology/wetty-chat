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
  bool get isAudio => kind.startsWith('audio/');
}

class StickerSummary {
  final String? emoji;

  const StickerSummary({this.emoji});
}

class ReactionReactor {
  final int uid;
  final String? name;
  final String? avatarUrl;

  const ReactionReactor({required this.uid, this.name, this.avatarUrl});

  @override
  bool operator ==(Object other) =>
      other is ReactionReactor &&
      other.uid == uid &&
      other.name == name &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(uid, name, avatarUrl);
}

class ReactionSummary {
  final String emoji;
  final int count;
  final bool? reactedByMe;
  final List<ReactionReactor>? reactors;

  const ReactionSummary({
    required this.emoji,
    required this.count,
    this.reactedByMe,
    this.reactors,
  });

  @override
  bool operator ==(Object other) =>
      other is ReactionSummary &&
      other.emoji == emoji &&
      other.count == count &&
      other.reactedByMe == reactedByMe &&
      _listEquals(other.reactors, reactors);

  @override
  int get hashCode => Object.hash(
    emoji,
    count,
    reactedByMe,
    Object.hashAll(reactors ?? const <ReactionReactor>[]),
  );
}

class MentionInfo {
  final int uid;
  final String? username;

  const MentionInfo({required this.uid, this.username});
}

class ReplyToMessage {
  final int id;
  final String? message;
  final String messageType;
  final StickerSummary? sticker;
  final Sender sender;
  final bool isDeleted;
  final List<AttachmentItem> attachments;
  final List<ReactionSummary> reactions;
  final String? firstAttachmentKind;
  final List<MentionInfo> mentions;

  const ReplyToMessage({
    required this.id,
    this.message,
    this.messageType = 'text',
    this.sticker,
    required this.sender,
    required this.isDeleted,
    this.attachments = const [],
    this.reactions = const [],
    this.firstAttachmentKind,
    this.mentions = const [],
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
  final StickerSummary? sticker;
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
  final List<ReactionSummary> reactions;
  final List<MentionInfo> mentions;
  final ThreadInfo? threadInfo;

  const MessageItem({
    required this.id,
    this.message,
    required this.messageType,
    this.sticker,
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
    this.reactions = const [],
    this.mentions = const [],
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

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null || a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
