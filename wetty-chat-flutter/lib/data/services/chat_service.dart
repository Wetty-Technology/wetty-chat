import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../models/chat_models.dart';

/// Raw HTTP calls for chat endpoints. No state.
class ChatService {
  Future<ListChatsResponse> fetchChats({int? limit, String? after}) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = limit.toString();
    if (after != null && after.isNotEmpty) query['after'] = after;
    final uri = Uri.parse(
      '$apiBaseUrl/chats',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: apiHeaders);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load chats: ${response.statusCode} ${response.body}',
      );
    }
    return ListChatsResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<http.Response> createChat({String? name}) async {
    final url = Uri.parse('$apiBaseUrl/group');
    return http.post(
      url,
      headers: apiHeaders,
      body: jsonEncode({"name": name}),
    );
  }
}
