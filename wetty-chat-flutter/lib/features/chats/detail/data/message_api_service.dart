import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/network/api_config.dart';
import '../../models/message_models.dart';

class MessageApiService {
  Future<ListMessagesResponse> fetchMessages(
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

    return ListMessagesResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<MessageItem>> fetchAround(String chatId, int messageId) async {
    final response = await fetchMessages(chatId, around: messageId);
    return response.messages;
  }

  Future<MessageItem> sendMessage(
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
    final body = <String, dynamic>{
      'message': text,
      'messageType': 'text',
      'clientGeneratedId': clientGeneratedId,
      'attachmentIds': attachmentIds,
    };
    if (replyToId != null) {
      body['replyToId'] = replyToId;
    }

    final response = await http.post(
      uri,
      headers: apiHeaders,
      body: jsonEncode(body),
    );
    if (response.statusCode != 201) {
      throw Exception(
        'Failed to send message: ${response.statusCode} ${response.body}',
      );
    }

    return MessageItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<MessageItem> editMessage(
    String chatId,
    int messageId,
    String newText, {
    List<String> attachmentIds = const <String>[],
  }) async {
    final uri = Uri.parse('$apiBaseUrl/chats/$chatId/messages/$messageId');
    final response = await http.patch(
      uri,
      headers: apiHeaders,
      body: jsonEncode(<String, dynamic>{
        'message': newText,
        'attachmentIds': attachmentIds,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to edit message: ${response.statusCode} ${response.body}',
      );
    }

    return MessageItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
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

  Future<void> markMessagesAsRead(String chatId, int messageId) async {
    final uri = Uri.parse('$apiBaseUrl/chats/$chatId/read');
    final response = await http.post(
      uri,
      headers: apiHeaders,
      body: jsonEncode({'messageId': messageId}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to mark as read: ${response.statusCode} ${response.body}',
      );
    }
  }
}
