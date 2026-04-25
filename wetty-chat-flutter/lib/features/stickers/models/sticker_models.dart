import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/features/shared/model/message/message.dart';

part 'sticker_models.freezed.dart';

@freezed
abstract class StickerPackPreviewSticker with _$StickerPackPreviewSticker {
  const factory StickerPackPreviewSticker({
    required String id,
    required StickerMedia media,
    required String emoji,
  }) = _StickerPackPreviewSticker;
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
}
