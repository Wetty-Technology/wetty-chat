// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_messages_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SavedAttachmentSnapshotDto _$SavedAttachmentSnapshotDtoFromJson(
  Map<String, dynamic> json,
) => SavedAttachmentSnapshotDto(
  id: const StringValueConverter().fromJson(json['id']),
  url: json['url'] as String? ?? '',
  kind: json['kind'] as String? ?? 'application/octet-stream',
  size: (json['size'] as num?)?.toInt() ?? 0,
  fileName: json['fileName'] as String? ?? '',
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
);

Map<String, dynamic> _$SavedAttachmentSnapshotDtoToJson(
  SavedAttachmentSnapshotDto instance,
) => <String, dynamic>{
  'id': const StringValueConverter().toJson(instance.id),
  'url': instance.url,
  'kind': instance.kind,
  'size': instance.size,
  'fileName': instance.fileName,
  'width': instance.width,
  'height': instance.height,
};

SavedStickerSnapshotDto _$SavedStickerSnapshotDtoFromJson(
  Map<String, dynamic> json,
) => SavedStickerSnapshotDto(
  id: const StringValueConverter().fromJson(json['id']),
  emoji: json['emoji'] as String?,
  name: json['name'] as String?,
  mediaUrl: json['mediaUrl'] as String? ?? '',
  mediaContentType: json['mediaContentType'] as String? ?? 'image/webp',
);

Map<String, dynamic> _$SavedStickerSnapshotDtoToJson(
  SavedStickerSnapshotDto instance,
) => <String, dynamic>{
  'id': const StringValueConverter().toJson(instance.id),
  'emoji': instance.emoji,
  'name': instance.name,
  'mediaUrl': instance.mediaUrl,
  'mediaContentType': instance.mediaContentType,
};

SavedSenderSnapshotDto _$SavedSenderSnapshotDtoFromJson(
  Map<String, dynamic> json,
) => SavedSenderSnapshotDto(
  uid: const FlexibleIntConverter().fromJson(json['uid']),
  name: json['name'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  gender: (json['gender'] as num?)?.toInt() ?? 0,
  userGroup: json['userGroup'] == null
      ? null
      : UserGroupTagInfoDto.fromJson(json['userGroup'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SavedSenderSnapshotDtoToJson(
  SavedSenderSnapshotDto instance,
) => <String, dynamic>{
  'uid': const FlexibleIntConverter().toJson(instance.uid),
  'name': instance.name,
  'avatarUrl': instance.avatarUrl,
  'gender': instance.gender,
  'userGroup': instance.userGroup?.toJson(),
};

SavedChatSnapshotDto _$SavedChatSnapshotDtoFromJson(
  Map<String, dynamic> json,
) => SavedChatSnapshotDto(
  id: const FlexibleIntConverter().fromJson(json['id']),
  name: json['name'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
);

Map<String, dynamic> _$SavedChatSnapshotDtoToJson(
  SavedChatSnapshotDto instance,
) => <String, dynamic>{
  'id': const FlexibleIntConverter().toJson(instance.id),
  'name': instance.name,
  'avatarUrl': instance.avatarUrl,
};

SavedMessageResponseDto _$SavedMessageResponseDtoFromJson(
  Map<String, dynamic> json,
) => SavedMessageResponseDto(
  id: const FlexibleIntConverter().fromJson(json['id']),
  originalChatId: const FlexibleIntConverter().fromJson(json['originalChatId']),
  originalThreadRootId: const NullableFlexibleIntConverter().fromJson(
    json['originalThreadRootId'],
  ),
  originalMessageId: const FlexibleIntConverter().fromJson(
    json['originalMessageId'],
  ),
  originalReplyToMessageId: const NullableFlexibleIntConverter().fromJson(
    json['originalReplyToMessageId'],
  ),
  originalSenderUid: const FlexibleIntConverter().fromJson(
    json['originalSenderUid'],
  ),
  originalCreatedAt: DateTime.parse(json['originalCreatedAt'] as String),
  savedAt: DateTime.parse(json['savedAt'] as String),
  message: json['message'] as String?,
  messageType: json['messageType'] as String? ?? 'text',
  attachments:
      (json['attachments'] as List<dynamic>?)
          ?.map(
            (e) =>
                SavedAttachmentSnapshotDto.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      [],
  sticker: json['sticker'] == null
      ? null
      : SavedStickerSnapshotDto.fromJson(
          json['sticker'] as Map<String, dynamic>,
        ),
  mentions:
      (json['mentions'] as List<dynamic>?)
          ?.map((e) => MentionInfoDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  sender: SavedSenderSnapshotDto.fromJson(
    json['sender'] as Map<String, dynamic>,
  ),
  chat: SavedChatSnapshotDto.fromJson(json['chat'] as Map<String, dynamic>),
  canLocateContext: json['canLocateContext'] as bool? ?? false,
);

Map<String, dynamic> _$SavedMessageResponseDtoToJson(
  SavedMessageResponseDto instance,
) => <String, dynamic>{
  'id': const FlexibleIntConverter().toJson(instance.id),
  'originalChatId': const FlexibleIntConverter().toJson(
    instance.originalChatId,
  ),
  'originalThreadRootId': const NullableFlexibleIntConverter().toJson(
    instance.originalThreadRootId,
  ),
  'originalMessageId': const FlexibleIntConverter().toJson(
    instance.originalMessageId,
  ),
  'originalReplyToMessageId': const NullableFlexibleIntConverter().toJson(
    instance.originalReplyToMessageId,
  ),
  'originalSenderUid': const FlexibleIntConverter().toJson(
    instance.originalSenderUid,
  ),
  'originalCreatedAt': instance.originalCreatedAt.toIso8601String(),
  'savedAt': instance.savedAt.toIso8601String(),
  'message': instance.message,
  'messageType': instance.messageType,
  'attachments': instance.attachments.map((e) => e.toJson()).toList(),
  'sticker': instance.sticker?.toJson(),
  'mentions': instance.mentions.map((e) => e.toJson()).toList(),
  'sender': instance.sender.toJson(),
  'chat': instance.chat.toJson(),
  'canLocateContext': instance.canLocateContext,
};

ListSavedMessagesResponseDto _$ListSavedMessagesResponseDtoFromJson(
  Map<String, dynamic> json,
) => ListSavedMessagesResponseDto(
  savedMessages:
      (json['savedMessages'] as List<dynamic>?)
          ?.map(
            (e) => SavedMessageResponseDto.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      [],
  nextCursor: const NullableFlexibleIntConverter().fromJson(json['nextCursor']),
);

Map<String, dynamic> _$ListSavedMessagesResponseDtoToJson(
  ListSavedMessagesResponseDto instance,
) => <String, dynamic>{
  'savedMessages': instance.savedMessages.map((e) => e.toJson()).toList(),
  'nextCursor': const NullableFlexibleIntConverter().toJson(
    instance.nextCursor,
  ),
};
