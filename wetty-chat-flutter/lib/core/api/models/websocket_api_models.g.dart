// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'websocket_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsTicketResponseDto _$WsTicketResponseDtoFromJson(Map<String, dynamic> json) =>
    WsTicketResponseDto(ticket: json['ticket'] as String);

Map<String, dynamic> _$WsTicketResponseDtoToJson(
  WsTicketResponseDto instance,
) => <String, dynamic>{'ticket': instance.ticket};

WsAuthMessageDto _$WsAuthMessageDtoFromJson(Map<String, dynamic> json) =>
    WsAuthMessageDto(
      ticket: json['ticket'] as String,
      type: json['type'] as String? ?? 'auth',
    );

Map<String, dynamic> _$WsAuthMessageDtoToJson(WsAuthMessageDto instance) =>
    <String, dynamic>{'type': instance.type, 'ticket': instance.ticket};

WsPingMessageDto _$WsPingMessageDtoFromJson(Map<String, dynamic> json) =>
    WsPingMessageDto(
      type: json['type'] as String? ?? 'ping',
      state: $enumDecodeNullable(_$WsClientAppStateEnumMap, json['state']),
    );

Map<String, dynamic> _$WsPingMessageDtoToJson(WsPingMessageDto instance) =>
    <String, dynamic>{
      'type': instance.type,
      'state': _$WsClientAppStateEnumMap[instance.state],
    };

const _$WsClientAppStateEnumMap = {
  WsClientAppState.active: 'active',
  WsClientAppState.inactive: 'inactive',
};

WsAppStateMessageDto _$WsAppStateMessageDtoFromJson(
  Map<String, dynamic> json,
) => WsAppStateMessageDto(
  type: json['type'] as String? ?? 'appState',
  state: $enumDecode(_$WsClientAppStateEnumMap, json['state']),
);

Map<String, dynamic> _$WsAppStateMessageDtoToJson(
  WsAppStateMessageDto instance,
) => <String, dynamic>{
  'type': instance.type,
  'state': _$WsClientAppStateEnumMap[instance.state]!,
};

MessageCreatedWsEvent _$MessageCreatedWsEventFromJson(
  Map<String, dynamic> json,
) => MessageCreatedWsEvent(
  type: json['type'] as String? ?? 'message',
  payload: MessageItemDto.fromJson(json['payload'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MessageCreatedWsEventToJson(
  MessageCreatedWsEvent instance,
) => <String, dynamic>{
  'type': instance.type,
  'payload': instance.payload.toJson(),
};

MessageUpdatedWsEvent _$MessageUpdatedWsEventFromJson(
  Map<String, dynamic> json,
) => MessageUpdatedWsEvent(
  type: json['type'] as String? ?? 'messageUpdated',
  payload: MessageItemDto.fromJson(json['payload'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MessageUpdatedWsEventToJson(
  MessageUpdatedWsEvent instance,
) => <String, dynamic>{
  'type': instance.type,
  'payload': instance.payload.toJson(),
};

MessageDeletedWsEvent _$MessageDeletedWsEventFromJson(
  Map<String, dynamic> json,
) => MessageDeletedWsEvent(
  type: json['type'] as String? ?? 'messageDeleted',
  payload: MessageItemDto.fromJson(json['payload'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MessageDeletedWsEventToJson(
  MessageDeletedWsEvent instance,
) => <String, dynamic>{
  'type': instance.type,
  'payload': instance.payload.toJson(),
};

ReactionUpdatePayloadDto _$ReactionUpdatePayloadDtoFromJson(
  Map<String, dynamic> json,
) => ReactionUpdatePayloadDto(
  messageId: const FlexibleIntConverter().fromJson(json['messageId']),
  chatId: const FlexibleIntConverter().fromJson(json['chatId']),
  reactions:
      (json['reactions'] as List<dynamic>?)
          ?.map((e) => ReactionSummaryDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$ReactionUpdatePayloadDtoToJson(
  ReactionUpdatePayloadDto instance,
) => <String, dynamic>{
  'messageId': const FlexibleIntConverter().toJson(instance.messageId),
  'chatId': const FlexibleIntConverter().toJson(instance.chatId),
  'reactions': instance.reactions.map((e) => e.toJson()).toList(),
};

ReactionUpdatedWsEvent _$ReactionUpdatedWsEventFromJson(
  Map<String, dynamic> json,
) => ReactionUpdatedWsEvent(
  type: json['type'] as String? ?? 'reactionUpdated',
  payload: ReactionUpdatePayloadDto.fromJson(
    json['payload'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$ReactionUpdatedWsEventToJson(
  ReactionUpdatedWsEvent instance,
) => <String, dynamic>{
  'type': instance.type,
  'payload': instance.payload.toJson(),
};

ThreadUpdatePayloadDto _$ThreadUpdatePayloadDtoFromJson(
  Map<String, dynamic> json,
) => ThreadUpdatePayloadDto(
  threadRootId: const FlexibleIntConverter().fromJson(json['threadRootId']),
  chatId: const FlexibleIntConverter().fromJson(json['chatId']),
  lastReplyAt: DateTime.parse(json['lastReplyAt'] as String),
  replyCount: const FlexibleIntConverter().fromJson(json['replyCount']),
);

Map<String, dynamic> _$ThreadUpdatePayloadDtoToJson(
  ThreadUpdatePayloadDto instance,
) => <String, dynamic>{
  'threadRootId': const FlexibleIntConverter().toJson(instance.threadRootId),
  'chatId': const FlexibleIntConverter().toJson(instance.chatId),
  'lastReplyAt': instance.lastReplyAt.toIso8601String(),
  'replyCount': const FlexibleIntConverter().toJson(instance.replyCount),
};

ThreadUpdatedWsEvent _$ThreadUpdatedWsEventFromJson(
  Map<String, dynamic> json,
) => ThreadUpdatedWsEvent(
  type: json['type'] as String? ?? 'threadUpdate',
  payload: ThreadUpdatePayloadDto.fromJson(
    json['payload'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$ThreadUpdatedWsEventToJson(
  ThreadUpdatedWsEvent instance,
) => <String, dynamic>{
  'type': instance.type,
  'payload': instance.payload.toJson(),
};

StickerPackOrderItemDto _$StickerPackOrderItemDtoFromJson(
  Map<String, dynamic> json,
) => StickerPackOrderItemDto(
  stickerPackId: json['stickerPackId'] as String,
  lastUsedOn: (json['lastUsedOn'] as num).toInt(),
);

Map<String, dynamic> _$StickerPackOrderItemDtoToJson(
  StickerPackOrderItemDto instance,
) => <String, dynamic>{
  'stickerPackId': instance.stickerPackId,
  'lastUsedOn': instance.lastUsedOn,
};

StickerPackOrderUpdatePayloadDto _$StickerPackOrderUpdatePayloadDtoFromJson(
  Map<String, dynamic> json,
) => StickerPackOrderUpdatePayloadDto(
  order: (json['order'] as List<dynamic>)
      .map((e) => StickerPackOrderItemDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$StickerPackOrderUpdatePayloadDtoToJson(
  StickerPackOrderUpdatePayloadDto instance,
) => <String, dynamic>{'order': instance.order.map((e) => e.toJson()).toList()};
