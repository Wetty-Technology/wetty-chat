import 'package:json_annotation/json_annotation.dart';

import 'package:chahua/core/api/converters/flexible_int_converter.dart';
import 'package:chahua/core/api/converters/nullable_date_time_converter.dart';
import 'package:chahua/core/api/models/messages_api_models.dart';

part 'thread_api_models.g.dart';

@JsonSerializable(explicitToJson: true)
class ThreadListItemDto {
  const ThreadListItemDto({
    required this.chatId,
    required this.chatName,
    this.chatAvatar,
    required this.threadRootMessage,
    this.participants = const <UserDto>[],
    this.lastReply,
    this.replyCount = 0,
    required this.lastReplyAt,
    this.unreadCount = 0,
    required this.subscribedAt,
  });

  @FlexibleIntConverter()
  final int chatId;
  final String chatName;
  final String? chatAvatar;
  final MessagePreviewDto threadRootMessage;
  @JsonKey(defaultValue: <UserDto>[])
  final List<UserDto> participants;
  final MessagePreviewDto? lastReply;
  @JsonKey(defaultValue: 0)
  final int replyCount;
  @NullableDateTimeConverter()
  final DateTime? lastReplyAt;
  @JsonKey(defaultValue: 0)
  final int unreadCount;
  @NullableDateTimeConverter()
  final DateTime? subscribedAt;

  factory ThreadListItemDto.fromJson(Map<String, dynamic> json) =>
      _$ThreadListItemDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ThreadListItemDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ListThreadsResponseDto {
  const ListThreadsResponseDto({
    this.threads = const <ThreadListItemDto>[],
    this.nextCursor,
  });

  @JsonKey(defaultValue: <ThreadListItemDto>[])
  final List<ThreadListItemDto> threads;
  final String? nextCursor;

  factory ListThreadsResponseDto.fromJson(Map<String, dynamic> json) =>
      _$ListThreadsResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ListThreadsResponseDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class UnreadThreadCountResponseDto {
  const UnreadThreadCountResponseDto({this.unreadThreadCount = 0});

  @JsonKey(defaultValue: 0)
  final int unreadThreadCount;

  factory UnreadThreadCountResponseDto.fromJson(Map<String, dynamic> json) =>
      _$UnreadThreadCountResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$UnreadThreadCountResponseDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class MarkThreadReadResponseDto {
  const MarkThreadReadResponseDto({
    this.lastReadMessageId,
    this.unreadCount = 0,
  });

  final String? lastReadMessageId;
  @JsonKey(defaultValue: 0)
  final int unreadCount;

  factory MarkThreadReadResponseDto.fromJson(Map<String, dynamic> json) =>
      _$MarkThreadReadResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$MarkThreadReadResponseDtoToJson(this);
}
