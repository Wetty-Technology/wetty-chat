import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/group_info_api_models.dart';
import '../../../../core/network/dio_client.dart';

class GroupMetadataApiService {
  GroupMetadataApiService(this._dio);

  final Dio _dio;

  Future<GroupInfoResponseDto> fetchGroupMetadata(String chatId) async {
    final response = await _dio.get<Map<String, dynamic>>('/group/$chatId');
    return GroupInfoResponseDto.fromJson(response.data!);
  }

  Future<GroupInfoResponseDto> updateGroupMetadata(
    String chatId, {
    String? name,
    String? description,
    int? avatarImageId,
    String? visibility,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/group/$chatId',
      data: UpdateGroupRequestDto(
        name: name,
        description: description,
        avatarImageId: avatarImageId,
        visibility: visibility,
      ).toJson(),
    );
    return GroupInfoResponseDto.fromJson(response.data!);
  }

  /// PUT /group/:chatId/mute
  /// Body: { "duration_seconds": int? } (null/omitted = forever)
  /// Returns the server-assigned muted_until timestamp.
  Future<DateTime> muteChat(String chatId, {int? durationSeconds}) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/group/$chatId/mute',
      data: MuteChatRequestDto(durationSeconds: durationSeconds).toJson(),
    );
    final raw = response.data!['mutedUntil'] as String;
    return DateTime.parse(raw);
  }

  /// DELETE /group/:chatId/mute
  Future<void> unmuteChat(String chatId) async {
    await _dio.delete<void>('/group/$chatId/mute');
  }
}

final groupMetadataApiServiceProvider = Provider<GroupMetadataApiService>((
  ref,
) {
  return GroupMetadataApiService(ref.watch(dioProvider));
});
