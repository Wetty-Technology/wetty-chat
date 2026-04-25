import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/messages_api_models.dart';

part 'sender.freezed.dart';

@freezed
abstract class Sender with _$Sender {
  const factory Sender({
    required int uid,
    String? name,
    String? avatarUrl,
    @Default(0) int gender,
  }) = _Sender;

  factory Sender.fromDto(SenderDto dto) => Sender(
    uid: dto.uid,
    name: dto.name,
    avatarUrl: dto.avatarUrl,
    gender: dto.gender,
  );
}
