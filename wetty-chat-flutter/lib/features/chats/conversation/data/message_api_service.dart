import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/chats_api_models.dart';
import '../../../../core/api/models/messages_api_models.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/session/dev_session_store.dart';
import '../domain/conversation_scope.dart';

class MessageApiService {
  final Dio _dio;
  final int _currentUserId;

  MessageApiService(this._dio, this._currentUserId);

  String nextClientGeneratedId({String? seed}) {
    return '${DateTime.now().microsecondsSinceEpoch}-$seed-$_currentUserId';
  }

  /// Send path: threads use a dedicated POST endpoint.
  String _sendPath(ConversationScope scope) {
    if (scope.threadRootId == null) {
      return '/chats/${scope.chatId}/messages';
    }
    return '/chats/${scope.chatId}/threads/${scope.threadRootId}/messages';
  }

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

    final response = await _dio.get<Map<String, dynamic>>(
      '/chats/$chatId/messages',
      queryParameters: query.isEmpty ? null : query,
    );
    return ListMessagesResponseDto.fromJson(response.data!);
  }

  Future<List<MessageItemDto>> fetchAround(String chatId, int messageId) async {
    final response = await fetchMessages(chatId, around: messageId);
    return response.messages;
  }

  /// Fetch path: threads use the same GET endpoint with a `threadId` query param.
  Future<ListMessagesResponseDto> fetchConversationMessages(
    ConversationScope scope, {
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
    if (scope.threadRootId != null) {
      query['threadId'] = scope.threadRootId!;
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '/chats/${scope.chatId}/messages',
      queryParameters: query.isEmpty ? null : query,
    );
    return ListMessagesResponseDto.fromJson(response.data!);
  }

  Future<MessageItemDto> sendMessage(
    String chatId,
    String text, {
    String messageType = 'text',
    int? replyToId,
    String? threadId,
    List<String> attachmentIds = const <String>[],
    String? clientGeneratedId,
  }) async {
    final path = threadId == null
        ? '/chats/$chatId/messages'
        : '/chats/$chatId/threads/$threadId/messages';
    final body = SendMessageRequestDto(
      message: text,
      messageType: messageType,
      clientGeneratedId: clientGeneratedId ?? nextClientGeneratedId(),
      attachmentIds: attachmentIds,
      replyToId: replyToId,
    );

    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: body.toJson(),
    );
    return MessageItemDto.fromJson(response.data!);
  }

  Future<MessageItemDto> sendConversationMessage(
    ConversationScope scope,
    String text, {
    required String messageType,
    int? replyToId,
    List<String> attachmentIds = const <String>[],
    required String clientGeneratedId,
  }) async {
    final body = SendMessageRequestDto(
      message: text,
      messageType: messageType,
      clientGeneratedId: clientGeneratedId,
      attachmentIds: attachmentIds,
      replyToId: replyToId,
    );
    final response = await _dio.post<Map<String, dynamic>>(
      _sendPath(scope),
      data: body.toJson(),
    );
    return MessageItemDto.fromJson(response.data!);
  }

  Future<MessageItemDto> editMessage(
    String chatId,
    int messageId,
    String newText, {
    List<String> attachmentIds = const <String>[],
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/chats/$chatId/messages/$messageId',
      data: EditMessageRequestDto(
        message: newText,
        attachmentIds: attachmentIds,
      ).toJson(),
    );
    return MessageItemDto.fromJson(response.data!);
  }

  Future<void> deleteMessage(String chatId, int messageId) async {
    await _dio.delete<void>('/chats/$chatId/messages/$messageId');
  }

  Future<void> putReaction(
    ConversationScope scope,
    int messageId,
    String emoji,
  ) async {
    await _dio.put<void>(
      '/chats/${scope.chatId}/messages/$messageId/reactions/${Uri.encodeComponent(emoji)}',
    );
  }

  Future<void> deleteReaction(
    ConversationScope scope,
    int messageId,
    String emoji,
  ) async {
    await _dio.delete<void>(
      '/chats/${scope.chatId}/messages/$messageId/reactions/${Uri.encodeComponent(emoji)}',
    );
  }

  Future<MarkChatReadStateResponseDto> markMessagesAsRead(
    String chatId,
    int messageId,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chats/$chatId/read',
      data: MarkReadRequestDto(messageId: messageId).toJson(),
    );
    return MarkChatReadStateResponseDto.fromJson(response.data!);
  }
}

final messageApiServiceProvider = Provider<MessageApiService>((ref) {
  final session = ref.watch(authSessionProvider);
  return MessageApiService(ref.watch(dioProvider), session.currentUserId);
});
