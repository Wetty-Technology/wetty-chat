import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../conversation/domain/conversation_message.dart';
import '../../models/chat_models.dart';
import '../data/chat_repository.dart';

typedef ChatListViewState = ({
  List<ChatListItem> chats,
  bool hasMore,
  bool isLoadingMore,
  bool isRefreshing,
  String? errorMessage,
});

class ChatListViewModel extends AsyncNotifier<ChatListViewState> {
  @override
  Future<ChatListViewState> build() async {
    // Watch the underlying chat list state for realtime updates.
    ref.listen<ChatListState>(chatListStateProvider, (_, _) {
      _rebuildFromRepository();
    });
    return _loadInitial();
  }

  Future<ChatListViewState> _loadInitial() async {
    final notifier = ref.read(chatListStateProvider.notifier);
    await notifier.loadChats();
    final repoState = ref.read(chatListStateProvider);
    return (
      chats: repoState.chats,
      hasMore: repoState.hasMore,
      isLoadingMore: false,
      isRefreshing: false,
      errorMessage: null,
    );
  }

  void _rebuildFromRepository() {
    final current = state.value;
    if (current == null) return;
    final repoState = ref.read(chatListStateProvider);
    state = AsyncData((
      chats: repoState.chats,
      hasMore: repoState.hasMore,
      isLoadingMore: current.isLoadingMore,
      isRefreshing: current.isRefreshing,
      errorMessage: current.errorMessage,
    ));
  }

  Future<void> loadMoreChats() async {
    final current = state.value;
    if (current == null) return;
    if (!current.hasMore || current.isLoadingMore || current.chats.isEmpty) {
      return;
    }
    state = AsyncData((
      chats: current.chats,
      hasMore: current.hasMore,
      isLoadingMore: true,
      isRefreshing: current.isRefreshing,
      errorMessage: current.errorMessage,
    ));
    try {
      await ref.read(chatListStateProvider.notifier).loadMoreChats();
    } catch (_) {
      // Silently fail pagination.
    } finally {
      final repoState = ref.read(chatListStateProvider);
      final latest = state.value;
      if (latest != null) {
        state = AsyncData((
          chats: repoState.chats,
          hasMore: repoState.hasMore,
          isLoadingMore: false,
          isRefreshing: latest.isRefreshing,
          errorMessage: latest.errorMessage,
        ));
      }
    }
  }

  Future<void> refreshChats({bool userInitiated = false}) async {
    final current = state.value;
    if (current == null) return;
    if (current.isLoadingMore || current.isRefreshing) return;

    debugPrint("refreshing");
    state = AsyncData((
      chats: current.chats,
      hasMore: current.hasMore,
      isLoadingMore: current.isLoadingMore,
      isRefreshing: true,
      errorMessage: current.errorMessage,
    ));
    try {
      // TODO: may need to redesign the logic when have more chats
      final limit = current.chats.isEmpty ? 11 : current.chats.length;
      await ref.read(chatListStateProvider.notifier).loadChats(limit: limit);
      final repoState = ref.read(chatListStateProvider);
      state = AsyncData((
        chats: repoState.chats,
        hasMore: repoState.hasMore,
        isLoadingMore: false,
        isRefreshing: false,
        errorMessage: null,
      ));
    } catch (e) {
      final latest = state.value;
      if (latest != null) {
        state = AsyncData((
          chats: latest.chats,
          hasMore: latest.hasMore,
          isLoadingMore: false,
          isRefreshing: false,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> toggleChatReadState({required String chatId}) async {
    final chat = ref
        .read(chatListStateProvider)
        .chats
        .where((c) => c.id == chatId)
        .firstOrNull;
    if (chat == null) return;
    if (chat.unreadCount > 0) {
      await ref
          .read(chatListStateProvider.notifier)
          .markChatReadViaSwipe(chatId: chatId);
    } else {
      await ref
          .read(chatListStateProvider.notifier)
          .markChatUnread(chatId: chatId);
    }
  }

  void insertChat(ChatListItem chat) {
    ref.read(chatListStateProvider.notifier).insertChat(chat);
  }

  void markChatRead({required String chatId, required int messageId}) {
    ref
        .read(chatListStateProvider.notifier)
        .markChatRead(chatId: chatId, messageId: messageId);
  }

  void recordOutgoingMessage(ConversationMessage message) {
    ref.read(chatListStateProvider.notifier).recordOutgoingMessage(message);
  }

  Future<ChatListItem?> createChat({String? name}) async {
    return ref.read(chatListStateProvider.notifier).createChat(name: name);
  }
}

final chatListViewModelProvider =
    AsyncNotifierProvider<ChatListViewModel, ChatListViewState>(
      ChatListViewModel.new,
    );
