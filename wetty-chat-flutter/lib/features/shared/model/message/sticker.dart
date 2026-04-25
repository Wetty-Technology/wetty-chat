import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/messages_api_models.dart';

part 'sticker.freezed.dart';

@freezed
abstract class StickerMedia with _$StickerMedia {
  const StickerMedia._();

  const factory StickerMedia({
    required String id,
    required String url,
    required String contentType,
    required int size,
    int? width,
    int? height,
  }) = _StickerMedia;

  bool get isVideo => contentType.startsWith('video/');

  factory StickerMedia.fromDto(StickerMediaDto dto) => StickerMedia(
    id: dto.id,
    url: dto.url,
    contentType: dto.contentType,
    size: dto.size,
    width: dto.width,
    height: dto.height,
  );
}

@freezed
abstract class StickerSummary with _$StickerSummary {
  const factory StickerSummary({
    required String id,
    StickerMedia? media,
    String? emoji,
    String? name,
    String? description,
    DateTime? createdAt,
    bool? isFavorited,
  }) = _StickerSummary;

  factory StickerSummary.fromDto(StickerSummaryDto dto) => StickerSummary(
    id: dto.id ?? (throw StateError('StickerSummaryDto.id is required')),
    media: dto.media == null ? null : StickerMedia.fromDto(dto.media!),
    emoji: dto.emoji,
    name: dto.name,
    description: dto.description,
    createdAt: dto.createdAt,
    isFavorited: dto.isFavorited,
  );
}
