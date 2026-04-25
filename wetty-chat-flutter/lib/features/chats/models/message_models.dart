import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/messages_api_models.dart';

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

  factory Sender.fromDto(SenderDto dto) => Sender(
    uid: dto.uid,
    name: dto.name,
    avatarUrl: dto.avatarUrl,
    gender: dto.gender,
  );
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

  factory AttachmentItem.fromDto(AttachmentItemDto dto) => AttachmentItem(
    id: dto.id,
    url: dto.url,
    kind: dto.kind,
    size: dto.size,
    fileName: dto.fileName,
    width: dto.width,
    height: dto.height,
  );
}

@freezed
abstract class StickerMedia with _$StickerMedia {
  const StickerMedia._();

  const factory StickerMedia({
    required String id,
    required String url,
    required String contentType,
    required int size,
    int? width,
    int? height,
  }) = _StickerMedia;

  bool get isVideo => contentType.startsWith('video/');

  factory StickerMedia.fromDto(StickerMediaDto dto) => StickerMedia(
    id: dto.id,
    url: dto.url,
    contentType: dto.contentType,
    size: dto.size,
    width: dto.width,
    height: dto.height,
  );
}

@freezed
abstract class StickerSummary with _$StickerSummary {
  const factory StickerSummary({
    required String id,
    StickerMedia? media,
    String? emoji,
    String? name,
    String? description,
    DateTime? createdAt,
    bool? isFavorited,
  }) = _StickerSummary;

  factory StickerSummary.fromDto(StickerSummaryDto dto) => StickerSummary(
    id: dto.id ?? (throw StateError('StickerSummaryDto.id is required')),
    media: dto.media == null ? null : StickerMedia.fromDto(dto.media!),
    emoji: dto.emoji,
    name: dto.name,
    description: dto.description,
    createdAt: dto.createdAt,
    isFavorited: dto.isFavorited,
  );
}

@freezed
abstract class ReactionReactor with _$ReactionReactor {
  const factory ReactionReactor({
    required int uid,
    String? name,
    String? avatarUrl,
  }) = _ReactionReactor;

  factory ReactionReactor.fromDto(ReactionReactorDto dto) =>
      ReactionReactor(uid: dto.uid, name: dto.name, avatarUrl: dto.avatarUrl);
}

@freezed
abstract class ReactionSummary with _$ReactionSummary {
  const factory ReactionSummary({
    required String emoji,
    required int count,
    bool? reactedByMe,
    List<ReactionReactor>? reactors,
  }) = _ReactionSummary;

  factory ReactionSummary.fromDto(ReactionSummaryDto dto) => ReactionSummary(
    emoji: dto.emoji,
    count: dto.count,
    reactedByMe: dto.reactedByMe,
    reactors: dto.reactors
        ?.map((reactor) => ReactionReactor.fromDto(reactor))
        .toList(),
  );
}

@freezed
abstract class UserGroupInfo with _$UserGroupInfo {
  const factory UserGroupInfo({
    required int groupId,
    String? name,
    String? chatGroupColor,
    String? chatGroupColorDark,
  }) = _UserGroupInfo;

  factory UserGroupInfo.fromDto(UserGroupInfoDto dto) => UserGroupInfo(
    groupId: dto.groupId,
    name: dto.name,
    chatGroupColor: dto.chatGroupColor,
    chatGroupColorDark: dto.chatGroupColorDark,
  );
}

@freezed
abstract class MentionInfo with _$MentionInfo {
  const factory MentionInfo({
    required int uid,
    String? username,
    String? avatarUrl,
    @Default(0) int gender,
    UserGroupInfo? userGroup,
  }) = _MentionInfo;

  factory MentionInfo.fromDto(MentionInfoDto dto) => MentionInfo(
    uid: dto.uid,
    username: dto.username,
    avatarUrl: dto.avatarUrl,
    gender: dto.gender,
    userGroup: dto.userGroup == null
        ? null
        : UserGroupInfo.fromDto(dto.userGroup!),
  );
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

  factory ReplyToMessage.fromDto(ReplyToMessageDto dto) => ReplyToMessage(
    id: dto.id,
    message: dto.message,
    messageType: dto.messageType,
    sticker: dto.sticker == null ? null : StickerSummary.fromDto(dto.sticker!),
    sender: Sender.fromDto(dto.sender),
    isDeleted: dto.isDeleted,
    attachments: dto.attachments
        .map((attachment) => AttachmentItem.fromDto(attachment))
        .toList(),
    firstAttachmentKind: dto.firstAttachmentKind,
    mentions: dto.mentions
        .map((mention) => MentionInfo.fromDto(mention))
        .toList(),
  );
}

@freezed
abstract class ThreadInfo with _$ThreadInfo {
  const factory ThreadInfo({required int replyCount}) = _ThreadInfo;

  factory ThreadInfo.fromDto(ThreadInfoDto dto) =>
      ThreadInfo(replyCount: dto.replyCount);
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

  factory MessageItem.fromDto(MessageItemDto dto) => MessageItem(
    id: dto.id,
    message: dto.message,
    messageType: dto.messageType,
    sticker: dto.sticker == null ? null : StickerSummary.fromDto(dto.sticker!),
    sender: Sender.fromDto(dto.sender),
    chatId: dto.chatId.toString(),
    createdAt: dto.createdAt,
    isEdited: dto.isEdited,
    isDeleted: dto.isDeleted,
    clientGeneratedId: dto.clientGeneratedId,
    replyRootId: dto.replyRootId,
    hasAttachments: dto.hasAttachments,
    replyToMessage: dto.replyToMessage == null
        ? null
        : ReplyToMessage.fromDto(dto.replyToMessage!),
    attachments: dto.attachments
        .map((attachment) => AttachmentItem.fromDto(attachment))
        .toList(),
    reactions: dto.reactions
        .map((reaction) => ReactionSummary.fromDto(reaction))
        .toList(),
    mentions: dto.mentions
        .map((mention) => MentionInfo.fromDto(mention))
        .toList(),
    threadInfo: dto.threadInfo == null
        ? null
        : ThreadInfo.fromDto(dto.threadInfo!),
  );
}

@freezed
abstract class ListMessagesResponse with _$ListMessagesResponse {
  const factory ListMessagesResponse({
    required List<MessageItem> messages,
    String? nextCursor,
    String? prevCursor,
  }) = _ListMessagesResponse;
}
