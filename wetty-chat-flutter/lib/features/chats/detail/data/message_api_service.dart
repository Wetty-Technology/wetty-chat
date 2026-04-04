import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/api/client/api_json.dart';
import '../../../../core/api/models/chats_api_models.dart';
import '../../../../core/api/models/messages_api_models.dart';
import '../../../../core/network/api_config.dart';

class MessageApiService {
  Future<ListMessagesResponseDto> fetchMessages(
    String chatId, {
    int? max,
    int? before,
    int? after,
    int? around,
    String? threadId,
  }) async {
    final query = <String, String>{};
    if (max != null) query['max'] = max.toString();
    if (before != null) query['before'] = before.toString();
    if (after != null) query['after'] = after.toString();
    if (around != null) query['around'] = around.toString();
    if (threadId != null && threadId.isNotEmpty) {
      query['threadId'] = threadId;
    }

    final uri = Uri.parse(
      '$apiBaseUrl/chats/$chatId/messages',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: apiHeaders);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load messages: ${response.statusCode} ${response.body}',
      );
    }

    return ListMessagesResponseDto.fromJson(decodeJsonObject(response.body));
  }

  Future<List<MessageItemDto>> fetchAround(String chatId, int messageId) async {
    final response = await fetchMessages(chatId, around: messageId);
    return response.messages;
  }

  Future<MessageItemDto> sendMessage(
    String chatId,
    String text, {
    int? replyToId,
    String? threadId,
    List<String> attachmentIds = const <String>[],
  }) async {
    final path = threadId == null
        ? '$apiBaseUrl/chats/$chatId/messages'
        : '$apiBaseUrl/chats/$chatId/threads/$threadId/messages';
    final uri = Uri.parse(path);
    final clientGeneratedId =
        '${DateTime.now().millisecondsSinceEpoch}-${Uri.base.hashCode}';
    final body = SendMessageRequestDto(
      message: text,
      messageType: 'text',
      clientGeneratedId: clientGeneratedId,
      attachmentIds: attachmentIds,
      replyToId: replyToId,
    );

    final response = await http.post(
      uri,
      headers: apiHeaders,
      body: jsonEncode(body.toJson()),
    );
    if (response.statusCode != 201) {
      throw Exception(
        'Failed to send message: ${response.statusCode} ${response.body}',
      );
    }

    return MessageItemDto.fromJson(decodeJsonObject(response.body));
  }

  Future<MessageItemDto> editMessage(
    String chatId,
    int messageId,
    String newText, {
    List<String> attachmentIds = const <String>[],
  }) async {
    final uri = Uri.parse('$apiBaseUrl/chats/$chatId/messages/$messageId');
    final response = await http.patch(
      uri,
      headers: apiHeaders,
      body: jsonEncode(
        EditMessageRequestDto(
          message: newText,
          attachmentIds: attachmentIds,
        ).toJson(),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to edit message: ${response.statusCode} ${response.body}',
      );
    }

    return MessageItemDto.fromJson(decodeJsonObject(response.body));
  }

  Future<void> deleteMessage(String chatId, int messageId) async {
    final uri = Uri.parse('$apiBaseUrl/chats/$chatId/messages/$messageId');
    final response = await http.delete(uri, headers: apiHeaders);
    if (response.statusCode != 204) {
      throw Exception(
        'Failed to delete message: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<MarkChatReadStateResponseDto> markMessagesAsRead(
    String chatId,
    int messageId,
  ) async {
    final uri = Uri.parse('$apiBaseUrl/chats/$chatId/read');
    final response = await http.post(
      uri,
      headers: apiHeaders,
      body: jsonEncode(MarkReadRequestDto(messageId: messageId).toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to mark as read: ${response.statusCode} ${response.body}',
      );
    }
    return MarkChatReadStateResponseDto.fromJson(
      decodeJsonObject(response.body),
    );
  }
}
