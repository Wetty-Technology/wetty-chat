import 'package:json_annotation/json_annotation.dart';

import '../converters/string_map_converter.dart';
import '../converters/string_value_converter.dart';

part 'attachments_api_models.g.dart';

@JsonSerializable(explicitToJson: true)
class UploadUrlRequestDto {
  const UploadUrlRequestDto({
    required this.filename,
    required this.contentType,
    required this.size,
    this.width,
    this.height,
  });

  final String filename;
  final String contentType;
  final int size;
  final int? width;
  final int? height;

  factory UploadUrlRequestDto.fromJson(Map<String, dynamic> json) =>
      _$UploadUrlRequestDtoFromJson(json);

  Map<String, dynamic> toJson() => _$UploadUrlRequestDtoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class UploadUrlResponseDto {
  const UploadUrlResponseDto({
    required this.attachmentId,
    this.uploadUrl = '',
    this.uploadHeaders = const {},
  });

  @StringValueConverter()
  final String attachmentId;
  @JsonKey(defaultValue: '')
  final String uploadUrl;
  @StringMapConverter()
  @JsonKey(defaultValue: <String, String>{})
  final Map<String, String> uploadHeaders;

  factory UploadUrlResponseDto.fromJson(Map<String, dynamic> json) =>
      _$UploadUrlResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$UploadUrlResponseDtoToJson(this);
}
