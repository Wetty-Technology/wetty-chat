import 'package:json_annotation/json_annotation.dart';

import 'package:chahua/core/api/converters/flexible_int_converter.dart';
import 'package:chahua/core/api/converters/nullable_date_time_converter.dart';
import 'package:chahua/core/api/models/messages_api_models.dart';

part 'pins_api_models.g.dart';

@JsonSerializable(explicitToJson: true)
class PinResponseDto {
  const PinResponseDto({
    required this.id,
    required this.chatId,
    required this.message,
    required this.pinnedBy,
    required this.pinnedAt,
    this.expiresAt,
  });

  @FlexibleIntConverter()
  final int id;
  @FlexibleIntConverter()
  final int chatId;
  final MessageItemDto message;
  @FlexibleIntConverter()
  final int pinnedBy;
  final DateTime pinnedAt;
  @NullableDateTimeConverter()
  final DateTime? expiresAt;

  factory PinResponseDto.fromJson(Map<String, dynamic> json) =>
      _$PinResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$PinResponseDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class PinUpdatePayloadDto {
  const PinUpdatePayloadDto({
    required this.chatId,
    required this.pinId,
    required this.messageId,
    this.pin,
  });

  @FlexibleIntConverter()
  final int chatId;
  @FlexibleIntConverter()
  final int pinId;
  @FlexibleIntConverter()
  final int messageId;
  final PinResponseDto? pin;

  factory PinUpdatePayloadDto.fromJson(Map<String, dynamic> json) =>
      _$PinUpdatePayloadDtoFromJson(json);

  Map<String, dynamic> toJson() => _$PinUpdatePayloadDtoToJson(this);
}
