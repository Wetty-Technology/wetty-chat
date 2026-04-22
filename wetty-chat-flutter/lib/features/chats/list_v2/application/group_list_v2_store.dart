import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/messages_api_models.dart';
import '../../../../core/api/models/websocket_api_models.dart';
import '../../../../core/session/dev_session_store.dart';
import '../../list_projection/domain/list_projection_helpers.dart';
import '../../models/chat_models.dart';
import '../../models/message_api_mapper.dart';

typedef GroupListV2StoreState = ({
  List<ChatListItem> groups,
  String? nextCursor,
  bool hasMore,
});

class GroupListV2Store extends Notifier<GroupListV2StoreState> {
  bool _isRealtimeRefreshing = false;

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

  void applyRealtimeEvent(ApiWsEvent event) {
    switch (event) {
      case MessageCreatedWsEvent(:final payload):
        _applyRealtimeCreated(payload);
        return;
      case MessageUpdatedWsEvent(:final payload):
        _applyRealtimePatched(payload);
        return;
      case MessageDeletedWsEvent(:final payload):
        _applyRealtimePatched(payload);
        return;
      default:
        return;
    }
  }

  void _applyRealtimeCreated(MessageItemDto payload) {
    final chatId = payload.chatId.toString();
    final index = state.groups.indexWhere((group) => group.id == chatId);
    if (index < 0) {
      _refreshForRealtimeMiss();
      return;
    }

    final message = payload.toDomain();
    if (!isEligibleChatPreviewMessage(message)) {
      return;
    }

    final previous = state.groups[index];
    if (matchesChatPreview(previous.lastMessage, payload)) {
      return;
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
  }

  void _applyRealtimePatched(MessageItemDto payload) {
    if (payload.replyRootId != null) {
      return;
    }

    final chatId = payload.chatId.toString();
    final index = state.groups.indexWhere((group) => group.id == chatId);
    if (index < 0) {
      return;
    }

    final previous = state.groups[index];
    if (!matchesChatPreview(previous.lastMessage, payload)) {
      return;
    }

    if (payload.isDeleted) {
      _refreshForRealtimeMiss();
      return;
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
  }

  void _refreshForRealtimeMiss() {
    if (_isRealtimeRefreshing) {
      return;
    }

    _isRealtimeRefreshing = true;
    Future<void>.microtask(() {
      // TODO(codex): Reconcile the v2 groups list from the backend when a
      // realtime event references a group or preview slice we do not have
      // enough local state to update precisely.
      _isRealtimeRefreshing = false;
    });
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
