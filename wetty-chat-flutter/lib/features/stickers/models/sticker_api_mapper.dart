import '../../../core/api/models/stickers_api_models.dart';
import '../../chats/models/message_models.dart';
import 'sticker_models.dart';

extension StickerPackPreviewStickerDtoMapper on StickerPackPreviewStickerDto {
  StickerPackPreviewSticker toDomain() => StickerPackPreviewSticker(
    id: id,
    media: StickerMedia.fromDto(media),
    emoji: emoji,
  );
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
    stickers: stickers.map(StickerSummary.fromDto).toList(),
  );
}

extension StickerDetailResponseDtoMapper on StickerDetailResponseDto {
  StickerSummary toStickerSummary() => StickerSummary(
    id: id ?? (throw StateError('StickerDetailResponseDto.id is required')),
    media: media == null ? null : StickerMedia.fromDto(media!),
    emoji: emoji,
    name: name,
    description: description,
    createdAt: createdAt,
    isFavorited: isFavorited,
  );
}
