import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/websocket_api_models.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/session/dev_session_store.dart';
import '../../models/chat_api_mapper.dart';
import '../../models/chat_models.dart';
import '../../models/message_api_mapper.dart';
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
      final event = next.valueOrNull;
      if (event != null) _applyRealtimeEvent(event);
    });
    return (chats: const [], nextCursor: null, hasMore: false);
  }

  ChatApiService get _service => ref.read(chatApiServiceProvider);

  /// Load the first page of chats.
  Future<void> loadChats({int limit = 20}) async {
    final res = await _service.fetchChats();
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
      final currentUserId = ref.read(devSessionProvider);
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
}

final chatListStateProvider = NotifierProvider<ChatListNotifier, ChatListState>(
  ChatListNotifier.new,
);
