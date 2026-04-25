import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/api/models/group_info_api_models.dart';
import 'package:chahua/features/chat_list/application/group_list_v2_store.dart';
import 'package:chahua/features/chat_list/model/chat_list_item.dart';
import 'package:chahua/features/groups/metadata/application/group_metadata_view_model.dart';
import 'package:chahua/features/groups/metadata/data/group_metadata_api_service.dart';
import 'package:chahua/features/groups/metadata/data/group_metadata_repository.dart';

void main() {
  test(
    'updateMetadata stores backend result and syncs chat list metadata',
    () async {
      final service = _FakeGroupMetadataApiService(
        const GroupInfoResponseDto(id: 42, name: 'Original Name'),
      );
      final container = ProviderContainer(
        overrides: [
          groupMetadataRepositoryProvider.overrideWithValue(
            GroupMetadataRepository(service),
          ),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(groupListV2StoreProvider.notifier)
          .replacePage(
            groups: const [ChatListItem(id: '42', name: 'Stale Name')],
          );

      final provider = groupMetadataViewModelProvider('42');
      final initial = await container.read(provider.future);
      expect(initial.name, 'Original Name');

      service.nextResponse = const GroupInfoResponseDto(
        id: 42,
        name: 'Updated Name',
      );

      final updated = await container
          .read(provider.notifier)
          .updateMetadata(name: 'Updated Name');

      expect(updated.name, 'Updated Name');
      expect(container.read(provider).value?.name, 'Updated Name');
      expect(
        container.read(groupListV2StoreProvider).groups.first.name,
        'Updated Name',
      );
    },
  );
}

class _FakeGroupMetadataApiService extends GroupMetadataApiService {
  _FakeGroupMetadataApiService(this.nextResponse) : super(Dio());

  GroupInfoResponseDto nextResponse;

  @override
  Future<GroupInfoResponseDto> fetchGroupMetadata(String chatId) async {
    return nextResponse;
  }

  @override
  Future<GroupInfoResponseDto> updateGroupMetadata(
    String chatId, {
    String? name,
    String? description,
    int? avatarImageId,
    String? visibility,
  }) async {
    return nextResponse;
  }
}
