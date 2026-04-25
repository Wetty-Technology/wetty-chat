import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models/messages_api_models.dart';
import '../../../core/api/models/websocket_api_models.dart';
import '../../../core/notifications/unread_badge_provider.dart';
import '../../../core/session/dev_session_store.dart';
import '../../chats/list_projection/domain/list_projection_helpers.dart';
import '../model/chat_list_item.dart';
import '../../chats/models/message_api_mapper.dart';
import '../../chats/shared/data/read_state_models.dart';

typedef GroupListV2StoreState = ({
  List<ChatListItem> groups,
  String? nextCursor,
  bool hasMore,
});

class GroupListV2Store extends Notifier<GroupListV2StoreState> {
  @override
  GroupListV2StoreState build() {
    return (groups: const [], nextCursor: null, hasMore: false);
  }

  void replacePage({required List<ChatListItem> groups, String? nextCursor}) {
    state = (
      groups: groups,
      nextCursor: nextCursor,
      hasMore: nextCursor != null && nextCursor.isNotEmpty,
    );
  }

  void appendPage({required List<ChatListItem> groups, String? nextCursor}) {
    final existingIds = state.groups.map((group) => group.id).toSet();
    final appended = groups
        .where((group) => !existingIds.contains(group.id))
        .toList(growable: false);

    state = (
      groups: [...state.groups, ...appended],
      nextCursor: nextCursor,
      hasMore: nextCursor != null && nextCursor.isNotEmpty,
    );
  }

  void updateGroupMetadata({
    required String chatId,
    required String name,
    DateTime? mutedUntil,
  }) {
    final index = state.groups.indexWhere((group) => group.id == chatId);
    if (index < 0) {
      return;
    }

    final groups = [...state.groups];
    groups[index] = groups[index].copyWith(name: name, mutedUntil: mutedUntil);
    state = (
      groups: groups,
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );
  }

  void updateGroupMutedUntil({
    required String chatId,
    required DateTime? mutedUntil,
  }) {
    final index = state.groups.indexWhere((group) => group.id == chatId);
    if (index < 0) {
      return;
    }

    final groups = [...state.groups];
    groups[index] = groups[index].copyWith(mutedUntil: mutedUntil);
    state = (
      groups: groups,
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );
  }

  void removeGroup(String chatId) {
    state = (
      groups: state.groups.where((group) => group.id != chatId).toList(),
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );
  }

  void applyServerReadState({
    required String chatId,
    int? messageId,
    required ChatReadStateUpdate response,
  }) {
    final index = state.groups.indexWhere((group) => group.id == chatId);
    if (index < 0) {
      return;
    }

    final previous = state.groups[index];
    final groups = [...state.groups];
    final updated = previous.copyWith(
      unreadCount: response.unreadCount,
      lastReadMessageId: response.lastReadMessageId ?? messageId?.toString(),
    );
    groups[index] = updated;
    state = (
      groups: groups,
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );
    _applyUnreadBadgeDelta(previous: previous, updated: updated);
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
    final chatId = payload.chatId.toString();
    final index = state.groups.indexWhere((group) => group.id == chatId);
    if (index < 0) {
      return true;
    }

    final message = payload.toDomain();
    if (!isEligibleChatPreviewMessage(message)) {
      return false;
    }

    final previous = state.groups[index];
    if (matchesChatPreview(previous.lastMessage, payload)) {
      return false;
    }

    final currentUserId = ref.read(authSessionProvider).currentUserId;
    final shouldIncrementUnread = payload.sender.uid != currentUserId;
    final updated = previous.copyWith(
      lastMessage: message,
      lastMessageAt: payload.createdAt,
      unreadCount: shouldIncrementUnread
          ? previous.unreadCount + 1
          : previous.unreadCount,
    );

    state = (
      groups: moveChatToFront(state.groups, index, updated),
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );
    _applyUnreadBadgeDelta(previous: previous, updated: updated);
    return false;
  }

  bool _applyRealtimePatched(MessageItemDto payload) {
    if (payload.replyRootId != null) {
      return false;
    }

    final chatId = payload.chatId.toString();
    final index = state.groups.indexWhere((group) => group.id == chatId);
    if (index < 0) {
      return false;
    }

    final previous = state.groups[index];
    if (!matchesChatPreview(previous.lastMessage, payload)) {
      return false;
    }

    if (payload.isDeleted) {
      return true;
    }

    state = (
      groups: replaceChatAt(
        state.groups,
        index,
        previous.copyWith(
          lastMessage: payload.toDomain(),
          lastMessageAt: payload.createdAt,
        ),
      ),
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );
    return false;
  }

  void _applyUnreadBadgeDelta({
    required ChatListItem previous,
    required ChatListItem updated,
  }) {
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
}

final groupListV2StoreProvider =
    NotifierProvider<GroupListV2Store, GroupListV2StoreState>(
      GroupListV2Store.new,
    );

final groupByIdProvider = Provider.family<ChatListItem?, String>((ref, chatId) {
  return ref.watch(
    groupListV2StoreProvider.select(
      (state) => state.groups.where((group) => group.id == chatId).firstOrNull,
    ),
  );
});
