import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/messages_api_models.dart';

import 'mention.dart';

part 'user.freezed.dart';

@freezed
abstract class User with _$User {
  const factory User({
    required int uid,
    String? name,
    String? avatarUrl,
    @Default(0) int gender,
    UserGroupTagInfo? userGroup,
  }) = _User;

  factory User.fromDto(UserDto dto) => User(
    uid: dto.uid,
    name: dto.name,
    avatarUrl: dto.avatarUrl,
    gender: dto.gender,
    userGroup: dto.userGroup == null
        ? null
        : UserGroupTagInfo.fromDto(dto.userGroup!),
  );
}
