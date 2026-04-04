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
    WsPingMessageDto(type: json['type'] as String? ?? 'ping');

Map<String, dynamic> _$WsPingMessageDtoToJson(WsPingMessageDto instance) =>
    <String, dynamic>{'type': instance.type};

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
