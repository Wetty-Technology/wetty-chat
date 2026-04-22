import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/websocket_api_models.dart';
import '../../../../core/api/models/messages_api_models.dart';
import '../../../../core/notifications/unread_badge_provider.dart';
import '../../../../core/session/dev_session_store.dart';
import '../../list_projection/domain/list_projection_helpers.dart';
import '../../models/chat_api_mapper.dart';
import '../../models/chat_models.dart';
import '../../models/message_api_mapper.dart';
import '../../conversation_v2/data/message_api_service_v2.dart';
import 'chat_api_service.dart';

typedef ChatListState = ({
  List<ChatListItem> chats,
  String? nextCursor,
  bool hasMore,
});

/// Source of truth for chat list data.
/// Manages pagination, caching, and realtime events.
class ChatListNotifier extends Notifier<ChatListState> {
  bool _isRealtimeRefreshing = false;

  @override
  ChatListState build() {
    return (chats: const [], nextCursor: null, hasMore: false);
  }

  ChatApiService get _service => ref.read(chatApiServiceProvider);

  /// Load the first page of chats.
  Future<void> loadChats({int limit = 20}) async {
    final res = await _service.fetchChats(limit: limit);
    final chats = res.chats.map((chat) => chat.toDomain()).toList();
    state = (
      chats: chats,
      nextCursor: res.nextCursor,
      hasMore: res.nextCursor != null && res.nextCursor!.isNotEmpty,
    );
  }

  /// Load more chats (next page).
  Future<void> loadMoreChats({int limit = 20}) async {
    if (!state.hasMore || state.chats.isEmpty) return;
    final lastId = state.chats.last.id;
    final res = await _service.fetchChats(limit: limit, after: lastId);
    final existingIds = state.chats.map((c) => c.id).toSet();
    final newChats = res.chats
        .map((chat) => chat.toDomain())
        .where((c) => !existingIds.contains(c.id))
        .toList();
    state = (
      chats: [...state.chats, ...newChats],
      nextCursor: res.nextCursor,
      hasMore: res.nextCursor != null && res.nextCursor!.isNotEmpty,
    );
  }

  /// Insert a newly created chat at the top.
  void insertChat(ChatListItem chat) {
    state = (
      chats: [chat, ...state.chats],
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );
  }

  /// Create a new chat via the service.
  Future<ChatListItem?> createChat({String? name}) async {
    final response = await _service.createChat(name: name);
    return ChatListItem(id: response.id.toString(), name: response.name);
  }

  void updateChatMetadata({
    required String chatId,
    required String name,
    DateTime? mutedUntil,
  }) {
    final index = state.chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) {
      return;
    }

