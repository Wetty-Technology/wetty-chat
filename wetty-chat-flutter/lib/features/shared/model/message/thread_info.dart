import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/messages_api_models.dart';

part 'thread_info.freezed.dart';

@freezed
abstract class ThreadInfo with _$ThreadInfo {
  const factory ThreadInfo({required int replyCount}) = _ThreadInfo;

  factory ThreadInfo.fromDto(ThreadInfoDto dto) =>
      ThreadInfo(replyCount: dto.replyCount);
}
