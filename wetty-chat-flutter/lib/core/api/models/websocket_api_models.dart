import 'package:json_annotation/json_annotation.dart';

import 'messages_api_models.dart';

part 'websocket_api_models.g.dart';

@JsonSerializable(explicitToJson: true)
class WsTicketResponseDto {
  const WsTicketResponseDto({required this.ticket});

  final String ticket;

  factory WsTicketResponseDto.fromJson(Map<String, dynamic> json) =>
      _$WsTicketResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$WsTicketResponseDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class WsAuthMessageDto {
  const WsAuthMessageDto({required this.ticket, this.type = 'auth'});

  final String type;
  final String ticket;

  factory WsAuthMessageDto.fromJson(Map<String, dynamic> json) =>
      _$WsAuthMessageDtoFromJson(json);

  Map<String, dynamic> toJson() => _$WsAuthMessageDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class WsPingMessageDto {
  const WsPingMessageDto({this.type = 'ping'});

  final String type;

  factory WsPingMessageDto.fromJson(Map<String, dynamic> json) =>
      _$WsPingMessageDtoFromJson(json);

  Map<String, dynamic> toJson() => _$WsPingMessageDtoToJson(this);
}

sealed class ApiWsEvent {
  const ApiWsEvent();

  static ApiWsEvent? fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    if (type is! String) return null;
    switch (type) {
      case 'pong':
        return const PongWsEvent();
      case 'message':
        return MessageCreatedWsEvent.fromJson(json);
      case 'messageUpdated':
        return MessageUpdatedWsEvent.fromJson(json);
      case 'messageDeleted':
        return MessageDeletedWsEvent.fromJson(json);
      default:
        return null;
    }
  }
}

class PongWsEvent extends ApiWsEvent {
  const PongWsEvent();
}

@JsonSerializable(explicitToJson: true)
class MessageCreatedWsEvent extends ApiWsEvent {
  const MessageCreatedWsEvent({this.type = 'message', required this.payload});

  final String type;
  final MessageItemDto payload;

  factory MessageCreatedWsEvent.fromJson(Map<String, dynamic> json) =>
      _$MessageCreatedWsEventFromJson(json);

  Map<String, dynamic> toJson() => _$MessageCreatedWsEventToJson(this);
}

@JsonSerializable(explicitToJson: true)
class MessageUpdatedWsEvent extends ApiWsEvent {
  const MessageUpdatedWsEvent({
    this.type = 'messageUpdated',
    required this.payload,
  });

  final String type;
  final MessageItemDto payload;

  factory MessageUpdatedWsEvent.fromJson(Map<String, dynamic> json) =>
      _$MessageUpdatedWsEventFromJson(json);

  Map<String, dynamic> toJson() => _$MessageUpdatedWsEventToJson(this);
}

@JsonSerializable(explicitToJson: true)
class MessageDeletedWsEvent extends ApiWsEvent {
  const MessageDeletedWsEvent({
    this.type = 'messageDeleted',
    required this.payload,
  });

  final String type;
  final MessageItemDto payload;

  factory MessageDeletedWsEvent.fromJson(Map<String, dynamic> json) =>
      _$MessageDeletedWsEventFromJson(json);

  Map<String, dynamic> toJson() => _$MessageDeletedWsEventToJson(this);
}
