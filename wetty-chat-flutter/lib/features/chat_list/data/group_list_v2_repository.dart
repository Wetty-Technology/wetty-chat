import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/core/api/services/chat_api_service.dart';

import '../application/chat_list_v2_scope.dart';
import '../application/group_list_v2_store.dart';
import '../model/chat_list_item.dart';

class GroupListV2Repository {
  GroupListV2Repository(this.ref);

  final Ref ref;

  Future<void> loadGroups({int limit = 20}) {
    return loadGroupsForScope(scope: ChatListV2Scope.active, limit: limit);
  }

  Future<void> loadArchivedGroups({int limit = 20}) {
    return loadGroupsForScope(scope: ChatListV2Scope.archived, limit: limit);
  }

  Future<void> loadGroupsForScope({
    required ChatListV2Scope scope,
    int limit = 20,
  }) async {
    final response = await ref
        .read(chatApiServiceProvider)
        .fetchChats(limit: limit, archived: scope == ChatListV2Scope.archived);
    final groups = response.chats
        .map(ChatListItem.fromDto)
        .toList(growable: false);
    final store = ref.read(groupListV2StoreProvider.notifier);
    switch (scope) {
      case ChatListV2Scope.active:
        store.replaceActivePage(
          groups: groups,
          nextCursor: response.nextCursor,
        );
      case ChatListV2Scope.archived:
        store.replaceArchivedPage(
          groups: groups,
          nextCursor: response.nextCursor,
        );
    }
  }

  Future<void> probeArchivedGroups() async {
    final response = await ref
        .read(chatApiServiceProvider)
        .fetchChats(limit: 1, archived: true);
    ref
        .read(groupListV2StoreProvider.notifier)
        .replaceHasArchivedGroups(response.chats.isNotEmpty);
  }

  Future<void> loadMoreGroups({int limit = 20}) async {
    return loadMoreGroupsForScope(scope: ChatListV2Scope.active, limit: limit);
  }

  Future<void> loadMoreArchivedGroups({int limit = 20}) {
    return loadMoreGroupsForScope(
      scope: ChatListV2Scope.archived,
      limit: limit,
    );
  }

  Future<void> loadMoreGroupsForScope({
    required ChatListV2Scope scope,
    int limit = 20,
  }) async {
    final current = switch (scope) {
      ChatListV2Scope.active => ref.read(groupListV2StoreProvider).active,
      ChatListV2Scope.archived => ref.read(groupListV2StoreProvider).archived,
    };
    if (!current.hasMore || current.nextCursor == null) {
      return;
    }

    final response = await ref
        .read(chatApiServiceProvider)
        .fetchChats(
          limit: limit,
          after: current.nextCursor,
          archived: scope == ChatListV2Scope.archived,
        );
    final groups = response.chats
        .map(ChatListItem.fromDto)
        .toList(growable: false);
    final store = ref.read(groupListV2StoreProvider.notifier);
    switch (scope) {
      case ChatListV2Scope.active:
        store.appendActivePage(groups: groups, nextCursor: response.nextCursor);
      case ChatListV2Scope.archived:
        store.appendArchivedPage(
          groups: groups,
          nextCursor: response.nextCursor,
        );
    }
  }

  Future<void> archiveGroup(ChatListItem group) async {
    await ref.read(chatApiServiceProvider).archiveChat(group.id);
    ref.read(groupListV2StoreProvider.notifier).archiveGroup(group);
  }

  Future<void> unarchiveGroup(ChatListItem group) async {
    await ref.read(chatApiServiceProvider).unarchiveChat(group.id);
    ref.read(groupListV2StoreProvider.notifier).unarchiveGroup(group);
  }
}

final groupListV2RepositoryProvider = Provider<GroupListV2Repository>((ref) {
  return GroupListV2Repository(ref);
});
