// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_info_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroupInfoResponseDto _$GroupInfoResponseDtoFromJson(
  Map<String, dynamic> json,
) => GroupInfoResponseDto(
  id: const FlexibleIntConverter().fromJson(json['id']),
  name: json['name'] as String? ?? '',
  description: json['description'] as String?,
  avatarImageId: const NullableFlexibleIntConverter().fromJson(
    json['avatarImageId'],
  ),
  avatar: json['avatar'] as String?,
  visibility: json['visibility'] as String? ?? 'public',
  createdAt: const NullableDateTimeConverter().fromJson(json['createdAt']),
  mutedUntil: const NullableDateTimeConverter().fromJson(json['mutedUntil']),
  myRole: json['myRole'] as String?,
);

Map<String, dynamic> _$GroupInfoResponseDtoToJson(
  GroupInfoResponseDto instance,
) => <String, dynamic>{
  'id': const FlexibleIntConverter().toJson(instance.id),
  'name': instance.name,
  'description': instance.description,
  'avatarImageId': const NullableFlexibleIntConverter().toJson(
    instance.avatarImageId,
  ),
  'avatar': instance.avatar,
  'visibility': instance.visibility,
  'createdAt': const NullableDateTimeConverter().toJson(instance.createdAt),
  'mutedUntil': const NullableDateTimeConverter().toJson(instance.mutedUntil),
  'myRole': instance.myRole,
};

MuteChatRequestDto _$MuteChatRequestDtoFromJson(Map<String, dynamic> json) =>
    MuteChatRequestDto(
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MuteChatRequestDtoToJson(MuteChatRequestDto instance) =>
    <String, dynamic>{'durationSeconds': ?instance.durationSeconds};

UpdateGroupRequestDto _$UpdateGroupRequestDtoFromJson(
  Map<String, dynamic> json,
) => UpdateGroupRequestDto(
  name: json['name'] as String?,
  description: json['description'] as String?,
  avatarImageId: const NullableFlexibleIntConverter().fromJson(
    json['avatarImageId'],
  ),
  visibility: json['visibility'] as String?,
);

Map<String, dynamic> _$UpdateGroupRequestDtoToJson(
  UpdateGroupRequestDto instance,
) => <String, dynamic>{
  'name': ?instance.name,
  'description': ?instance.description,
  'avatarImageId': ?const NullableFlexibleIntConverter().toJson(
    instance.avatarImageId,
  ),
  'visibility': ?instance.visibility,
};
