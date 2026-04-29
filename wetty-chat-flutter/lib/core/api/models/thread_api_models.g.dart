// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thread_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThreadListItemDto _$ThreadListItemDtoFromJson(
  Map<String, dynamic> json,
) => ThreadListItemDto(
  chatId: const FlexibleIntConverter().fromJson(json['chatId']),
  chatName: json['chatName'] as String,
  chatAvatar: json['chatAvatar'] as String?,
  threadRootMessage: MessagePreviewDto.fromJson(
    json['threadRootMessage'] as Map<String, dynamic>,
  ),
  participants:
      (json['participants'] as List<dynamic>?)
          ?.map((e) => UserDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  lastReply: json['lastReply'] == null
      ? null
      : MessagePreviewDto.fromJson(json['lastReply'] as Map<String, dynamic>),
  replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
  lastReplyAt: const NullableDateTimeConverter().fromJson(json['lastReplyAt']),
  unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
  subscribedAt: const NullableDateTimeConverter().fromJson(
    json['subscribedAt'],
  ),
);

Map<String, dynamic> _$ThreadListItemDtoToJson(
  ThreadListItemDto instance,
) => <String, dynamic>{
  'chatId': const FlexibleIntConverter().toJson(instance.chatId),
  'chatName': instance.chatName,
  'chatAvatar': instance.chatAvatar,
  'threadRootMessage': instance.threadRootMessage.toJson(),
  'participants': instance.participants.map((e) => e.toJson()).toList(),
  'lastReply': instance.lastReply?.toJson(),
  'replyCount': instance.replyCount,
  'lastReplyAt': const NullableDateTimeConverter().toJson(instance.lastReplyAt),
  'unreadCount': instance.unreadCount,
  'subscribedAt': const NullableDateTimeConverter().toJson(
    instance.subscribedAt,
  ),
};

ListThreadsResponseDto _$ListThreadsResponseDtoFromJson(
  Map<String, dynamic> json,
) => ListThreadsResponseDto(
  threads:
      (json['threads'] as List<dynamic>?)
          ?.map((e) => ThreadListItemDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  nextCursor: json['nextCursor'] as String?,
);

Map<String, dynamic> _$ListThreadsResponseDtoToJson(
  ListThreadsResponseDto instance,
) => <String, dynamic>{
  'threads': instance.threads.map((e) => e.toJson()).toList(),
  'nextCursor': instance.nextCursor,
};

UnreadThreadCountResponseDto _$UnreadThreadCountResponseDtoFromJson(
  Map<String, dynamic> json,
) => UnreadThreadCountResponseDto(
  unreadThreadCount: (json['unreadThreadCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$UnreadThreadCountResponseDtoToJson(
  UnreadThreadCountResponseDto instance,
) => <String, dynamic>{'unreadThreadCount': instance.unreadThreadCount};

MarkThreadReadResponseDto _$MarkThreadReadResponseDtoFromJson(
  Map<String, dynamic> json,
) => MarkThreadReadResponseDto(
  lastReadMessageId: json['lastReadMessageId'] as String?,
  unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$MarkThreadReadResponseDtoToJson(
  MarkThreadReadResponseDto instance,
) => <String, dynamic>{
  'lastReadMessageId': instance.lastReadMessageId,
  'unreadCount': instance.unreadCount,
};
