import 'dart:developer' show log;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models/messages_api_models.dart';
import '../../../core/api/models/websocket_api_models.dart';
import '../../../core/notifications/unread_badge_provider.dart';
import '../../../core/session/dev_session_store.dart';
import '../model/chat_list_item.dart';
import '../../shared/data/read_state_models.dart';
import 'chat_list_v2_scope.dart';
import 'realtime_projection_policy.dart';

typedef GroupListV2ListState = ({
  List<ChatListItem> groups,
  String? nextCursor,
  bool hasMore,
  bool isLoaded,
});

typedef GroupListV2StoreState = ({
  GroupListV2ListState active,
  GroupListV2ListState archived,
  bool hasArchivedGroups,
});

typedef _GroupLocation = ({ChatListV2Scope scope, int index});

class GroupListV2Store extends Notifier<GroupListV2StoreState> {
  @override
  GroupListV2StoreState build() {
    return (
      active: _emptyListState(),
      archived: _emptyListState(),
      hasArchivedGroups: false,
    );
  }

  void replaceActivePage({
    required List<ChatListItem> groups,
    String? nextCursor,
  }) {
    _replaceState(
      active: _listStateWithPage(
        groups.map((group) => group.copyWith(archived: false)).toList(),
        nextCursor,
      ),
    );
  }

  void replaceArchivedPage({
    required List<ChatListItem> groups,
    String? nextCursor,
  }) {
    _replaceState(
      archived: _listStateWithPage(
        groups.map((group) => group.copyWith(archived: true)).toList(),
        nextCursor,
      ),
      hasArchivedGroups: groups.isNotEmpty,
    );
  }

  void replaceHasArchivedGroups(bool hasArchivedGroups) {
    _replaceState(hasArchivedGroups: hasArchivedGroups);
  }

  void appendActivePage({
    required List<ChatListItem> groups,
    String? nextCursor,
  }) {
    _replaceState(
      active: _listStateWithAppendedPage(
        state.active,
        groups.map((group) => group.copyWith(archived: false)).toList(),
        nextCursor,
      ),
    );
  }

  void appendArchivedPage({
    required List<ChatListItem> groups,
    String? nextCursor,
  }) {
    _replaceState(
      archived: _listStateWithAppendedPage(
        state.archived,
        groups.map((group) => group.copyWith(archived: true)).toList(),
        nextCursor,
      ),
      hasArchivedGroups: state.hasArchivedGroups || groups.isNotEmpty,
    );
  }

  void archiveGroup(ChatListItem group) {
    final updated = group.copyWith(archived: true);
    final activeIndex = state.active.groups.indexWhere(
      (candidate) => candidate.id == group.id,
    );
    final previousActive = activeIndex < 0
        ? null
        : state.active.groups[activeIndex];
    final nextActive = _listStateWithoutGroup(state.active, group.id);
    final nextArchived = state.archived.isLoaded
        ? _listStateWithUpsertedGroup(state.archived, updated)
        : state.archived;

    _replaceState(
      active: nextActive,
      archived: nextArchived,
      hasArchivedGroups: true,
    );
    if (previousActive != null) {
      _applyUnreadBadgeDelta(
        previous: previousActive,
        updated: previousActive.copyWith(unreadCount: 0),
        scope: ChatListV2Scope.active,
      );
    }
  }

  void unarchiveGroup(ChatListItem group) {
    final updated = group.copyWith(archived: false);
    final nextArchived = _listStateWithoutGroup(state.archived, group.id);
    final nextActive = state.active.isLoaded
        ? _listStateWithUpsertedGroup(state.active, updated)
        : state.active;

    _replaceState(
      active: nextActive,
      archived: nextArchived,
      hasArchivedGroups: nextArchived.isLoaded
          ? nextArchived.groups.isNotEmpty
          : state.hasArchivedGroups,
    );
    _applyUnreadBadgeDelta(
      previous: updated.copyWith(unreadCount: 0),
      updated: updated,
      scope: ChatListV2Scope.active,
    );
  }

