import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chats/shared/data/chat_api_service.dart';
import '../../chats/models/chat_api_mapper.dart';
import '../application/group_list_v2_store.dart';

class GroupListV2Repository {
  GroupListV2Repository(this.ref);

  final Ref ref;

  Future<void> loadGroups({int limit = 20}) async {
    final response = await ref
        .read(chatApiServiceProvider)
        .fetchChats(limit: limit);
    final groups = response.chats
        .map((chat) => chat.toDomain())
        .toList(growable: false);
    ref
        .read(groupListV2StoreProvider.notifier)
        .replacePage(groups: groups, nextCursor: response.nextCursor);
  }

  Future<void> loadMoreGroups({int limit = 20}) async {
    final current = ref.read(groupListV2StoreProvider);
    if (!current.hasMore || current.groups.isEmpty) {
      return;
    }

    final response = await ref
        .read(chatApiServiceProvider)
        .fetchChats(limit: limit, after: current.groups.last.id);
    final groups = response.chats
        .map((chat) => chat.toDomain())
        .toList(growable: false);
    ref
        .read(groupListV2StoreProvider.notifier)
        .appendPage(groups: groups, nextCursor: response.nextCursor);
  }
}

final groupListV2RepositoryProvider = Provider<GroupListV2Repository>((ref) {
  return GroupListV2Repository(ref);
});
