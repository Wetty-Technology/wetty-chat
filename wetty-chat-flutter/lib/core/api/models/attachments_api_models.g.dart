// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachments_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UploadUrlRequestDto _$UploadUrlRequestDtoFromJson(Map<String, dynamic> json) =>
    UploadUrlRequestDto(
      filename: json['filename'] as String,
      contentType: json['contentType'] as String,
      size: (json['size'] as num).toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );

Map<String, dynamic> _$UploadUrlRequestDtoToJson(
  UploadUrlRequestDto instance,
) => <String, dynamic>{
  'filename': instance.filename,
  'contentType': instance.contentType,
  'size': instance.size,
  'width': instance.width,
  'height': instance.height,
};

UploadUrlResponseDto _$UploadUrlResponseDtoFromJson(
  Map<String, dynamic> json,
) => UploadUrlResponseDto(
  attachmentId: const StringValueConverter().fromJson(json['attachmentId']),
  uploadUrl: json['uploadUrl'] as String? ?? '',
  uploadHeaders: json['uploadHeaders'] == null
      ? {}
      : const StringMapConverter().fromJson(
          json['uploadHeaders'] as Map<String, dynamic>?,
        ),
);

Map<String, dynamic> _$UploadUrlResponseDtoToJson(
  UploadUrlResponseDto instance,
) => <String, dynamic>{
  'attachmentId': const StringValueConverter().toJson(instance.attachmentId),
  'uploadUrl': instance.uploadUrl,
  'uploadHeaders': const StringMapConverter().toJson(instance.uploadHeaders),
};
