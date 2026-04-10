import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/chats_api_models.dart';
import '../../../../core/network/dio_client.dart';


/// Raw HTTP calls for chat endpoints. No state.
class ChatApiService {
  final Dio _dio;

  ChatApiService(this._dio);

  Future<ListChatsResponseDto> fetchChats({int? limit, String? after}) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = limit.toString();
    if (after != null && after.isNotEmpty) query['after'] = after;
    final response = await _dio.get<Map<String, dynamic>>(
      '/chats',
      queryParameters: query.isEmpty ? null : query,
    );
    return ListChatsResponseDto.fromJson(response.data!);
  }

  Future<CreateChatResponseDto> createChat({String? name}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/group',
      data: CreateChatRequestDto(name: name).toJson(),
    );
    return CreateChatResponseDto.fromJson(response.data!);
  }

  Future<UnreadCountResponseDto> fetchUnreadCount() async {
    final response = await _dio.get<Map<String, dynamic>>('/chats/unread');
    return UnreadCountResponseDto.fromJson(response.data!);
  }

  Future<MarkChatReadStateResponseDto> markChatAsUnread(String chatId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chats/$chatId/unread',
      data: 'null',
    );
    return MarkChatReadStateResponseDto.fromJson(response.data!);
  }
}

final chatApiServiceProvider = Provider<ChatApiService>((ref) {
  return ChatApiService(ref.watch(dioProvider));
});
