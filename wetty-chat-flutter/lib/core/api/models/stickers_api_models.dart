import 'package:json_annotation/json_annotation.dart';

import '../converters/nullable_date_time_converter.dart';
import '../converters/string_value_converter.dart';
import 'messages_api_models.dart';

part 'stickers_api_models.g.dart';

@JsonSerializable(explicitToJson: true)
class StickerPackPreviewStickerDto {
  const StickerPackPreviewStickerDto({
    required this.id,
    required this.media,
    required this.emoji,
  });

  @StringValueConverter()
  final String id;
  final StickerMediaDto media;
  final String emoji;

  factory StickerPackPreviewStickerDto.fromJson(Map<String, dynamic> json) =>
      _$StickerPackPreviewStickerDtoFromJson(json);

  Map<String, dynamic> toJson() => _$StickerPackPreviewStickerDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class StickerPackSummaryDto {
  const StickerPackSummaryDto({
    required this.id,
    required this.ownerUid,
    this.ownerName,
    required this.name,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.stickerCount = 0,
    this.isSubscribed = false,
    this.previewSticker,
  });

  @StringValueConverter()
  final String id;
  final int ownerUid;
  final String? ownerName;
  final String name;
  final String? description;
  @NullableDateTimeConverter()
  final DateTime? createdAt;
  @NullableDateTimeConverter()
  final DateTime? updatedAt;
  @JsonKey(defaultValue: 0)
  final int stickerCount;
  @JsonKey(defaultValue: false)
  final bool isSubscribed;
  final StickerPackPreviewStickerDto? previewSticker;

  factory StickerPackSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$StickerPackSummaryDtoFromJson(json);

  Map<String, dynamic> toJson() => _$StickerPackSummaryDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class StickerPackDetailResponseDto {
  const StickerPackDetailResponseDto({
    required this.id,
    required this.ownerUid,
    this.ownerName,
    required this.name,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.stickerCount = 0,
    this.isSubscribed = false,
    this.previewSticker,
    this.stickers = const [],
  });

  @StringValueConverter()
  final String id;
  final int ownerUid;
  final String? ownerName;
  final String name;
  final String? description;
  @NullableDateTimeConverter()
  final DateTime? createdAt;
  @NullableDateTimeConverter()
  final DateTime? updatedAt;
  @JsonKey(defaultValue: 0)
  final int stickerCount;
  @JsonKey(defaultValue: false)
  final bool isSubscribed;
  final StickerPackPreviewStickerDto? previewSticker;
  @JsonKey(defaultValue: <StickerSummaryDto>[])
  final List<StickerSummaryDto> stickers;

  factory StickerPackDetailResponseDto.fromJson(Map<String, dynamic> json) =>
      _$StickerPackDetailResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$StickerPackDetailResponseDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class StickerDetailResponseDto {
  const StickerDetailResponseDto({
    this.id,
    this.media,
    this.emoji,
    this.name,
    this.description,
    this.createdAt,
    this.isFavorited,
    this.packs = const [],
  });

  final String? id;
  final StickerMediaDto? media;
  final String? emoji;
  final String? name;
  final String? description;
  @NullableDateTimeConverter()
  final DateTime? createdAt;
  final bool? isFavorited;
  @JsonKey(defaultValue: <StickerPackSummaryDto>[])
  final List<StickerPackSummaryDto> packs;

  factory StickerDetailResponseDto.fromJson(Map<String, dynamic> json) =>
      _$StickerDetailResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$StickerDetailResponseDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class StickerPackListResponseDto {
  const StickerPackListResponseDto({this.packs = const []});

  @JsonKey(defaultValue: <StickerPackSummaryDto>[])
  final List<StickerPackSummaryDto> packs;

  factory StickerPackListResponseDto.fromJson(Map<String, dynamic> json) =>
      _$StickerPackListResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$StickerPackListResponseDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class FavoriteStickerListResponseDto {
  const FavoriteStickerListResponseDto({this.stickers = const []});

  @JsonKey(defaultValue: <StickerSummaryDto>[])
  final List<StickerSummaryDto> stickers;

  factory FavoriteStickerListResponseDto.fromJson(Map<String, dynamic> json) =>
      _$FavoriteStickerListResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$FavoriteStickerListResponseDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class CreateStickerPackRequestDto {
  const CreateStickerPackRequestDto({required this.name, this.description});

  final String name;
  @JsonKey(includeIfNull: false)
  final String? description;

  factory CreateStickerPackRequestDto.fromJson(Map<String, dynamic> json) =>
      _$CreateStickerPackRequestDtoFromJson(json);

  Map<String, dynamic> toJson() => _$CreateStickerPackRequestDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class UpdateStickerPackRequestDto {
  const UpdateStickerPackRequestDto({this.name, this.description});

  @JsonKey(includeIfNull: false)
  final String? name;
  @JsonKey(includeIfNull: false)
  final String? description;

  factory UpdateStickerPackRequestDto.fromJson(Map<String, dynamic> json) =>
      _$UpdateStickerPackRequestDtoFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateStickerPackRequestDtoToJson(this);
}