  void updateGroupMetadata({
    required String chatId,
    required String name,
    DateTime? mutedUntil,
  }) {
    _replaceGroupWhereFound(
      chatId,
      (group) => group.copyWith(name: name, mutedUntil: mutedUntil),
    );
  }

  void updateGroupMutedUntil({
    required String chatId,
    required DateTime? mutedUntil,
  }) {
    _replaceGroupWhereFound(
      chatId,
      (group) => group.copyWith(mutedUntil: mutedUntil),
    );
  }

  void removeGroup(String chatId) {
    final wasInActive = _containsGroup(state.active, chatId);
    final wasInArchived = _containsGroup(state.archived, chatId);
    if (wasInActive && wasInArchived) {
      log(
        'group existed in both active and archived lists before removal',
        name: 'wetty.chatList.groupStore',
        error: {'chatId': chatId},
      );
    }

    // Leaving a group invalidates membership globally. A group should only
    // exist in one bucket, but remove from both to repair stale projections.
    final nextActive = _listStateWithoutGroup(state.active, chatId);
    final nextArchived = _listStateWithoutGroup(state.archived, chatId);
    _replaceState(
      active: nextActive,
      archived: nextArchived,
      hasArchivedGroups: nextArchived.isLoaded
          ? nextArchived.groups.isNotEmpty
          : state.hasArchivedGroups,
    );
  }

  void applyServerReadState({
    required String chatId,
    int? messageId,
    required ChatReadStateUpdate response,
  }) {
    final location = _locationOfGroup(chatId);
    if (location == null) {
      return;
    }

    final listState = _listStateForScope(location.scope);
    final previous = listState.groups[location.index];
    final updated = previous.copyWith(
      unreadCount: response.unreadCount,
      lastReadMessageId: response.lastReadMessageId ?? messageId?.toString(),
    );
    _replaceListGroups(
      scope: location.scope,
      groups: _replaceChatAt(listState.groups, location.index, updated),
    );
    _applyUnreadBadgeDelta(
      previous: previous,
      updated: updated,
      scope: location.scope,
    );
  }

  bool applyRealtimeEvent(ApiWsEvent event) {
    switch (event) {
      case MessageCreatedWsEvent(:final payload):
        return _applyRealtimeCreated(payload);
      case MessageUpdatedWsEvent(:final payload):
        return _applyRealtimePatched(payload);
      case MessageDeletedWsEvent(:final payload):
        return _applyRealtimePatched(payload);
      default:
        return false;
    }
  }

  bool _applyRealtimeCreated(MessageItemDto payload) {
    if (!isEligibleChatPreviewPayload(payload)) {
      return false;
    }

    final chatId = payload.chatId.toString();
    final location = _locationOfGroup(chatId);
    if (location == null) {
      return true;
    }

    final listState = _listStateForScope(location.scope);
    final previous = listState.groups[location.index];
    final isCurrentUserMessage =
        payload.sender.uid == ref.read(authSessionProvider).currentUserId;
    if (matchesChatPreview(previous.lastMessage, payload)) {
      if (isCurrentUserMessage && previous.unreadCount > 0) {
        final updated = previous.copyWith(unreadCount: 0);
        _replaceListGroups(
          scope: location.scope,
          groups: _replaceChatAt(listState.groups, location.index, updated),
        );
        _applyUnreadBadgeDelta(
          previous: previous,
          updated: updated,
          scope: location.scope,
        );
      }
      return false;
    }

    final message = messagePreviewFromMessageItemDto(payload);
    final updated = previous.copyWith(
      lastMessage: message,
      lastMessageAt: payload.createdAt,
      unreadCount: isCurrentUserMessage ? 0 : previous.unreadCount + 1,
    );

    _replaceListGroups(
      scope: location.scope,
      groups: _moveChatToFront(listState.groups, location.index, updated),
    );
    _applyUnreadBadgeDelta(
      previous: previous,
      updated: updated,
      scope: location.scope,
    );
    return false;
  }

