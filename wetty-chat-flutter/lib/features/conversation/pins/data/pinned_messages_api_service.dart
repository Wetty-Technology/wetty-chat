import 'package:chahua/core/api/models/pins_api_models.dart';
import 'package:chahua/core/network/dio_client.dart';
import 'package:chahua/features/conversation/pins/domain/pinned_message.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

extension PinResponseDtoMapper on PinResponseDto {
  PinnedMessage toDomain() {
    return PinnedMessage(
      id: id,
      chatId: chatId,
      message: ConversationMessageV2.fromMessageItemDto(message),
      pinnedBy: pinnedBy,
      pinnedAt: pinnedAt,
      expiresAt: expiresAt,
    );
  }
}

class PinnedMessagesApiService {
  const PinnedMessagesApiService(this._dio);

  final Dio _dio;

  Future<List<PinnedMessage>> listPins(int chatId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/chats/$chatId/pins',
    );
    final pinsJson = response.data!['pins'] as List<dynamic>? ?? const [];
    return pinsJson
        .map((item) => PinResponseDto.fromJson(item as Map<String, dynamic>))
        .map((dto) => dto.toDomain())
        .toList(growable: false);
  }

  Future<PinnedMessage> pinMessage({
    required int chatId,
    required int messageId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chats/$chatId/pins',
      data: <String, String>{'messageId': messageId.toString()},
    );
    return PinResponseDto.fromJson(response.data!).toDomain();
  }

  Future<void> unpinMessage({required int chatId, required int pinId}) async {
    await _dio.delete<void>('/chats/$chatId/pins/$pinId');
  }
}

final pinnedMessagesApiServiceProvider = Provider<PinnedMessagesApiService>((
  ref,
) {
  return PinnedMessagesApiService(ref.watch(dioProvider));
});
