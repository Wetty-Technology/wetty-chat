import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/core/api/models/thread_api_models.dart';
import 'package:chahua/core/network/dio_client.dart';

/// Raw HTTP calls for thread endpoints. No state.
class ThreadApiService {
  final Dio _dio;

  ThreadApiService(this._dio);

  Future<ListThreadsResponseDto> fetchThreads({
    int? limit,
    String? before,
  }) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = limit.toString();
    if (before != null && before.isNotEmpty) query['before'] = before;
    final response = await _dio.get<Map<String, dynamic>>(
      '/threads',
      queryParameters: query.isEmpty ? null : query,
    );
    return ListThreadsResponseDto.fromJson(response.data!);
  }

  Future<UnreadThreadCountResponseDto> fetchUnreadThreadCount() async {
    final response = await _dio.get<Map<String, dynamic>>('/threads/unread');
    return UnreadThreadCountResponseDto.fromJson(response.data!);
  }

  Future<MarkThreadReadResponseDto> markThreadAsRead(
    int threadRootId,
    int messageId,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/threads/$threadRootId/read',
      data: {'messageId': messageId.toString()},
    );
    return MarkThreadReadResponseDto.fromJson(response.data!);
  }

  /// PUT /chats/{chatId}/threads/{threadRootId}/subscribe — returns 204
  Future<void> subscribeToThread(String chatId, int threadRootId) async {
    await _dio.put<void>('/chats/$chatId/threads/$threadRootId/subscribe');
  }

  /// DELETE /chats/{chatId}/threads/{threadRootId}/subscribe — returns 204
  Future<void> unsubscribeFromThread(String chatId, int threadRootId) async {
    await _dio.delete<void>('/chats/$chatId/threads/$threadRootId/subscribe');
  }

  /// GET /chats/{chatId}/threads/{threadRootId}/subscribe — returns { subscribed: bool }
  Future<bool> getThreadSubscriptionStatus(
    String chatId,
    int threadRootId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/chats/$chatId/threads/$threadRootId/subscribe',
    );
    return response.data!['subscribed'] as bool? ?? false;
  }
}

final threadApiServiceProvider = Provider<ThreadApiService>((ref) {
  return ThreadApiService(ref.watch(dioProvider));
});
