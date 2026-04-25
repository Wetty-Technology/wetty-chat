import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/messages_api_models.dart';

part 'reaction.freezed.dart';

@freezed
abstract class ReactionReactor with _$ReactionReactor {
  const factory ReactionReactor({
    required int uid,
    String? name,
    String? avatarUrl,
  }) = _ReactionReactor;

  factory ReactionReactor.fromDto(ReactionReactorDto dto) =>
      ReactionReactor(uid: dto.uid, name: dto.name, avatarUrl: dto.avatarUrl);
}

@freezed
abstract class ReactionSummary with _$ReactionSummary {
  const factory ReactionSummary({
    required String emoji,
    required int count,
    bool? reactedByMe,
    List<ReactionReactor>? reactors,
  }) = _ReactionSummary;

  factory ReactionSummary.fromDto(ReactionSummaryDto dto) => ReactionSummary(
    emoji: dto.emoji,
    count: dto.count,
    reactedByMe: dto.reactedByMe,
    reactors: dto.reactors
        ?.map((reactor) => ReactionReactor.fromDto(reactor))
        .toList(),
  );
}
