import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_models.freezed.dart';

int parseSnowflakeId(Object? value) {
  if (value is int) return value;
  if (value is String) return int.parse(value);
  if (value == null) return 0;
  throw FormatException('Invalid snowflake id: $value');
}

@freezed
abstract class Sender with _$Sender {
  const factory Sender({
    required int uid,
    String? name,
    String? avatarUrl,
    @Default(0) int gender,
  }) = _Sender;
}

@freezed
abstract class AttachmentItem with _$AttachmentItem {
  const AttachmentItem._();

  const factory AttachmentItem({
    required String id,
    required String url,
    required String kind,
    required int size,
    required String fileName,
    int? width,
    int? height,
    int? durationMs,
    List<int>? waveformSamples,
  }) = _AttachmentItem;

  bool get isImage => kind.startsWith('image/');
  bool get isVideo => kind.startsWith('video/');
  bool get isAudio => kind.startsWith('audio/');
  bool get hasWaveform =>
      waveformSamples != null && waveformSamples!.isNotEmpty;
  Duration? get duration =>
      durationMs == null ? null : Duration(milliseconds: durationMs!);
}

@freezed
abstract class StickerSummary with _$StickerSummary {
  const factory StickerSummary({
    String? emoji,
  }) = _StickerSummary;
}

@freezed
abstract class ReactionReactor with _$ReactionReactor {
  const factory ReactionReactor({
    required int uid,
    String? name,
    String? avatarUrl,
  }) = _ReactionReactor;
}

@freezed
abstract class ReactionSummary with _$ReactionSummary {
  const factory ReactionSummary({
    required String emoji,
    required int count,
    bool? reactedByMe,
    List<ReactionReactor>? reactors,
  }) = _ReactionSummary;
}

@freezed
abstract class MentionInfo with _$MentionInfo {
  const factory MentionInfo({
    required int uid,
    String? username,
  }) = _MentionInfo;
}

@freezed
abstract class ReplyToMessage with _$ReplyToMessage {
  const factory ReplyToMessage({
    required int id,
    String? message,
    @Default('text') String messageType,
    StickerSummary? sticker,
    required Sender sender,
    @Default(false) bool isDeleted,
    @Default([]) List<AttachmentItem> attachments,
    @Default([]) List<ReactionSummary> reactions,
    String? firstAttachmentKind,
    @Default([]) List<MentionInfo> mentions,
  }) = _ReplyToMessage;
}

@freezed
abstract class ThreadInfo with _$ThreadInfo {
  const factory ThreadInfo({
    required int replyCount,
  }) = _ThreadInfo;
}

@freezed
abstract class MessageItem with _$MessageItem {
  const factory MessageItem({
    required int id,
    String? message,
    required String messageType,
    StickerSummary? sticker,
    required Sender sender,
    required String chatId,
    DateTime? createdAt,
    @Default(false) bool isEdited,
    @Default(false) bool isDeleted,
    @Default('') String clientGeneratedId,
    int? replyRootId,
    @Default(false) bool hasAttachments,
    ReplyToMessage? replyToMessage,
    @Default([]) List<AttachmentItem> attachments,
    @Default([]) List<ReactionSummary> reactions,
    @Default([]) List<MentionInfo> mentions,
    ThreadInfo? threadInfo,
  }) = _MessageItem;
}

@freezed
abstract class ListMessagesResponse with _$ListMessagesResponse {
  const factory ListMessagesResponse({
    required List<MessageItem> messages,
    String? nextCursor,
    String? prevCursor,
  }) = _ListMessagesResponse;
}