  bool _applyRealtimePatched(MessageItemDto payload) {
    if (payload.replyRootId != null) {
      return false;
    }

    final chatId = payload.chatId.toString();
    final location = _locationOfGroup(chatId);
    if (location == null) {
      return false;
    }

    final listState = _listStateForScope(location.scope);
    final previous = listState.groups[location.index];
    if (!matchesChatPreview(previous.lastMessage, payload)) {
      return false;
    }

    if (payload.isDeleted) {
      return true;
    }

    _replaceListGroups(
      scope: location.scope,
      groups: _replaceChatAt(
        listState.groups,
        location.index,
        previous.copyWith(
          lastMessage: messagePreviewFromMessageItemDto(payload),
          lastMessageAt: payload.createdAt,
        ),
      ),
    );
    return false;
  }

  _GroupLocation? _locationOfGroup(String chatId) {
    final activeIndex = state.active.groups.indexWhere(
      (group) => group.id == chatId,
    );
    if (activeIndex >= 0) {
      return (scope: ChatListV2Scope.active, index: activeIndex);
    }

    final archivedIndex = state.archived.groups.indexWhere(
      (group) => group.id == chatId,
    );
    if (archivedIndex >= 0) {
      return (scope: ChatListV2Scope.archived, index: archivedIndex);
    }

    return null;
  }

  void _replaceGroupWhereFound(
    String chatId,
    ChatListItem Function(ChatListItem group) update,
  ) {
    final activeIndex = state.active.groups.indexWhere(
      (group) => group.id == chatId,
    );
    final archivedIndex = state.archived.groups.indexWhere(
      (group) => group.id == chatId,
    );

    _replaceState(
      active: activeIndex < 0
          ? null
          : _listStateWithReplacedGroup(
              state.active,
              activeIndex,
              update(state.active.groups[activeIndex]),
            ),
      archived: archivedIndex < 0
          ? null
          : _listStateWithReplacedGroup(
              state.archived,
              archivedIndex,
              update(state.archived.groups[archivedIndex]),
            ),
    );
  }

  void _replaceListGroups({
    required ChatListV2Scope scope,
    required List<ChatListItem> groups,
  }) {
    final listState = _listStateForScope(scope);
    final updatedList = (
      groups: groups,
      nextCursor: listState.nextCursor,
      hasMore: listState.hasMore,
      isLoaded: listState.isLoaded,
    );
    switch (scope) {
      case ChatListV2Scope.active:
        _replaceState(active: updatedList);
      case ChatListV2Scope.archived:
        _replaceState(
          archived: updatedList,
          hasArchivedGroups: updatedList.isLoaded
              ? updatedList.groups.isNotEmpty
              : state.hasArchivedGroups,
        );
    }
  }

  GroupListV2ListState _listStateForScope(ChatListV2Scope scope) {
    return switch (scope) {
      ChatListV2Scope.active => state.active,
      ChatListV2Scope.archived => state.archived,
    };
  }

  List<ChatListItem> _replaceChatAt(
    List<ChatListItem> chats,
    int index,
    ChatListItem updated,
  ) {
    final next = [...chats];
    next[index] = updated;
    return next;
  }

  List<ChatListItem> _moveChatToFront(
    List<ChatListItem> chats,
    int index,
    ChatListItem updated,
  ) {
    final next = [...chats]..removeAt(index);
    next.insert(0, updated);
    return next;
  }

  void _applyUnreadBadgeDelta({
    required ChatListItem previous,
    required ChatListItem updated,
    required ChatListV2Scope scope,
  }) {
    if (scope == ChatListV2Scope.archived) {
      return;
    }

    final previousContribution = chatBadgeContribution(
      unreadCount: previous.unreadCount,
      mutedUntil: previous.mutedUntil,
    );
    final nextContribution = chatBadgeContribution(
      unreadCount: updated.unreadCount,
      mutedUntil: updated.mutedUntil,
    );
    ref
        .read(unreadBadgeProvider.notifier)
        .applyChatUnreadDelta(nextContribution - previousContribution);
  }

