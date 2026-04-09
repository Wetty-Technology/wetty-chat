import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/api/models/attachments_api_models.dart';

class UploadUrlResponse {
  final String attachmentId;
  final String uploadUrl;
  final Map<String, String> uploadHeaders;

  const UploadUrlResponse({
    required this.attachmentId,
    required this.uploadUrl,
    this.uploadHeaders = const {},
  });
}

class AttachmentService {
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _uploadTimeout = Duration(seconds: 120);

  final Dio _dio;

  AttachmentService(this._dio);

  Future<UploadUrlResponse> requestUploadUrl({
    required String filename,
    required String contentType,
    required int size,
    int? width,
    int? height,
  }) async {
    final payload = UploadUrlRequestDto(
      filename: filename,
      contentType: contentType,
      size: size,
      width: width,
      height: height,
    );

    final response = await _dio.post<Map<String, dynamic>>(
      '/attachments/upload-url',
      data: payload.toJson(),
      options: Options(sendTimeout: _requestTimeout),
    );
    final dto = UploadUrlResponseDto.fromJson(response.data!);
    return UploadUrlResponse(
      attachmentId: dto.attachmentId,
      uploadUrl: dto.uploadUrl,
      uploadHeaders: dto.uploadHeaders,
    );
  }

  /// Uploads a file directly to S3 using the pre-signed URL.
  ///
  /// Uses a separate [Dio] instance without auth interceptors since
  /// the upload target is an external S3 endpoint with its own headers.
  Future<void> uploadFileToS3({
    required String uploadUrl,
    required PlatformFile file,
    required Map<String, String> uploadHeaders,
    void Function(double progress)? onProgress,
  }) async {
    final s3Dio = Dio(
      BaseOptions(sendTimeout: _uploadTimeout, receiveTimeout: _uploadTimeout),
    );
    try {
      final stream =
          file.readStream ??
          (file.path != null
              ? File(file.path!).openRead()
              : file.xFile.openRead());
      await s3Dio.put<void>(
        uploadUrl,
        data: stream,
        onSendProgress: (sent, total) {
          if (onProgress == null || total <= 0) {
            return;
          }
          final value = (sent / total).clamp(0, 1).toDouble();
          onProgress(value);
        },
        options: Options(
          headers: {...uploadHeaders, Headers.contentLengthHeader: file.size},
        ),
      );
    } finally {
      s3Dio.close();
    }
  }
}
