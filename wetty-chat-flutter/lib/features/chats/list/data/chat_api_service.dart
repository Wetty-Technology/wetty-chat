import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/api/client/api_json.dart';
import '../../../../core/api/models/chats_api_models.dart';
import '../../../../core/network/api_config.dart';

/// Raw HTTP calls for chat endpoints. No state.
class ChatApiService {
  Future<ListChatsResponseDto> fetchChats({int? limit, String? after}) async {
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
    return ListChatsResponseDto.fromJson(decodeJsonObject(response.body));
  }

  Future<CreateChatResponseDto> createChat({String? name}) async {
    final url = Uri.parse('$apiBaseUrl/group');
    final response = await http.post(
      url,
      headers: apiHeaders,
      body: jsonEncode(CreateChatRequestDto(name: name).toJson()),
    );
    if (response.statusCode != 201) {
      throw Exception(
        'Failed to create chat: ${response.statusCode} ${response.body}',
      );
    }
    return CreateChatResponseDto.fromJson(decodeJsonObject(response.body));
  }

  Future<UnreadCountResponseDto> fetchUnreadCount() async {
    final uri = Uri.parse('$apiBaseUrl/chats/unread');
    final response = await http.get(uri, headers: apiHeaders);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load unread count: ${response.statusCode} ${response.body}',
      );
    }

    return UnreadCountResponseDto.fromJson(decodeJsonObject(response.body));
  }
}
