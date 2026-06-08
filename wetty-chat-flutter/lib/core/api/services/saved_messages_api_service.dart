import 'package:chahua/core/api/models/saved_messages_api_models.dart';
import 'package:chahua/core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SavedMessagesApiService {
  const SavedMessagesApiService(this._dio);

  final Dio _dio;

  Future<ListSavedMessagesResponseDto> listSavedMessages({
    int limit = 25,
    int? before,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/saved-messages',
      queryParameters: _listQuery(limit: limit, before: before),
    );
    return ListSavedMessagesResponseDto.fromJson(response.data!);
  }

  Future<ListSavedMessagesResponseDto> listChatSavedMessages(
    int chatId, {
    int limit = 25,
    int? before,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/chats/$chatId/saved-messages',
      queryParameters: _listQuery(limit: limit, before: before),
    );
    return ListSavedMessagesResponseDto.fromJson(response.data!);
  }

  Future<SavedMessageResponseDto> saveMessage(int messageId) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/saved-messages/$messageId',
    );
    return SavedMessageResponseDto.fromJson(response.data!);
  }

  Future<void> deleteSavedMessage(int savedMessageId) async {
    await _dio.delete<void>('/saved-messages/by-id/$savedMessageId');
  }

  Map<String, Object> _listQuery({required int limit, int? before}) {
    final query = <String, Object>{'limit': limit};
    if (before != null) {
      query['before'] = before;
    }
    return query;
  }
}

final savedMessagesApiServiceProvider = Provider<SavedMessagesApiService>((
  ref,
) {
  return SavedMessagesApiService(ref.watch(dioProvider));
});