    final previous = state.chats[index];
    final updated = state.chats[index].copyWith(
      name: name,
      mutedUntil: mutedUntil,
    );
    final chats = [...state.chats];
    chats[index] = updated;
    state = (
      chats: chats,
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );
    _applyBadgeDelta(
      previousUnreadCount: previous.unreadCount,
      previousMutedUntil: previous.mutedUntil,
      nextUnreadCount: updated.unreadCount,
      nextMutedUntil: updated.mutedUntil,
    );
  }

  void removeChat(String chatId) {
    final existing = state.chats.where((chat) => chat.id == chatId).firstOrNull;
    final chats = state.chats.where((c) => c.id != chatId).toList();
    state = (
      chats: chats,
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );
    if (existing != null) {
      _applyBadgeDelta(
        previousUnreadCount: existing.unreadCount,
        previousMutedUntil: existing.mutedUntil,
        nextUnreadCount: 0,
      );
    }
  }

  void updateChatMutedUntil({
    required String chatId,
    required DateTime? mutedUntil,
  }) {
    final index = state.chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) return;
    final previous = state.chats[index];
    final chats = [...state.chats];
    final updated = state.chats[index].copyWith(mutedUntil: mutedUntil);
    chats[index] = updated;
    state = (
      chats: chats,
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );
    _applyBadgeDelta(
      previousUnreadCount: previous.unreadCount,
      previousMutedUntil: previous.mutedUntil,
      nextUnreadCount: updated.unreadCount,
      nextMutedUntil: updated.mutedUntil,
    );
  }

  void markChatRead({required String chatId, required int messageId}) {
    final index = state.chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) {
      return;
    }

    final current = state.chats[index];
    final lastMessageId = current.lastMessage?.id;
    final nextUnreadCount = lastMessageId != null && messageId >= lastMessageId
        ? 0
        : current.unreadCount;
    final chats = [...state.chats];
    chats[index] = current.copyWith(
      unreadCount: nextUnreadCount,
      lastReadMessageId: messageId.toString(),
    );
    state = (
      chats: chats,
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );
    _applyBadgeDelta(
      previousUnreadCount: current.unreadCount,
      previousMutedUntil: current.mutedUntil,
      nextUnreadCount: nextUnreadCount,
      nextMutedUntil: current.mutedUntil,
    );
  }

  Future<void> markChatReadViaSwipe({required String chatId}) async {
    final index = state.chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) return;

    final current = state.chats[index];
    final lastMessageId = current.lastMessage?.id;
    if (lastMessageId == null) return;

    final originalUnreadCount = current.unreadCount;
    final originalLastReadMessageId = current.lastReadMessageId;

    // Optimistic update.
    final chats = [...state.chats];
    chats[index] = current.copyWith(
      unreadCount: 0,
      lastReadMessageId: lastMessageId.toString(),
    );
    state = (
      chats: chats,
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );
    _applyBadgeDelta(
      previousUnreadCount: originalUnreadCount,
      previousMutedUntil: current.mutedUntil,
      nextUnreadCount: 0,
      nextMutedUntil: current.mutedUntil,
    );

    try {
      await ref
          .read(messageApiServiceV2Provider)
          .markMessagesAsRead(chatId, lastMessageId);
      ref.read(unreadBadgeProvider.notifier).scheduleReconcile();
    } catch (e) {
      debugPrint('markChatReadViaSwipe failed: $e');
      // Revert on failure.
      final revertIndex = state.chats.indexWhere((chat) => chat.id == chatId);
      if (revertIndex >= 0) {
        final revertChats = [...state.chats];
        revertChats[revertIndex] = state.chats[revertIndex].copyWith(
          unreadCount: originalUnreadCount,
          lastReadMessageId: originalLastReadMessageId,
        );
        state = (
          chats: revertChats,
          nextCursor: state.nextCursor,
          hasMore: state.hasMore,
        );
        _applyBadgeDelta(
          previousUnreadCount: 0,
          previousMutedUntil: current.mutedUntil,
          nextUnreadCount: originalUnreadCount,
          nextMutedUntil: current.mutedUntil,
        );
      }
    }
  }

  Future<void> markChatUnread({required String chatId}) async {
    final index = state.chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) return;

    final current = state.chats[index];
    final originalUnreadCount = current.unreadCount;
    final originalLastReadMessageId = current.lastReadMessageId;

    // Optimistic update.
    final chats = [...state.chats];
    chats[index] = current.copyWith(unreadCount: 1);
    state = (
      chats: chats,
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );
    _applyBadgeDelta(
      previousUnreadCount: originalUnreadCount,
      previousMutedUntil: current.mutedUntil,
      nextUnreadCount: 1,
      nextMutedUntil: current.mutedUntil,
    );

    try {
      final response = await ref
          .read(chatApiServiceProvider)
          .markChatAsUnread(chatId);
      // Update from server response.
      final successIndex = state.chats.indexWhere((chat) => chat.id == chatId);
      if (successIndex >= 0) {
        final successChats = [...state.chats];
        final updated = state.chats[successIndex].copyWith(
          unreadCount: response.unreadCount,
          lastReadMessageId: response.lastReadMessageId,
        );
        successChats[successIndex] = updated;
        state = (
          chats: successChats,
          nextCursor: state.nextCursor,
          hasMore: state.hasMore,
        );
        _applyBadgeDelta(
          previousUnreadCount: 1,
          previousMutedUntil: current.mutedUntil,
          nextUnreadCount: updated.unreadCount,
          nextMutedUntil: current.mutedUntil,
        );
      }
      ref.read(unreadBadgeProvider.notifier).scheduleReconcile();
    } catch (e) {
      debugPrint('markChatUnread failed: $e');
      // Revert on failure.
      final revertIndex = state.chats.indexWhere((chat) => chat.id == chatId);
      if (revertIndex >= 0) {
        final revertChats = [...state.chats];
        revertChats[revertIndex] = state.chats[revertIndex].copyWith(
          unreadCount: originalUnreadCount,
          lastReadMessageId: originalLastReadMessageId,
        );
        state = (
          chats: revertChats,
          nextCursor: state.nextCursor,
          hasMore: state.hasMore,
        );
        _applyBadgeDelta(
          previousUnreadCount: 1,
          previousMutedUntil: current.mutedUntil,
          nextUnreadCount: originalUnreadCount,
          nextMutedUntil: current.mutedUntil,
        );
      }
    }
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
    final chats = state.chats;
    final index = chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) {
      unawaited(_refreshForRealtimeMiss());
      return;
    }

    final previous = chats[index];
    final message = payload.toDomain();
    if (!isEligibleChatPreviewMessage(message)) {
      return;
    }
    if (matchesChatPreview(previous.lastMessage, payload)) {
      return;
    }

    final senderUid = payload.sender.uid;
    final currentUserId = ref.read(authSessionProvider).currentUserId;
    final updated = previous.copyWith(
      lastMessage: message,
      lastMessageAt: payload.createdAt,
      unreadCount: senderUid != currentUserId
          ? previous.unreadCount + 1
          : previous.unreadCount,
    );
    state = (
      chats: moveChatToFront(chats, index, updated),
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
    );
    if (senderUid != currentUserId) {
      _applyBadgeDelta(
        previousUnreadCount: previous.unreadCount,
        previousMutedUntil: previous.mutedUntil,
        nextUnreadCount: updated.unreadCount,
        nextMutedUntil: updated.mutedUntil,
      );
    }
  }

  void _applyRealtimePatched(MessageItemDto payload) {
    if (payload.replyRootId != null) {
      return;
    }

    final chatId = payload.chatId.toString();
    final chats = state.chats;
    final index = chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) {
      return;
    }

    final previous = chats[index];
    if (!matchesChatPreview(previous.lastMessage, payload)) {
      return;
    }
    if (payload.isDeleted) {
      unawaited(_refreshForRealtimeMiss());
      return;
    }

    state = (
      chats: replaceChatAt(
        chats,
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

  Future<void> _refreshForRealtimeMiss() async {
    if (_isRealtimeRefreshing) return;

    _isRealtimeRefreshing = true;
    try {
      final limit = state.chats.isEmpty ? 11 : state.chats.length;
      await loadChats(limit: limit);
    } catch (_) {
      // Ignore realtime refresh failures and rely on the next manual refresh.
    } finally {
      _isRealtimeRefreshing = false;
    }
  }

  void _applyBadgeDelta({
    required int previousUnreadCount,
    DateTime? previousMutedUntil,
    required int nextUnreadCount,
    DateTime? nextMutedUntil,
  }) {
    final previousContribution = chatBadgeContribution(
      unreadCount: previousUnreadCount,
      mutedUntil: previousMutedUntil,
    );
    final nextContribution = chatBadgeContribution(
      unreadCount: nextUnreadCount,
      mutedUntil: nextMutedUntil,
    );
    ref
        .read(unreadBadgeProvider.notifier)
        .applyChatUnreadDelta(nextContribution - previousContribution);
  }
}

final chatListStateProvider = NotifierProvider<ChatListNotifier, ChatListState>(
  ChatListNotifier.new,
);
