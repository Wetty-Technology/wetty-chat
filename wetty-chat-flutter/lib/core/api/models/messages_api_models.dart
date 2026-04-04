import 'package:json_annotation/json_annotation.dart';

import '../converters/flexible_int_converter.dart';
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
class ReplyToMessageDto {
  const ReplyToMessageDto({
    required this.id,
    this.message,
    required this.sender,
    this.isDeleted = false,
  });

  @FlexibleIntConverter()
  final int id;
  final String? message;
  final SenderDto sender;
  @JsonKey(defaultValue: false)
  final bool isDeleted;

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
    required this.sender,
    required this.chatId,
    this.createdAt = '',
    this.isEdited = false,
    this.isDeleted = false,
    this.clientGeneratedId = '',
    this.replyRootId,
    this.hasAttachments = false,
    this.replyToMessage,
    this.attachments = const [],
    this.threadInfo,
  });

  @FlexibleIntConverter()
  final int id;
  final String? message;
  @JsonKey(defaultValue: 'text')
  final String messageType;
  final SenderDto sender;
  @FlexibleIntConverter()
  final int chatId;
  @JsonKey(defaultValue: '')
  final String createdAt;
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
