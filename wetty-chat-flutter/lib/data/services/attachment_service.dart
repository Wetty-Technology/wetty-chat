import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

class UploadUrlResponse {
  final String attachmentId;
  final String uploadUrl;

  UploadUrlResponse({required this.attachmentId, required this.uploadUrl});

  factory UploadUrlResponse.fromJson(Map<String, dynamic> json) {
    return UploadUrlResponse(
      attachmentId: json['attachment_id']?.toString() ?? '',
      uploadUrl: json['upload_url'] as String? ?? '',
    );
  }
}

class AttachmentService {
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _uploadTimeout = Duration(seconds: 120);

  Future<UploadUrlResponse> requestUploadUrl({
    required String filename,
    required String contentType,
    required int size,
    int? width,
    int? height,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/attachments/upload-url');
    final body = <String, dynamic>{
      'filename': filename,
      'content_type': contentType,
      'size': size,
    };
    if (width != null) body['width'] = width;
    if (height != null) body['height'] = height;

    final response = await http
        .post(
          uri,
          headers: apiHeaders,
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
    if (response.statusCode != 201) {
      throw Exception(
        'Failed to get upload URL: ${response.statusCode} ${response.body}',
      );
    }
    final parsed = UploadUrlResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    return parsed;
  }

  Future<void> uploadFileToS3({
    required String uploadUrl,
    required File file,
    required String contentType,
  }) async {
    await Future<void>(() async {
      final uri = Uri.parse(uploadUrl);
      final signedHeaders = _extractSignedHeaders(uri);

      final cacheControlCandidates = _cacheControlCandidates(signedHeaders);
      Exception? lastError;

      for (final candidate in cacheControlCandidates) {
        try {
          await _uploadOnce(
            uri: uri,
            file: file,
            contentType: contentType,
            signedHeaders: signedHeaders,
            cacheControlValue: candidate,
          );
          return;
        } catch (e) {
          final err = Exception(e.toString());
          lastError = err;
          if (!_isSignatureMismatch(e)) {
            rethrow;
          }
          // retry with next candidate
        }
      }

      if (lastError != null) {
        throw lastError;
      }
    }).timeout(_uploadTimeout);
  }

  Set<String> _extractSignedHeaders(Uri uri) {
    final raw = uri.queryParameters['X-Amz-SignedHeaders'] ??
        uri.queryParameters['x-amz-signedheaders'] ??
        '';
    return raw
        .split(';')
        .map((h) => h.trim().toLowerCase())
        .where((h) => h.isNotEmpty)
        .toSet();
  }

  String? _queryValue(Uri uri, String key) {
    for (final entry in uri.queryParameters.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  List<String?> _cacheControlCandidates(Set<String> signedHeaders) {
    if (!signedHeaders.contains('cache-control')) return [null];
    final candidates = <String?>[];
    candidates.add('');
    candidates.add('max-age=0');
    candidates.add('no-cache');
    candidates.add('');
    // de-dup while preserving order
    final seen = <String?>{};
    return candidates.where((c) => seen.add(c)).toList();
  }

  bool _isSignatureMismatch(Object e) {
    final msg = e.toString();
    return msg.contains('SignatureDoesNotMatch') || msg.contains('SignatureDoes');
  }

  Future<void> _uploadOnce({
    required Uri uri,
    required File file,
    required String contentType,
    required Set<String> signedHeaders,
    required String? cacheControlValue,
  }) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.openUrl('PUT', uri);
      request.followRedirects = false;
      request.maxRedirects = 0;
      if (signedHeaders.contains('content-type')) {
        request.headers.set(HttpHeaders.contentTypeHeader, contentType);
      }
      if (signedHeaders.contains('cache-control')) {
        final configured = cacheControlValue ?? '';
        request.headers.set('cache-control', configured);
      }
      if (signedHeaders.contains('x-amz-acl')) {
        request.headers.set('x-amz-acl', 'public-read');
      }
      if (signedHeaders.contains('x-amz-content-sha256')) {
        request.headers.set(
          'x-amz-content-sha256',
          _queryValue(uri, 'X-Amz-Content-Sha256') ?? 'UNSIGNED-PAYLOAD',
        );
      }
      if (signedHeaders.contains('x-amz-security-token')) {
        final token = _queryValue(uri, 'X-Amz-Security-Token');
        if (token != null && token.isNotEmpty) {
          request.headers.set('x-amz-security-token', token);
        }
      }
      if (signedHeaders.contains('x-amz-date')) {
        final date = _queryValue(uri, 'X-Amz-Date');
        if (date != null && date.isNotEmpty) {
          request.headers.set('x-amz-date', date);
        }
      }
      if (signedHeaders.contains('host')) {
        try {
          request.headers.set(HttpHeaders.hostHeader, uri.host);
        } catch (_) {
          // ignore host header if not supported by client
        }
      }
      final bytes = await file.readAsBytes();
      request.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close().timeout(_uploadTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.transform(utf8.decoder).join();
        throw Exception(
          'Failed to upload file: ${response.statusCode} $body',
        );
      }
    } finally {
      httpClient.close(force: true);
    }
  }

}
