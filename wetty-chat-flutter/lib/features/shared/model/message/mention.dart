import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/messages_api_models.dart';

part 'mention.freezed.dart';

@freezed
abstract class UserGroupTagInfo with _$UserGroupTagInfo {
  const factory UserGroupTagInfo({
    required int groupId,
    String? name,
    String? chatGroupColor,
    String? chatGroupColorDark,
  }) = _UserGroupTagInfo;

  factory UserGroupTagInfo.fromDto(UserGroupTagInfoDto dto) => UserGroupTagInfo(
    groupId: dto.groupId,
    name: dto.name,
    chatGroupColor: dto.chatGroupColor,
    chatGroupColorDark: dto.chatGroupColorDark,
  );
}

@freezed
abstract class MentionInfo with _$MentionInfo {
  const factory MentionInfo({
    required int uid,
    String? username,
    String? avatarUrl,
    @Default(0) int gender,
    UserGroupTagInfo? userGroup,
  }) = _MentionInfo;

  factory MentionInfo.fromDto(MentionInfoDto dto) => MentionInfo(
    uid: dto.uid,
    username: dto.username,
    avatarUrl: dto.avatarUrl,
    gender: dto.gender,
    userGroup: dto.userGroup == null
        ? null
        : UserGroupTagInfo.fromDto(dto.userGroup!),
  );
}
