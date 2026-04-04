import 'package:json_annotation/json_annotation.dart';

import '../converters/flexible_int_converter.dart';

part 'group_members_api_models.g.dart';

@JsonSerializable(explicitToJson: true)
class GroupMemberDto {
  const GroupMemberDto({
    required this.uid,
    this.username,
    this.role = 'member',
    this.joinedAt = '',
  });

  @FlexibleIntConverter()
  final int uid;
  final String? username;
  @JsonKey(defaultValue: 'member')
  final String role;
  @JsonKey(defaultValue: '')
  final String joinedAt;

  factory GroupMemberDto.fromJson(Map<String, dynamic> json) =>
      _$GroupMemberDtoFromJson(json);

  Map<String, dynamic> toJson() => _$GroupMemberDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class GroupMembersResponseDto {
  const GroupMembersResponseDto({
    this.members = const [],
    this.nextCursor,
    this.canManageMembers = false,
  });

  @JsonKey(defaultValue: <GroupMemberDto>[])
  final List<GroupMemberDto> members;
  final int? nextCursor;
  @JsonKey(defaultValue: false)
  final bool canManageMembers;

  factory GroupMembersResponseDto.fromJson(Map<String, dynamic> json) =>
      _$GroupMembersResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$GroupMembersResponseDtoToJson(this);
}
