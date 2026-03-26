import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../models/message_models.dart';

/// Raw HTTP calls for message endpoints. No state.
class MessageService {
  Future<ListMessagesResponse> fetchMessages(
    String chatId, {
    int? max,
    int? before,
    int? after,
    int? around,
  }) async {
    final query = <String, String>{};
    if (max != null) query['max'] = max.toString();
    if (before != null) query['before'] = before.toString();
    if (after != null) query['after'] = after.toString();
    if (around != null) query['around'] = around.toString();
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

  /// Fetches messages around [messageId] for deep linking.
  Future<List<MessageItem>> fetchAround(String chatId, int messageId) async {
    final res = await fetchMessages(chatId, around: messageId);
    return res.messages;
  }

  Future<MessageItem> sendMessage(
    String chatId,
    String text, {
    int? replyToId,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/chats/$chatId/messages');
    final clientGeneratedId =
        '${DateTime.now().millisecondsSinceEpoch}-${Uri.base.hashCode}';
    final body = <String, dynamic>{
      'message': text,
      'message_type': 'text',
      'client_generated_id': clientGeneratedId,
    };
    if (replyToId != null) body['reply_to_id'] = replyToId;
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
    String newText,
  ) async {
    final uri = Uri.parse('$apiBaseUrl/chats/$chatId/messages/$messageId');
    final response = await http.patch(
      uri,
      headers: apiHeaders,
      body: jsonEncode({'message': newText}),
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

  Future<void> markAsRead(String chatId, int messageId) async {
    final uri = Uri.parse('$apiBaseUrl/chats/$chatId/read');
    final response = await http.post(
      uri,
      headers: apiHeaders,
      body: jsonEncode({'message_id': messageId}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to mark as read: ${response.statusCode} ${response.body}',
      );
    }
  }
}
