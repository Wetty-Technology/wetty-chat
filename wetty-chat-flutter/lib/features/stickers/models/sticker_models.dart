import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/stickers_api_models.dart';
import 'package:chahua/features/shared/model/message/message.dart';

part 'sticker_models.freezed.dart';

@freezed
abstract class StickerPackPreviewSticker with _$StickerPackPreviewSticker {
  const factory StickerPackPreviewSticker({
    required String id,
    required StickerMedia media,
    required String emoji,
  }) = _StickerPackPreviewSticker;

  factory StickerPackPreviewSticker.fromDto(StickerPackPreviewStickerDto dto) =>
      StickerPackPreviewSticker(
        id: dto.id,
        media: StickerMedia.fromDto(dto.media),
        emoji: dto.emoji,
      );
}

@freezed
abstract class StickerPackSummary with _$StickerPackSummary {
  const factory StickerPackSummary({
    required String id,
    required int ownerUid,
    String? ownerName,
    required String name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default(0) int stickerCount,
    @Default(false) bool isSubscribed,
    StickerPackPreviewSticker? previewSticker,
  }) = _StickerPackSummary;

  factory StickerPackSummary.fromDto(StickerPackSummaryDto dto) =>
      StickerPackSummary(
        id: dto.id,
        ownerUid: dto.ownerUid,
        ownerName: dto.ownerName,
        name: dto.name,
        description: dto.description,
        createdAt: dto.createdAt,
        updatedAt: dto.updatedAt,
        stickerCount: dto.stickerCount,
        isSubscribed: dto.isSubscribed,
        previewSticker: dto.previewSticker == null
            ? null
            : StickerPackPreviewSticker.fromDto(dto.previewSticker!),
      );
}

@freezed
abstract class StickerPackDetail with _$StickerPackDetail {
  const factory StickerPackDetail({
    required String id,
    required int ownerUid,
    String? ownerName,
    required String name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default(0) int stickerCount,
    @Default(false) bool isSubscribed,
    StickerPackPreviewSticker? previewSticker,
    @Default([]) List<StickerSummary> stickers,
  }) = _StickerPackDetail;

  factory StickerPackDetail.fromDto(StickerPackDetailResponseDto dto) =>
      StickerPackDetail(
        id: dto.id,
        ownerUid: dto.ownerUid,
        ownerName: dto.ownerName,
        name: dto.name,
        description: dto.description,
        createdAt: dto.createdAt,
        updatedAt: dto.updatedAt,
        stickerCount: dto.stickerCount,
        isSubscribed: dto.isSubscribed,
        previewSticker: dto.previewSticker == null
            ? null
            : StickerPackPreviewSticker.fromDto(dto.previewSticker!),
        stickers: dto.stickers.map(StickerSummary.fromDto).toList(),
      );
}
