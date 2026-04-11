import '../../../core/api/models/stickers_api_models.dart';
import '../../chats/models/message_api_mapper.dart';
import '../../chats/models/message_models.dart';
import 'sticker_models.dart';

extension StickerPackPreviewStickerDtoMapper on StickerPackPreviewStickerDto {
  StickerPackPreviewSticker toDomain() =>
      StickerPackPreviewSticker(id: id, media: media.toDomain(), emoji: emoji);
}

extension StickerPackSummaryDtoMapper on StickerPackSummaryDto {
  StickerPackSummary toDomain() => StickerPackSummary(
    id: id,
    ownerUid: ownerUid,
    ownerName: ownerName,
    name: name,
    description: description,
    createdAt: createdAt,
    updatedAt: updatedAt,
    stickerCount: stickerCount,
    isSubscribed: isSubscribed,
    previewSticker: previewSticker?.toDomain(),
  );
}

extension StickerPackDetailResponseDtoMapper on StickerPackDetailResponseDto {
  StickerPackDetail toDomain() => StickerPackDetail(
    id: id,
    ownerUid: ownerUid,
    ownerName: ownerName,
    name: name,
    description: description,
    createdAt: createdAt,
    updatedAt: updatedAt,
    stickerCount: stickerCount,
    isSubscribed: isSubscribed,
    previewSticker: previewSticker?.toDomain(),
    stickers: stickers.map((s) => s.toDomain()).toList(),
  );
}

extension StickerDetailResponseDtoMapper on StickerDetailResponseDto {
  StickerSummary toStickerSummary() => StickerSummary(
    id: id,
    media: media?.toDomain(),
    emoji: emoji,
    name: name,
    description: description,
    createdAt: createdAt,
    isFavorited: isFavorited,
  );
}