  void _replaceState({
    GroupListV2ListState? active,
    GroupListV2ListState? archived,
    bool? hasArchivedGroups,
  }) {
    state = (
      active: active ?? state.active,
      archived: archived ?? state.archived,
      hasArchivedGroups: hasArchivedGroups ?? state.hasArchivedGroups,
    );
  }
}

GroupListV2ListState _emptyListState() {
  return (
    groups: const <ChatListItem>[],
    nextCursor: null,
    hasMore: false,
    isLoaded: false,
  );
}

GroupListV2ListState _listStateWithPage(
  List<ChatListItem> groups,
  String? nextCursor,
) {
  return (
    groups: groups,
    nextCursor: nextCursor,
    hasMore: nextCursor != null && nextCursor.isNotEmpty,
    isLoaded: true,
  );
}

GroupListV2ListState _listStateWithAppendedPage(
  GroupListV2ListState listState,
  List<ChatListItem> groups,
  String? nextCursor,
) {
  final existingIds = listState.groups.map((group) => group.id).toSet();
  final appended = groups
      .where((group) => !existingIds.contains(group.id))
      .toList(growable: false);

  return (
    groups: [...listState.groups, ...appended],
    nextCursor: nextCursor,
    hasMore: nextCursor != null && nextCursor.isNotEmpty,
    isLoaded: true,
  );
}

GroupListV2ListState _listStateWithoutGroup(
  GroupListV2ListState listState,
  String chatId,
) {
  return (
    groups: listState.groups
        .where((group) => group.id != chatId)
        .toList(growable: false),
    nextCursor: listState.nextCursor,
    hasMore: listState.hasMore,
    isLoaded: listState.isLoaded,
  );
}

GroupListV2ListState _listStateWithReplacedGroup(
  GroupListV2ListState listState,
  int index,
  ChatListItem updated,
) {
  final groups = [...listState.groups];
  groups[index] = updated;
  return (
    groups: groups,
    nextCursor: listState.nextCursor,
    hasMore: listState.hasMore,
    isLoaded: listState.isLoaded,
  );
}

GroupListV2ListState _listStateWithUpsertedGroup(
  GroupListV2ListState listState,
  ChatListItem group,
) {
  final existingIndex = listState.groups.indexWhere(
    (candidate) => candidate.id == group.id,
  );
  if (existingIndex >= 0) {
    return _listStateWithReplacedGroup(listState, existingIndex, group);
  }

  final insertAt = listState.groups.indexWhere((candidate) {
    final groupActivity = group.lastMessageAt;
    final candidateActivity = candidate.lastMessageAt;
    if (groupActivity == null) {
      return false;
    }
    if (candidateActivity == null) {
      return true;
    }
    return groupActivity.isAfter(candidateActivity);
  });
  final groups = [...listState.groups];
  if (insertAt < 0) {
    groups.add(group);
  } else {
    groups.insert(insertAt, group);
  }

  return (
    groups: groups,
    nextCursor: listState.nextCursor,
    hasMore: listState.hasMore,
    isLoaded: listState.isLoaded,
  );
}

bool _containsGroup(GroupListV2ListState listState, String chatId) {
  return listState.groups.any((group) => group.id == chatId);
}

final groupListV2StoreProvider =
    NotifierProvider<GroupListV2Store, GroupListV2StoreState>(
      GroupListV2Store.new,
    );

final groupByIdProvider = Provider.family<ChatListItem?, String>((ref, chatId) {
  return ref.watch(
    groupListV2StoreProvider.select((state) {
      ChatListItem? findIn(List<ChatListItem> groups) {
        return groups.where((group) => group.id == chatId).firstOrNull;
      }

      return findIn(state.active.groups) ?? findIn(state.archived.groups);
    }),
  );
});
