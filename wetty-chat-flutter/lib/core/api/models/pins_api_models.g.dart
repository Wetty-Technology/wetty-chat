// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pins_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PinResponseDto _$PinResponseDtoFromJson(Map<String, dynamic> json) =>
    PinResponseDto(
      id: const FlexibleIntConverter().fromJson(json['id']),
      chatId: const FlexibleIntConverter().fromJson(json['chatId']),
      message: MessageItemDto.fromJson(json['message'] as Map<String, dynamic>),
      pinnedBy: const FlexibleIntConverter().fromJson(json['pinnedBy']),
      pinnedAt: DateTime.parse(json['pinnedAt'] as String),
      expiresAt: const NullableDateTimeConverter().fromJson(json['expiresAt']),
    );

Map<String, dynamic> _$PinResponseDtoToJson(PinResponseDto instance) =>
    <String, dynamic>{
      'id': const FlexibleIntConverter().toJson(instance.id),
      'chatId': const FlexibleIntConverter().toJson(instance.chatId),
      'message': instance.message.toJson(),
      'pinnedBy': const FlexibleIntConverter().toJson(instance.pinnedBy),
      'pinnedAt': instance.pinnedAt.toIso8601String(),
      'expiresAt': const NullableDateTimeConverter().toJson(instance.expiresAt),
    };

PinUpdatePayloadDto _$PinUpdatePayloadDtoFromJson(Map<String, dynamic> json) =>
    PinUpdatePayloadDto(
      chatId: const FlexibleIntConverter().fromJson(json['chatId']),
      pinId: const FlexibleIntConverter().fromJson(json['pinId']),
      messageId: const FlexibleIntConverter().fromJson(json['messageId']),
      pin: json['pin'] == null
          ? null
          : PinResponseDto.fromJson(json['pin'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PinUpdatePayloadDtoToJson(
  PinUpdatePayloadDto instance,
) => <String, dynamic>{
  'chatId': const FlexibleIntConverter().toJson(instance.chatId),
  'pinId': const FlexibleIntConverter().toJson(instance.pinId),
  'messageId': const FlexibleIntConverter().toJson(instance.messageId),
  'pin': instance.pin?.toJson(),
};
