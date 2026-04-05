// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_members_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroupMemberDto _$GroupMemberDtoFromJson(Map<String, dynamic> json) =>
    GroupMemberDto(
      uid: const FlexibleIntConverter().fromJson(json['uid']),
      username: json['username'] as String?,
      role: json['role'] as String? ?? 'member',
      joinedAt: const NullableDateTimeConverter().fromJson(json['joinedAt']),
    );

Map<String, dynamic> _$GroupMemberDtoToJson(GroupMemberDto instance) =>
    <String, dynamic>{
      'uid': const FlexibleIntConverter().toJson(instance.uid),
      'username': instance.username,
      'role': instance.role,
      'joinedAt': const NullableDateTimeConverter().toJson(instance.joinedAt),
    };

GroupMembersResponseDto _$GroupMembersResponseDtoFromJson(
  Map<String, dynamic> json,
) => GroupMembersResponseDto(
  members:
      (json['members'] as List<dynamic>?)
          ?.map((e) => GroupMemberDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  nextCursor: (json['nextCursor'] as num?)?.toInt(),
  canManageMembers: json['canManageMembers'] as bool? ?? false,
);

Map<String, dynamic> _$GroupMembersResponseDtoToJson(
  GroupMembersResponseDto instance,
) => <String, dynamic>{
  'members': instance.members.map((e) => e.toJson()).toList(),
  'nextCursor': instance.nextCursor,
  'canManageMembers': instance.canManageMembers,
};
