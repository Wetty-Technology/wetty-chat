import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

class UploadUrlResponse {
  final String attachmentId;
  final String uploadUrl;
  final Map<String, String> uploadHeaders;

  const UploadUrlResponse({
    required this.attachmentId,
    required this.uploadUrl,
    required this.uploadHeaders,
  });

  factory UploadUrlResponse.fromJson(Map<String, dynamic> json) {
    final headers = json['upload_headers'] as Map<String, dynamic>? ?? {};
    return UploadUrlResponse(
      attachmentId: json['attachment_id']?.toString() ?? '',
      uploadUrl: json['upload_url'] as String? ?? '',
      uploadHeaders: headers.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }
}

class AttachmentService {
  Future<UploadUrlResponse> requestUploadUrl(
    File file, {
    String? contentType,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/attachments/upload-url');
    final stat = await file.stat();
    final response = await http.post(
      uri,
      headers: apiHeaders,
      body: jsonEncode({
        'filename': file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : 'attachment',
        'content_type': contentType ?? 'application/octet-stream',
        'size': stat.size,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to request upload URL: ${response.statusCode} ${response.body}',
      );
    }

    return UploadUrlResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> uploadFile(File file, UploadUrlResponse upload) async {
    final request = http.Request('PUT', Uri.parse(upload.uploadUrl));
    request.headers.addAll(upload.uploadHeaders);
    request.bodyBytes = await file.readAsBytes();
    final streamed = await request.send();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final body = await streamed.stream.bytesToString();
      throw Exception(
        'Failed to upload attachment: ${streamed.statusCode} $body',
      );
    }
  }
}
