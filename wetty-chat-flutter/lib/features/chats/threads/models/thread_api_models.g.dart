// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thread_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ThreadParticipantDto _$ThreadParticipantDtoFromJson(
  Map<String, dynamic> json,
) => ThreadParticipantDto(
  uid: const FlexibleIntConverter().fromJson(json['uid']),
  name: json['name'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
);

Map<String, dynamic> _$ThreadParticipantDtoToJson(
  ThreadParticipantDto instance,
) => <String, dynamic>{
  'uid': const FlexibleIntConverter().toJson(instance.uid),
  'name': instance.name,
  'avatarUrl': instance.avatarUrl,
};

ThreadReplyPreviewDto _$ThreadReplyPreviewDtoFromJson(
  Map<String, dynamic> json,
) => ThreadReplyPreviewDto(
  id: const NullableFlexibleIntConverter().fromJson(json['id']),
  clientGeneratedId: json['clientGeneratedId'] as String? ?? '',
  sender: ThreadParticipantDto.fromJson(json['sender'] as Map<String, dynamic>),
  message: json['message'] as String?,
  messageType: json['messageType'] as String? ?? 'text',
  stickerEmoji: json['stickerEmoji'] as String?,
  firstAttachmentKind: json['firstAttachmentKind'] as String?,
  isDeleted: json['isDeleted'] as bool? ?? false,
  mentions:
      (json['mentions'] as List<dynamic>?)
          ?.map((e) => MentionInfoDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$ThreadReplyPreviewDtoToJson(
  ThreadReplyPreviewDto instance,
) => <String, dynamic>{
  'id': const NullableFlexibleIntConverter().toJson(instance.id),
  'clientGeneratedId': instance.clientGeneratedId,
  'sender': instance.sender.toJson(),
  'message': instance.message,
  'messageType': instance.messageType,
  'stickerEmoji': instance.stickerEmoji,
  'firstAttachmentKind': instance.firstAttachmentKind,
  'isDeleted': instance.isDeleted,
  'mentions': instance.mentions.map((e) => e.toJson()).toList(),
};

ThreadListItemDto _$ThreadListItemDtoFromJson(
  Map<String, dynamic> json,
) => ThreadListItemDto(
  chatId: const FlexibleIntConverter().fromJson(json['chatId']),
  chatName: json['chatName'] as String,
  chatAvatar: json['chatAvatar'] as String?,
  threadRootMessage: MessageItemDto.fromJson(
    json['threadRootMessage'] as Map<String, dynamic>,
  ),
  participants:
      (json['participants'] as List<dynamic>?)
          ?.map((e) => ThreadParticipantDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  lastReply: json['lastReply'] == null
      ? null
      : ThreadReplyPreviewDto.fromJson(
          json['lastReply'] as Map<String, dynamic>,
        ),
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
  updated: json['updated'] as bool? ?? false,
);

Map<String, dynamic> _$MarkThreadReadResponseDtoToJson(
  MarkThreadReadResponseDto instance,
) => <String, dynamic>{'updated': instance.updated};
