import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'group_metadata_api_mapper.dart';
import 'group_metadata_api_service.dart';
import 'group_metadata_models.dart';

class GroupMetadataRepository {
  GroupMetadataRepository(this._apiService);

  final GroupMetadataApiService _apiService;

  Future<ChatMetadata> fetchMetadata(String chatId) async {
    final response = await _apiService.fetchGroupMetadata(chatId);
    return response.toDomain();
  }

  Future<ChatMetadata> updateMetadata(
    String chatId, {
    String? name,
    String? description,
    int? avatarImageId,
    String? visibility,
  }) async {
    final response = await _apiService.updateGroupMetadata(
      chatId,
      name: name,
      description: description,
      avatarImageId: avatarImageId,
      visibility: visibility,
    );
    return response.toDomain();
  }

  Future<DateTime> muteChat(String chatId, {int? durationSeconds}) {
    return _apiService.muteChat(chatId, durationSeconds: durationSeconds);
  }

  Future<void> unmuteChat(String chatId) {
    return _apiService.unmuteChat(chatId);
  }
}

final groupMetadataRepositoryProvider = Provider<GroupMetadataRepository>((
  ref,
) {
  return GroupMetadataRepository(ref.watch(groupMetadataApiServiceProvider));
});
