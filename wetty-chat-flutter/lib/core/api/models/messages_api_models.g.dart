// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'messages_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SenderDto _$SenderDtoFromJson(Map<String, dynamic> json) => SenderDto(
  uid: const FlexibleIntConverter().fromJson(json['uid']),
  name: json['name'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  gender: (json['gender'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$SenderDtoToJson(SenderDto instance) => <String, dynamic>{
  'uid': const FlexibleIntConverter().toJson(instance.uid),
  'name': instance.name,
  'avatarUrl': instance.avatarUrl,
  'gender': instance.gender,
};

AttachmentItemDto _$AttachmentItemDtoFromJson(Map<String, dynamic> json) =>
    AttachmentItemDto(
      id: const StringValueConverter().fromJson(json['id']),
      url: json['url'] as String? ?? '',
      kind: json['kind'] as String? ?? 'application/octet-stream',
      size: (json['size'] as num?)?.toInt() ?? 0,
      fileName: json['fileName'] as String? ?? '',
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AttachmentItemDtoToJson(AttachmentItemDto instance) =>
    <String, dynamic>{
      'id': const StringValueConverter().toJson(instance.id),
      'url': instance.url,
      'kind': instance.kind,
      'size': instance.size,
      'fileName': instance.fileName,
      'width': instance.width,
      'height': instance.height,
    };

ReplyToMessageDto _$ReplyToMessageDtoFromJson(Map<String, dynamic> json) =>
    ReplyToMessageDto(
      id: const FlexibleIntConverter().fromJson(json['id']),
      message: json['message'] as String?,
      sender: SenderDto.fromJson(json['sender'] as Map<String, dynamic>),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );

Map<String, dynamic> _$ReplyToMessageDtoToJson(ReplyToMessageDto instance) =>
    <String, dynamic>{
      'id': const FlexibleIntConverter().toJson(instance.id),
      'message': instance.message,
      'sender': instance.sender.toJson(),
      'isDeleted': instance.isDeleted,
    };

ThreadInfoDto _$ThreadInfoDtoFromJson(Map<String, dynamic> json) =>
    ThreadInfoDto(replyCount: (json['replyCount'] as num?)?.toInt() ?? 0);

Map<String, dynamic> _$ThreadInfoDtoToJson(ThreadInfoDto instance) =>
    <String, dynamic>{'replyCount': instance.replyCount};

MessageItemDto _$MessageItemDtoFromJson(Map<String, dynamic> json) =>
    MessageItemDto(
      id: const FlexibleIntConverter().fromJson(json['id']),
      message: json['message'] as String?,
      messageType: json['messageType'] as String? ?? 'text',
      sender: SenderDto.fromJson(json['sender'] as Map<String, dynamic>),
      chatId: const FlexibleIntConverter().fromJson(json['chatId']),
      createdAt: json['createdAt'] as String? ?? '',
      isEdited: json['isEdited'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      clientGeneratedId: json['clientGeneratedId'] as String? ?? '',
      replyRootId: const NullableFlexibleIntConverter().fromJson(
        json['replyRootId'],
      ),
      hasAttachments: json['hasAttachments'] as bool? ?? false,
      replyToMessage: json['replyToMessage'] == null
          ? null
          : ReplyToMessageDto.fromJson(
              json['replyToMessage'] as Map<String, dynamic>,
            ),
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map(
                (e) => AttachmentItemDto.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      threadInfo: json['threadInfo'] == null
          ? null
          : ThreadInfoDto.fromJson(json['threadInfo'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MessageItemDtoToJson(MessageItemDto instance) =>
    <String, dynamic>{
      'id': const FlexibleIntConverter().toJson(instance.id),
      'message': instance.message,
      'messageType': instance.messageType,
      'sender': instance.sender.toJson(),
      'chatId': const FlexibleIntConverter().toJson(instance.chatId),
      'createdAt': instance.createdAt,
      'isEdited': instance.isEdited,
      'isDeleted': instance.isDeleted,
      'clientGeneratedId': instance.clientGeneratedId,
      'replyRootId': const NullableFlexibleIntConverter().toJson(
        instance.replyRootId,
      ),
      'hasAttachments': instance.hasAttachments,
      'replyToMessage': instance.replyToMessage?.toJson(),
      'attachments': instance.attachments.map((e) => e.toJson()).toList(),
      'threadInfo': instance.threadInfo?.toJson(),
    };

ListMessagesResponseDto _$ListMessagesResponseDtoFromJson(
  Map<String, dynamic> json,
) => ListMessagesResponseDto(
  messages:
      (json['messages'] as List<dynamic>?)
          ?.map((e) => MessageItemDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  nextCursor: json['nextCursor'] as String?,
  prevCursor: json['prevCursor'] as String?,
);

Map<String, dynamic> _$ListMessagesResponseDtoToJson(
  ListMessagesResponseDto instance,
) => <String, dynamic>{
  'messages': instance.messages.map((e) => e.toJson()).toList(),
  'nextCursor': instance.nextCursor,
  'prevCursor': instance.prevCursor,
};

SendMessageRequestDto _$SendMessageRequestDtoFromJson(
  Map<String, dynamic> json,
) => SendMessageRequestDto(
  message: json['message'] as String,
  messageType: json['messageType'] as String,
  clientGeneratedId: json['clientGeneratedId'] as String,
  attachmentIds:
      (json['attachmentIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  replyToId: (json['replyToId'] as num?)?.toInt(),
);

Map<String, dynamic> _$SendMessageRequestDtoToJson(
  SendMessageRequestDto instance,
) => <String, dynamic>{
  'message': instance.message,
  'messageType': instance.messageType,
  'clientGeneratedId': instance.clientGeneratedId,
  'attachmentIds': instance.attachmentIds,
  'replyToId': instance.replyToId,
};

EditMessageRequestDto _$EditMessageRequestDtoFromJson(
  Map<String, dynamic> json,
) => EditMessageRequestDto(
  message: json['message'] as String,
  attachmentIds:
      (json['attachmentIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
);

Map<String, dynamic> _$EditMessageRequestDtoToJson(
  EditMessageRequestDto instance,
) => <String, dynamic>{
  'message': instance.message,
  'attachmentIds': instance.attachmentIds,
};

MarkReadRequestDto _$MarkReadRequestDtoFromJson(Map<String, dynamic> json) =>
    MarkReadRequestDto(
      messageId: const FlexibleIntConverter().fromJson(json['messageId']),
    );

Map<String, dynamic> _$MarkReadRequestDtoToJson(MarkReadRequestDto instance) =>
    <String, dynamic>{
      'messageId': const FlexibleIntConverter().toJson(instance.messageId),
    };
