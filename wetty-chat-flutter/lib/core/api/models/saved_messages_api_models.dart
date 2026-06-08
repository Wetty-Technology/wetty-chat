import 'package:json_annotation/json_annotation.dart';

import 'package:chahua/core/api/converters/flexible_int_converter.dart';
import 'package:chahua/core/api/converters/string_value_converter.dart';
import 'package:chahua/core/api/models/messages_api_models.dart';

part 'saved_messages_api_models.g.dart';

@JsonSerializable(explicitToJson: true)
class SavedAttachmentSnapshotDto {
  const SavedAttachmentSnapshotDto({
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

  factory SavedAttachmentSnapshotDto.fromJson(Map<String, dynamic> json) =>
      _$SavedAttachmentSnapshotDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SavedAttachmentSnapshotDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SavedStickerSnapshotDto {
  const SavedStickerSnapshotDto({
    required this.id,
    this.emoji,
    this.name,
    this.mediaUrl = '',
    this.mediaContentType = 'image/webp',
  });

  @StringValueConverter()
  final String id;
  final String? emoji;
  final String? name;
  @JsonKey(defaultValue: '')
  final String mediaUrl;
  @JsonKey(defaultValue: 'image/webp')
  final String mediaContentType;

  factory SavedStickerSnapshotDto.fromJson(Map<String, dynamic> json) =>
      _$SavedStickerSnapshotDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SavedStickerSnapshotDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SavedSenderSnapshotDto {
  const SavedSenderSnapshotDto({
    required this.uid,
    this.name,
    this.avatarUrl,
    this.gender = 0,
    this.userGroup,
  });

  @FlexibleIntConverter()
  final int uid;
  final String? name;
  final String? avatarUrl;
  @JsonKey(defaultValue: 0)
  final int gender;
  final UserGroupTagInfoDto? userGroup;

  factory SavedSenderSnapshotDto.fromJson(Map<String, dynamic> json) =>
      _$SavedSenderSnapshotDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SavedSenderSnapshotDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SavedChatSnapshotDto {
  const SavedChatSnapshotDto({required this.id, this.name, this.avatarUrl});

  @FlexibleIntConverter()
  final int id;
  final String? name;
  final String? avatarUrl;

  factory SavedChatSnapshotDto.fromJson(Map<String, dynamic> json) =>
      _$SavedChatSnapshotDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SavedChatSnapshotDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SavedMessageResponseDto {
  const SavedMessageResponseDto({
    required this.id,
    required this.originalChatId,
    this.originalThreadRootId,
    required this.originalMessageId,
    this.originalReplyToMessageId,
    required this.originalSenderUid,
    required this.originalCreatedAt,
    required this.savedAt,
    this.message,
    this.messageType = 'text',
    this.attachments = const <SavedAttachmentSnapshotDto>[],
    this.sticker,
    this.mentions = const <MentionInfoDto>[],
    required this.sender,
    required this.chat,
    this.canLocateContext = false,
  });

  @FlexibleIntConverter()
  final int id;
  @FlexibleIntConverter()
  final int originalChatId;
  @NullableFlexibleIntConverter()
  final int? originalThreadRootId;
  @FlexibleIntConverter()
  final int originalMessageId;
  @NullableFlexibleIntConverter()
  final int? originalReplyToMessageId;
  @FlexibleIntConverter()
  final int originalSenderUid;
  final DateTime originalCreatedAt;
  final DateTime savedAt;
  final String? message;
  @JsonKey(defaultValue: 'text')
  final String messageType;
  @JsonKey(defaultValue: <SavedAttachmentSnapshotDto>[])
  final List<SavedAttachmentSnapshotDto> attachments;
  final SavedStickerSnapshotDto? sticker;
  @JsonKey(defaultValue: <MentionInfoDto>[])
  final List<MentionInfoDto> mentions;
  final SavedSenderSnapshotDto sender;
  final SavedChatSnapshotDto chat;
  @JsonKey(defaultValue: false)
  final bool canLocateContext;

  factory SavedMessageResponseDto.fromJson(Map<String, dynamic> json) =>
      _$SavedMessageResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$SavedMessageResponseDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ListSavedMessagesResponseDto {
  const ListSavedMessagesResponseDto({
    this.savedMessages = const <SavedMessageResponseDto>[],
    this.nextCursor,
  });

  @JsonKey(defaultValue: <SavedMessageResponseDto>[])
  final List<SavedMessageResponseDto> savedMessages;
  @NullableFlexibleIntConverter()
  final int? nextCursor;

  factory ListSavedMessagesResponseDto.fromJson(Map<String, dynamic> json) =>
      _$ListSavedMessagesResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ListSavedMessagesResponseDtoToJson(this);
}
