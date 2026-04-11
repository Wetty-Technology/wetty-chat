// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stickers_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StickerPackPreviewStickerDto _$StickerPackPreviewStickerDtoFromJson(
  Map<String, dynamic> json,
) => StickerPackPreviewStickerDto(
  id: const StringValueConverter().fromJson(json['id']),
  media: StickerMediaDto.fromJson(json['media'] as Map<String, dynamic>),
  emoji: json['emoji'] as String,
);

Map<String, dynamic> _$StickerPackPreviewStickerDtoToJson(
  StickerPackPreviewStickerDto instance,
) => <String, dynamic>{
  'id': const StringValueConverter().toJson(instance.id),
  'media': instance.media.toJson(),
  'emoji': instance.emoji,
};

StickerPackSummaryDto _$StickerPackSummaryDtoFromJson(
  Map<String, dynamic> json,
) => StickerPackSummaryDto(
  id: const StringValueConverter().fromJson(json['id']),
  ownerUid: (json['ownerUid'] as num).toInt(),
  ownerName: json['ownerName'] as String?,
  name: json['name'] as String,
  description: json['description'] as String?,
  createdAt: const NullableDateTimeConverter().fromJson(json['createdAt']),
  updatedAt: const NullableDateTimeConverter().fromJson(json['updatedAt']),
  stickerCount: (json['stickerCount'] as num?)?.toInt() ?? 0,
  isSubscribed: json['isSubscribed'] as bool? ?? false,
  previewSticker: json['previewSticker'] == null
      ? null
      : StickerPackPreviewStickerDto.fromJson(
          json['previewSticker'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$StickerPackSummaryDtoToJson(
  StickerPackSummaryDto instance,
) => <String, dynamic>{
  'id': const StringValueConverter().toJson(instance.id),
  'ownerUid': instance.ownerUid,
  'ownerName': instance.ownerName,
  'name': instance.name,
  'description': instance.description,
  'createdAt': const NullableDateTimeConverter().toJson(instance.createdAt),
  'updatedAt': const NullableDateTimeConverter().toJson(instance.updatedAt),
  'stickerCount': instance.stickerCount,
  'isSubscribed': instance.isSubscribed,
  'previewSticker': instance.previewSticker?.toJson(),
};

StickerPackDetailResponseDto _$StickerPackDetailResponseDtoFromJson(
  Map<String, dynamic> json,
) => StickerPackDetailResponseDto(
  id: const StringValueConverter().fromJson(json['id']),
  ownerUid: (json['ownerUid'] as num).toInt(),
  ownerName: json['ownerName'] as String?,
  name: json['name'] as String,
  description: json['description'] as String?,
  createdAt: const NullableDateTimeConverter().fromJson(json['createdAt']),
  updatedAt: const NullableDateTimeConverter().fromJson(json['updatedAt']),
  stickerCount: (json['stickerCount'] as num?)?.toInt() ?? 0,
  isSubscribed: json['isSubscribed'] as bool? ?? false,
  previewSticker: json['previewSticker'] == null
      ? null
      : StickerPackPreviewStickerDto.fromJson(
          json['previewSticker'] as Map<String, dynamic>,
        ),
  stickers:
      (json['stickers'] as List<dynamic>?)
          ?.map((e) => StickerSummaryDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$StickerPackDetailResponseDtoToJson(
  StickerPackDetailResponseDto instance,
) => <String, dynamic>{
  'id': const StringValueConverter().toJson(instance.id),
  'ownerUid': instance.ownerUid,
  'ownerName': instance.ownerName,
  'name': instance.name,
  'description': instance.description,
  'createdAt': const NullableDateTimeConverter().toJson(instance.createdAt),
  'updatedAt': const NullableDateTimeConverter().toJson(instance.updatedAt),
  'stickerCount': instance.stickerCount,
  'isSubscribed': instance.isSubscribed,
  'previewSticker': instance.previewSticker?.toJson(),
  'stickers': instance.stickers.map((e) => e.toJson()).toList(),
};

StickerDetailResponseDto _$StickerDetailResponseDtoFromJson(
  Map<String, dynamic> json,
) => StickerDetailResponseDto(
  id: json['id'] as String?,
  media: json['media'] == null
      ? null
      : StickerMediaDto.fromJson(json['media'] as Map<String, dynamic>),
  emoji: json['emoji'] as String?,
  name: json['name'] as String?,
  description: json['description'] as String?,
  createdAt: const NullableDateTimeConverter().fromJson(json['createdAt']),
  isFavorited: json['isFavorited'] as bool?,
  packs:
      (json['packs'] as List<dynamic>?)
          ?.map(
            (e) => StickerPackSummaryDto.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      [],
);

Map<String, dynamic> _$StickerDetailResponseDtoToJson(
  StickerDetailResponseDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'media': instance.media?.toJson(),
  'emoji': instance.emoji,
  'name': instance.name,
  'description': instance.description,
  'createdAt': const NullableDateTimeConverter().toJson(instance.createdAt),
  'isFavorited': instance.isFavorited,
  'packs': instance.packs.map((e) => e.toJson()).toList(),
};

StickerPackListResponseDto _$StickerPackListResponseDtoFromJson(
  Map<String, dynamic> json,
) => StickerPackListResponseDto(
  packs:
      (json['packs'] as List<dynamic>?)
          ?.map(
            (e) => StickerPackSummaryDto.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      [],
);

Map<String, dynamic> _$StickerPackListResponseDtoToJson(
  StickerPackListResponseDto instance,
) => <String, dynamic>{'packs': instance.packs.map((e) => e.toJson()).toList()};

FavoriteStickerListResponseDto _$FavoriteStickerListResponseDtoFromJson(
  Map<String, dynamic> json,
) => FavoriteStickerListResponseDto(
  stickers:
      (json['stickers'] as List<dynamic>?)
          ?.map((e) => StickerSummaryDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$FavoriteStickerListResponseDtoToJson(
  FavoriteStickerListResponseDto instance,
) => <String, dynamic>{
  'stickers': instance.stickers.map((e) => e.toJson()).toList(),
};

CreateStickerPackRequestDto _$CreateStickerPackRequestDtoFromJson(
  Map<String, dynamic> json,
) => CreateStickerPackRequestDto(
  name: json['name'] as String,
  description: json['description'] as String?,
);

Map<String, dynamic> _$CreateStickerPackRequestDtoToJson(
  CreateStickerPackRequestDto instance,
) => <String, dynamic>{
  'name': instance.name,
  'description': ?instance.description,
};

UpdateStickerPackRequestDto _$UpdateStickerPackRequestDtoFromJson(
  Map<String, dynamic> json,
) => UpdateStickerPackRequestDto(
  name: json['name'] as String?,
  description: json['description'] as String?,
);

Map<String, dynamic> _$UpdateStickerPackRequestDtoToJson(
  UpdateStickerPackRequestDto instance,
) => <String, dynamic>{
  'name': ?instance.name,
  'description': ?instance.description,
};
