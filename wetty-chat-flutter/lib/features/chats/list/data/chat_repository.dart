import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/websocket_api_models.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/notifications/unread_badge_provider.dart';
import '../../../../core/session/dev_session_store.dart';
import '../../models/chat_api_mapper.dart';
import '../../models/chat_models.dart';
import '../../models/message_api_mapper.dart';
import '../../models/message_models.dart';
import '../../conversation/data/message_api_service.dart';
import '../../conversation/domain/conversation_message.dart';
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
    // Subscribe to WebSocket events for realtime updates.
    ref.listen<AsyncValue<ApiWsEvent>>(wsEventsProvider, (_, next) {
      final event = next.value;
      if (event != null) _applyRealtimeEvent(event);
    });
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

  void recordOutgoingMessage(ConversationMessage message) {
    final index = state.chats.indexWhere(
      (chat) => chat.id == message.scope.chatId,
    );
    if (index < 0) {
      return;
    }

    final previous = state.chats[index];
    final updated = previous.copyWith(
      lastMessage: _toMessageItem(message),
      lastMessageAt: message.createdAt,
      unreadCount: 0,
      lastReadMessageId: message.serverMessageId?.toString(),
    );
    final chats = [...state.chats]
      ..removeAt(index)
      ..insert(0, updated);
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
    ref.read(unreadBadgeProvider.notifier).scheduleReconcile();
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
          .read(messageApiServiceProvider)
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

  void _applyRealtimeEvent(ApiWsEvent event) {
    final (type, payload) = switch (event) {
      MessageCreatedWsEvent(:final payload) => ('message', payload),
      MessageUpdatedWsEvent(:final payload) => ('messageUpdated', payload),
      MessageDeletedWsEvent(:final payload) => ('messageDeleted', payload),
      _ => (null, null),
    };
    if (type == null || payload == null) return;

    final chatId = payload.chatId.toString();
    final chats = state.chats;
    final index = chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) {
      if (type == 'message') {
        unawaited(_refreshForRealtimeMiss());
      }
      return;
    }

    final previous = chats[index];
    final message = payload.toDomain();
    if (type == 'message') {
      final senderUid = payload.sender.uid;
      final currentUserId = ref.read(authSessionProvider).currentUserId;
      final createdAt = payload.createdAt;
      final updated = previous.copyWith(
        lastMessage: message,
        lastMessageAt: createdAt,
        unreadCount: senderUid != currentUserId
            ? previous.unreadCount + 1
            : previous.unreadCount,
      );
      final newChats = [...chats]
        ..removeAt(index)
        ..insert(0, updated);
      state = (
        chats: newChats,
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
      return;
    }

    if (type == 'messageUpdated' || type == 'messageDeleted') {
      if (previous.lastMessage?.id != message.id) return;
      final newChats = [...chats];
      newChats[index] = previous.copyWith(lastMessage: message);
      state = (
        chats: newChats,
        nextCursor: state.nextCursor,
        hasMore: state.hasMore,
      );
    }
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

  MessageItem _toMessageItem(ConversationMessage message) {
    return MessageItem(
      id: message.serverMessageId ?? 0,
      message: message.message,
      messageType: message.messageType,
      sticker: message.sticker,
      sender: message.sender,
      chatId: message.scope.chatId,
      createdAt: message.createdAt,
      isEdited: message.isEdited,
      isDeleted: message.isDeleted,
      clientGeneratedId: message.clientGeneratedId,
      replyRootId: message.replyRootId,
      hasAttachments: message.hasAttachments,
      replyToMessage: message.replyToMessage,
      attachments: message.attachments,
      reactions: message.reactions,
      mentions: message.mentions,
      threadInfo: message.threadInfo,
    );
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
