import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/api/client/api_json.dart';
import '../../../../core/api/models/attachments_api_models.dart';
import '../../../../core/network/api_config.dart';

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

  Future<UploadUrlResponse> requestUploadUrl({
    required String filename,
    required String contentType,
    required int size,
    int? width,
    int? height,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/attachments/upload-url');
    final payload = UploadUrlRequestDto(
      filename: filename,
      contentType: contentType,
      size: size,
      width: width,
      height: height,
    );

    final response = await http
        .post(uri, headers: apiHeaders, body: jsonEncode(payload.toJson()))
        .timeout(_requestTimeout);
    if (response.statusCode != 201) {
      throw Exception(
        'Failed to get upload URL: ${response.statusCode} ${response.body}',
      );
    }
    final dto = UploadUrlResponseDto.fromJson(decodeJsonObject(response.body));
    return UploadUrlResponse(
      attachmentId: dto.attachmentId,
      uploadUrl: dto.uploadUrl,
      uploadHeaders: dto.uploadHeaders,
    );
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
        }
      }

      if (lastError != null) {
        throw lastError;
      }
    }).timeout(_uploadTimeout);
  }

  Set<String> _extractSignedHeaders(Uri uri) {
    final raw =
        uri.queryParameters['X-Amz-SignedHeaders'] ??
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
    final candidates = <String?>['', 'max-age=0', 'no-cache', ''];
    final seen = <String?>{};
    return candidates.where((c) => seen.add(c)).toList();
  }

  bool _isSignatureMismatch(Object e) {
    final msg = e.toString();
    return msg.contains('SignatureDoesNotMatch') ||
        msg.contains('SignatureDoes');
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
        request.headers.set('cache-control', cacheControlValue ?? '');
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
          // Ignore host header if unsupported by the client.
        }
      }
      final bytes = await file.readAsBytes();
      request.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close().timeout(_uploadTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.transform(utf8.decoder).join();
        throw Exception('Failed to upload file: ${response.statusCode} $body');
      }
    } finally {
      httpClient.close(force: true);
    }
  }
}
