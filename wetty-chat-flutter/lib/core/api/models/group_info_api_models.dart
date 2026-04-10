import 'package:json_annotation/json_annotation.dart';

import '../converters/flexible_int_converter.dart';
import '../converters/nullable_date_time_converter.dart';

part 'group_info_api_models.g.dart';

@JsonSerializable(explicitToJson: true)
class GroupInfoResponseDto {
  const GroupInfoResponseDto({
    required this.id,
    this.name = '',
    this.description,
    this.avatarImageId,
    this.avatar,
    this.visibility = 'public',
    this.createdAt,
    this.mutedUntil,
    this.myRole,
  });

  @FlexibleIntConverter()
  final int id;
  @JsonKey(defaultValue: '')
  final String name;
  final String? description;
  @NullableFlexibleIntConverter()
  final int? avatarImageId;
  final String? avatar;
  @JsonKey(defaultValue: 'public')
  final String visibility;
  @NullableDateTimeConverter()
  final DateTime? createdAt;
  @NullableDateTimeConverter()
  final DateTime? mutedUntil;
  final String? myRole;

  factory GroupInfoResponseDto.fromJson(Map<String, dynamic> json) =>
      _$GroupInfoResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$GroupInfoResponseDtoToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class MuteChatRequestDto {
  const MuteChatRequestDto({this.durationSeconds});

  final int? durationSeconds;

  factory MuteChatRequestDto.fromJson(Map<String, dynamic> json) =>
      _$MuteChatRequestDtoFromJson(json);

  Map<String, dynamic> toJson() => _$MuteChatRequestDtoToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class UpdateGroupRequestDto {
  const UpdateGroupRequestDto({
    this.name,
    this.description,
    this.avatarImageId,
    this.visibility,
  });

  final String? name;
  final String? description;
  @NullableFlexibleIntConverter()
  final int? avatarImageId;
  final String? visibility;

  factory UpdateGroupRequestDto.fromJson(Map<String, dynamic> json) =>
      _$UpdateGroupRequestDtoFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateGroupRequestDtoToJson(this);
}
