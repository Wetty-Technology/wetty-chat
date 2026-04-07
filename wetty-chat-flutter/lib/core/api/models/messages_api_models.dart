import 'package:json_annotation/json_annotation.dart';

import '../converters/flexible_int_converter.dart';
import '../converters/nullable_date_time_converter.dart';
import '../converters/string_value_converter.dart';

part 'messages_api_models.g.dart';

@JsonSerializable(explicitToJson: true)
class SenderDto {
  const SenderDto({
    required this.uid,
    this.name,
    this.avatarUrl,
    this.gender = 0,
  });

  @FlexibleIntConverter()
  final int uid;
  final String? name;
  final String? avatarUrl;
  @JsonKey(defaultValue: 0)
  final int gender;

  factory SenderDto.fromJson(Map<String, dynamic> json) =>
      _$SenderDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SenderDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class AttachmentItemDto {
  const AttachmentItemDto({
    required this.id,
    this.url = '',
    this.kind = 'application/octet-stream',
    this.size = 0,
    this.fileName = '',
    this.width,
    this.height,
  });

  @StringValueConverter()
  final String id;
  @JsonKey(defaultValue: '')
  final String url;
  @JsonKey(defaultValue: 'application/octet-stream')
  final String kind;
  @JsonKey(defaultValue: 0)
  final int size;
  @JsonKey(defaultValue: '')
  final String fileName;
  final int? width;
  final int? height;

  factory AttachmentItemDto.fromJson(Map<String, dynamic> json) =>
      _$AttachmentItemDtoFromJson(json);

  Map<String, dynamic> toJson() => _$AttachmentItemDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class StickerSummaryDto {
  const StickerSummaryDto({this.emoji});

  final String? emoji;

  factory StickerSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$StickerSummaryDtoFromJson(json);

  Map<String, dynamic> toJson() => _$StickerSummaryDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ReactionReactorDto {
  const ReactionReactorDto({required this.uid, this.name, this.avatarUrl});

  @FlexibleIntConverter()
  final int uid;
  final String? name;
  final String? avatarUrl;

  factory ReactionReactorDto.fromJson(Map<String, dynamic> json) =>
      _$ReactionReactorDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ReactionReactorDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ReactionSummaryDto {
  const ReactionSummaryDto({
    required this.emoji,
    required this.count,
    this.reactedByMe,
    this.reactors,
  });

  final String emoji;
  @FlexibleIntConverter()
  final int count;
  final bool? reactedByMe;
  final List<ReactionReactorDto>? reactors;

  factory ReactionSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$ReactionSummaryDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ReactionSummaryDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class MentionInfoDto {
  const MentionInfoDto({required this.uid, this.username});

  @FlexibleIntConverter()
  final int uid;
  final String? username;

  factory MentionInfoDto.fromJson(Map<String, dynamic> json) =>
      _$MentionInfoDtoFromJson(json);

  Map<String, dynamic> toJson() => _$MentionInfoDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ReplyToMessageDto {
  const ReplyToMessageDto({
    required this.id,
    this.message,
    this.messageType = 'text',
    this.sticker,
    required this.sender,
    this.isDeleted = false,
    this.attachments = const <AttachmentItemDto>[],
    this.firstAttachmentKind,
    this.mentions = const <MentionInfoDto>[],
  });

  @FlexibleIntConverter()
  final int id;
  final String? message;
  @JsonKey(defaultValue: 'text')
  final String messageType;
  final StickerSummaryDto? sticker;
  final SenderDto sender;
  @JsonKey(defaultValue: false)
  final bool isDeleted;
  @JsonKey(defaultValue: <AttachmentItemDto>[])
  final List<AttachmentItemDto> attachments;
  final String? firstAttachmentKind;
  @JsonKey(defaultValue: <MentionInfoDto>[])
  final List<MentionInfoDto> mentions;

  factory ReplyToMessageDto.fromJson(Map<String, dynamic> json) =>
      _$ReplyToMessageDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ReplyToMessageDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ThreadInfoDto {
  const ThreadInfoDto({this.replyCount = 0});

  @JsonKey(defaultValue: 0)
  final int replyCount;

  factory ThreadInfoDto.fromJson(Map<String, dynamic> json) =>
      _$ThreadInfoDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ThreadInfoDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class MessageItemDto {
  const MessageItemDto({
    required this.id,
    this.message,
    this.messageType = 'text',
    this.sticker,
    required this.sender,
    required this.chatId,
    this.createdAt,
    this.isEdited = false,
    this.isDeleted = false,
    this.clientGeneratedId = '',
    this.replyRootId,
    this.hasAttachments = false,
    this.replyToMessage,
    this.attachments = const [],
    this.reactions = const [],
    this.mentions = const <MentionInfoDto>[],
    this.threadInfo,
  });

  @FlexibleIntConverter()
  final int id;
  final String? message;
  @JsonKey(defaultValue: 'text')
  final String messageType;
  final StickerSummaryDto? sticker;
  final SenderDto sender;
  @FlexibleIntConverter()
  final int chatId;
  @NullableDateTimeConverter()
  final DateTime? createdAt;
  @JsonKey(defaultValue: false)
  final bool isEdited;
  @JsonKey(defaultValue: false)
  final bool isDeleted;
  @JsonKey(defaultValue: '')
  final String clientGeneratedId;
  @NullableFlexibleIntConverter()
  final int? replyRootId;
  @JsonKey(defaultValue: false)
  final bool hasAttachments;
  final ReplyToMessageDto? replyToMessage;
  @JsonKey(defaultValue: <AttachmentItemDto>[])
  final List<AttachmentItemDto> attachments;
  @JsonKey(defaultValue: <ReactionSummaryDto>[])
  final List<ReactionSummaryDto> reactions;
  @JsonKey(defaultValue: <MentionInfoDto>[])
  final List<MentionInfoDto> mentions;
  final ThreadInfoDto? threadInfo;

  factory MessageItemDto.fromJson(Map<String, dynamic> json) =>
      _$MessageItemDtoFromJson(json);

  Map<String, dynamic> toJson() => _$MessageItemDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ListMessagesResponseDto {
  const ListMessagesResponseDto({
    this.messages = const [],
    this.nextCursor,
    this.prevCursor,
  });

  @JsonKey(defaultValue: <MessageItemDto>[])
  final List<MessageItemDto> messages;
  final String? nextCursor;
  final String? prevCursor;

  factory ListMessagesResponseDto.fromJson(Map<String, dynamic> json) =>
      _$ListMessagesResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ListMessagesResponseDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SendMessageRequestDto {
  const SendMessageRequestDto({
    required this.message,
    required this.messageType,
    required this.clientGeneratedId,
    this.attachmentIds = const <String>[],
    this.replyToId,
  });

  final String message;
  final String messageType;
  final String clientGeneratedId;
  final List<String> attachmentIds;
  final int? replyToId;

  factory SendMessageRequestDto.fromJson(Map<String, dynamic> json) =>
      _$SendMessageRequestDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SendMessageRequestDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class EditMessageRequestDto {
  const EditMessageRequestDto({
    required this.message,
    this.attachmentIds = const <String>[],
  });

  final String message;
  final List<String> attachmentIds;

  factory EditMessageRequestDto.fromJson(Map<String, dynamic> json) =>
      _$EditMessageRequestDtoFromJson(json);

  Map<String, dynamic> toJson() => _$EditMessageRequestDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class MarkReadRequestDto {
  const MarkReadRequestDto({required this.messageId});

  @FlexibleIntConverter()
  final int messageId;

  factory MarkReadRequestDto.fromJson(Map<String, dynamic> json) =>
      _$MarkReadRequestDtoFromJson(json);

  Map<String, dynamic> toJson() => _$MarkReadRequestDtoToJson(this);
}
