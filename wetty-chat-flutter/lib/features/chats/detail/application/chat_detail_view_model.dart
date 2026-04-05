import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/websocket_api_models.dart';
import '../../../../core/network/websocket_service.dart';
import '../../models/chat_input_state.dart';
import '../../models/message_models.dart';
import 'chat_draft_store.dart';
import '../data/message_api_service.dart';
import '../data/message_repository.dart';

typedef ChatDetailArgs = ({String chatId, int unreadCount});

enum ChatWindowMode { latest, unreadBoundary, aroundMessage }

typedef ChatDetailState = ({
  List<MessageItem> displayItems,
  bool isLoadingMore,
  String? errorMessage,
  bool showScrollToBottom,
  InputState inputState,
  int? highlightedMessageId,
  int? firstUnreadMessageId,
  bool showUnreadDivider,
  bool hasMoreMessages,
  bool hasNewerMessages,
  bool shouldRefreshChats,
});

class ChatDetailViewModel
    extends FamilyAsyncNotifier<ChatDetailState, ChatDetailArgs> {
  static const int initialWindowSize = 100;
  static const int pageSize = 50;
  static const int maxWindowSize = 300;
  static const Duration readSyncDebounce = Duration(milliseconds: 100);

  late final MessageRepository _repository;
  late final String chatId;
  late final int _unreadCount;

  Timer? _readSyncDebounceTimer;
  int? _lastReadSyncId;
  int? _currentReadId;
  int? _newestVisibleId;
  int? _oldestVisibleId;
  int? _windowAnchorMessageId;
  bool _hasOlder = false;
  bool _hasNewer = false;
  bool _isAtLiveEdge = true;
  bool _didSyncReadState = false;
  bool _isApplyingExplicitWindowChange = false;
  ChatWindowMode _windowMode = ChatWindowMode.latest;

  @override
  Future<ChatDetailState> build(ChatDetailArgs arg) async {
    chatId = arg.chatId;
    _unreadCount = arg.unreadCount;
    _repository = MessageRepository(
      chatId: chatId,
      service: ref.read(messageApiServiceProvider),
    );

    // Subscribe to WebSocket events for this chat.
    ref.listen<AsyncValue<ApiWsEvent>>(wsEventsProvider, (_, next) {
      final event = next.valueOrNull;
      if (event != null) _onRealtimeEvent(event);
    });

    ref.onDispose(() {
      _readSyncDebounceTimer?.cancel();
    });

    return _loadMessages();
  }

  void _onRealtimeEvent(ApiWsEvent event) {
    _repository.applyRealtimeEvent(event);
    _onStoreChanged();
  }

  ChatDetailState get _currentState => state.requireValue;

  void _onStoreChanged() {
    if (!state.hasValue) return;
    final current = _currentState;
    if (current.displayItems.isEmpty || _isApplyingExplicitWindowChange) return;

    final rebuilt = _repository.rebuildWindow(
      limit: maxWindowSize,
      anchorMessageId: _windowAnchorMessageId ?? current.displayItems.first.id,
      liveEdge: _windowMode == ChatWindowMode.latest && _isAtLiveEdge,
    );
    if (rebuilt.isEmpty) return;

    _setDisplayItems(rebuilt, anchorMessageId: _windowAnchorMessageId);
  }

  Future<ChatDetailState> _loadMessages() async {
    final items = await _repository.initLoadMessages(limit: initialWindowSize);
    _lastReadSyncId = null;
    _currentReadId = null;
    _didSyncReadState = false;
    _windowMode = ChatWindowMode.latest;
    _windowAnchorMessageId = null;

    var firstUnreadMessageId = <int?>[null].first;
    var showUnreadDivider = false;

    // Load unread window if needed
    if (_unreadCount > 0) {
      final result = await _loadInitialUnreadWindow(items);
      if (result != null) {
        return result;
      }
    }

    _setDisplayItemsInternal(items);
    return _buildState(
      displayItems: items,
      firstUnreadMessageId: firstUnreadMessageId,
      showUnreadDivider: showUnreadDivider,
    );
  }

  Future<ChatDetailState?> _loadInitialUnreadWindow(
    List<MessageItem> initialItems,
  ) async {
    int? targetId = _repository.findUnreadBoundaryId(_unreadCount);
    while (targetId == null && _repository.nextCursor != null) {
      final oldestLoadedId = _repository.store.oldestId;
      if (oldestLoadedId == null) break;

      final olderItems = await _repository.extendOlderWindow(
        oldestLoadedId,
        pageSize: pageSize,
      );
      if (olderItems.isEmpty) break;
      targetId = _repository.findUnreadBoundaryId(_unreadCount);
    }
    if (targetId == null) return null;

    final unreadWindow = await _repository.getWindowAround(
      targetId,
      before: initialWindowSize ~/ 2,
      after: initialWindowSize ~/ 2,
    );
    if (unreadWindow.isEmpty) return null;

    _windowMode = ChatWindowMode.unreadBoundary;
    _windowAnchorMessageId = targetId;
    final displayItems = unreadWindow
        .take(maxWindowSize)
        .toList(growable: false);
    _setDisplayItemsInternal(displayItems, anchorMessageId: targetId);
    return _buildState(
      displayItems: displayItems,
      firstUnreadMessageId: targetId,
      showUnreadDivider: true,
    );
  }

  Future<bool> loadMoreMessages() async {
    if (!state.hasValue) return false;
    final current = _currentState;
    if (current.displayItems.isEmpty || current.isLoadingMore || !_hasOlder) {
      return false;
    }

    _updateState(current.copyWith(isLoadingMore: true));
    _isApplyingExplicitWindowChange = true;

    try {
      final olderItems = await _repository.extendOlderWindow(
        _oldestVisibleId!,
        pageSize: pageSize,
      );
      if (olderItems.isEmpty) {
        _syncWindowFlags();
        return false;
      }

      var nextItems = <MessageItem>[...current.displayItems, ...olderItems];
      if (nextItems.length > maxWindowSize) {
        final trimCount = nextItems.length - maxWindowSize;
        nextItems = nextItems.sublist(trimCount);
      }

      _setDisplayItems(
        nextItems,
        anchorMessageId: _windowAnchorMessageId ?? _oldestVisibleId,
      );
      return true;
    } catch (e) {
      _updateState(current.copyWith(errorMessage: e.toString()));
      return false;
    } finally {
      _isApplyingExplicitWindowChange = false;
      final latest = state.valueOrNull;
      if (latest != null) {
        _updateState(latest.copyWith(isLoadingMore: false));
      }
    }
  }

  Future<bool> loadNewerMessages() async {
    if (!state.hasValue) return false;
    final current = _currentState;
    if (current.displayItems.isEmpty || current.isLoadingMore || !_hasNewer) {
      return false;
    }

    _updateState(current.copyWith(isLoadingMore: true));
    _isApplyingExplicitWindowChange = true;

    try {
      final newerItems = await _repository.extendNewerWindow(
        _newestVisibleId!,
        pageSize: pageSize,
      );
      if (newerItems.isEmpty) {
        _syncWindowFlags();
        return false;
      }

      var nextItems = <MessageItem>[...newerItems, ...current.displayItems];
      if (nextItems.length > maxWindowSize) {
        nextItems = nextItems.sublist(0, maxWindowSize);
      }

      final anchorMessageId = nextItems.first.id;
      if (!_repository.hasNewerAdjacent(anchorMessageId)) {
        _windowMode = ChatWindowMode.latest;
        _isAtLiveEdge = true;
        _windowAnchorMessageId = null;
      }
      _setDisplayItems(
        nextItems,
        anchorMessageId: _windowMode == ChatWindowMode.latest
            ? null
            : (_windowAnchorMessageId ?? anchorMessageId),
      );
      return true;
    } catch (e) {
      _updateState(_currentState.copyWith(errorMessage: e.toString()));
      return false;
    } finally {
      _isApplyingExplicitWindowChange = false;
      final latest = state.valueOrNull;
      if (latest != null) {
        _updateState(latest.copyWith(isLoadingMore: false));
      }
    }
  }

  Future<void> jumpToBottom() async {
    if (!state.hasValue) return;
    final current = _currentState;
    if (current.isLoadingMore) return;

    _updateState(current.copyWith(isLoadingMore: true));
    _isApplyingExplicitWindowChange = true;

    try {
      final latestWindow = await _repository.refreshLatestWindow(
        limit: initialWindowSize,
      );
      if (latestWindow.isEmpty && current.displayItems.isNotEmpty) {
        return;
      }
      _windowMode = ChatWindowMode.latest;
      _windowAnchorMessageId = null;
      _isAtLiveEdge = true;
      _setDisplayItems(latestWindow);
      _updateState(
        _currentState.copyWith(
          showScrollToBottom: false,
          firstUnreadMessageId: null,
          showUnreadDivider: false,
        ),
      );
    } catch (e) {
      _updateState(_currentState.copyWith(errorMessage: e.toString()));
    } finally {
      _isApplyingExplicitWindowChange = false;
      final latest = state.valueOrNull;
      if (latest != null) {
        _updateState(latest.copyWith(isLoadingMore: false));
      }
    }
  }

  void onMessageVisible(int messageId) {
    if (_currentReadId == null || messageId > _currentReadId!) {
      _currentReadId = messageId;
      _scheduleReadSync();
    }
  }

  void _scheduleReadSync() {
    _readSyncDebounceTimer?.cancel();
    _readSyncDebounceTimer = Timer(readSyncDebounce, () {
      _syncReadStatus();
    });
  }

  Future<bool> flushReadStatus() async {
    _readSyncDebounceTimer?.cancel();
    _readSyncDebounceTimer = null;
    return _syncReadStatus();
  }

  Future<bool> _syncReadStatus() async {
    if (_currentReadId == null || _currentReadId == _lastReadSyncId) {
      return false;
    }

    final toSync = _currentReadId!;
    try {
      await _repository.markAsRead(toSync);
      _lastReadSyncId = toSync;
      _didSyncReadState = true;
      if (state.hasValue) {
        _updateState(_currentState.copyWith(shouldRefreshChats: true));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void updateScrollToBottom(bool shouldShow) {
    if (!state.hasValue) return;
    final current = _currentState;
    if (shouldShow == current.showScrollToBottom) return;
    _isAtLiveEdge = !shouldShow;
    _updateState(current.copyWith(showScrollToBottom: shouldShow));
  }

  void setReplyTo(MessageItem msg) {
    if (!state.hasValue) return;
    _updateState(_currentState.copyWith(inputState: InputReplying(msg)));
  }

  void clearInputState() {
    if (!state.hasValue) return;
    _updateState(_currentState.copyWith(inputState: InputEmpty()));
  }

  void startEditing(MessageItem msg) {
    if (!state.hasValue) return;
    _updateState(_currentState.copyWith(inputState: InputEditing(msg)));
  }

  Future<bool> jumpToMessage(int messageId) async {
    if (!state.hasValue) return false;
    final current = _currentState;

    final existingIndex = current.displayItems.indexWhere(
      (item) => item.id == messageId,
    );
    if (existingIndex >= 0) {
      _windowMode = ChatWindowMode.aroundMessage;
      _windowAnchorMessageId = messageId;
      _highlightMessage(messageId);
      return true;
    }

    _updateState(current.copyWith(isLoadingMore: true));
    _isApplyingExplicitWindowChange = true;

    try {
      final window = await _repository.getWindowAround(
        messageId,
        before: initialWindowSize ~/ 2,
        after: initialWindowSize ~/ 2,
      );
      if (window.isEmpty) return false;

      _windowMode = ChatWindowMode.aroundMessage;
      _windowAnchorMessageId = messageId;
      _setDisplayItems(
        window.take(maxWindowSize).toList(growable: false),
        anchorMessageId: messageId,
      );
      _highlightMessage(messageId);
      return true;
    } catch (e) {
      _updateState(_currentState.copyWith(errorMessage: 'Failed to jump: $e'));
      return false;
    } finally {
      _isApplyingExplicitWindowChange = false;
      final latest = state.valueOrNull;
      if (latest != null) {
        _updateState(latest.copyWith(isLoadingMore: false));
      }
    }
  }

  void _highlightMessage(int messageId) {
    if (!state.hasValue) return;
    _updateState(_currentState.copyWith(highlightedMessageId: messageId));
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (state.hasValue) {
        _updateState(_currentState.copyWith(highlightedMessageId: null));
      }
    });
  }

  int? findWindowIndex(int messageId) {
    if (_newestVisibleId == null || _oldestVisibleId == null) return null;
    return _repository.findIndexInWindow(
      newestVisibleId: _newestVisibleId!,
      oldestVisibleId: _oldestVisibleId!,
      messageId: messageId,
    );
  }

  Future<void> sendMessage(
    String text, {
    int? replyToId,
    List<String>? attachmentIds,
  }) async {
    try {
      await _repository.sendMessage(
        text,
        replyToId: replyToId,
        attachmentIds: attachmentIds,
      );
    } catch (e) {
      throw Exception('Failed to send: $e');
    }
  }

  Future<void> editMessage(int messageId, String newText) async {
    try {
      await _repository.editMessage(messageId, newText);
    } catch (e) {
      throw Exception('Failed to edit: $e');
    }
  }

  Future<void> deleteMessage(int messageId) async {
    try {
      await _repository.deleteMessage(messageId);
    } catch (e) {
      throw Exception('Failed to delete: $e');
    }
  }

  void saveDraft(String text) {
    final drafts = ref.read(chatDraftProvider);
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      drafts.setDraft(chatId, trimmed);
    } else {
      drafts.clearDraft(chatId);
    }
  }

  String? loadDraft() {
    return ref.read(chatDraftProvider).getDraft(chatId);
  }

  void clearDraft() {
    ref.read(chatDraftProvider).clearDraft(chatId);
  }

  int? get newestVisibleId => _newestVisibleId;
  int? get oldestVisibleId => _oldestVisibleId;

  void _setDisplayItems(List<MessageItem> items, {int? anchorMessageId}) {
    _setDisplayItemsInternal(items, anchorMessageId: anchorMessageId);
    if (state.hasValue) {
      _updateState(
        _currentState.copyWith(
          displayItems: List.unmodifiable(items),
          hasMoreMessages: _hasOlder,
          hasNewerMessages: _hasNewer,
        ),
      );
    }
  }

  void _setDisplayItemsInternal(
    List<MessageItem> items, {
    int? anchorMessageId,
  }) {
    if (items.isNotEmpty) {
      _newestVisibleId = items.first.id;
      _oldestVisibleId = items.last.id;
    } else {
      _newestVisibleId = null;
      _oldestVisibleId = null;
    }
    _windowAnchorMessageId = anchorMessageId ?? _windowAnchorMessageId;
    _syncWindowFlags();
  }

  void _syncWindowFlags() {
    _hasOlder = _oldestVisibleId != null
        ? _repository.hasOlderAdjacent(_oldestVisibleId!)
        : false;
    _hasNewer = _newestVisibleId != null
        ? _repository.hasNewerAdjacent(_newestVisibleId!)
        : false;
  }

  ChatDetailState _buildState({
    required List<MessageItem> displayItems,
    int? firstUnreadMessageId,
    bool showUnreadDivider = false,
  }) {
    return (
      displayItems: List.unmodifiable(displayItems),
      isLoadingMore: false,
      errorMessage: null,
      showScrollToBottom: false,
      inputState: InputEmpty(),
      highlightedMessageId: null,
      firstUnreadMessageId: firstUnreadMessageId,
      showUnreadDivider: showUnreadDivider,
      hasMoreMessages: _hasOlder,
      hasNewerMessages: _hasNewer,
      shouldRefreshChats: _didSyncReadState,
    );
  }

  void _updateState(ChatDetailState newState) {
    state = AsyncData(newState);
  }
}

/// Extension for copyWith on the state record.
extension ChatDetailStateCopyWith on ChatDetailState {
  ChatDetailState copyWith({
    List<MessageItem>? displayItems,
    bool? isLoadingMore,
    Object? errorMessage = _sentinel,
    bool? showScrollToBottom,
    InputState? inputState,
    Object? highlightedMessageId = _sentinel,
    Object? firstUnreadMessageId = _sentinel,
    bool? showUnreadDivider,
    bool? hasMoreMessages,
    bool? hasNewerMessages,
    bool? shouldRefreshChats,
  }) {
    return (
      displayItems: displayItems ?? this.displayItems,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      showScrollToBottom: showScrollToBottom ?? this.showScrollToBottom,
      inputState: inputState ?? this.inputState,
      highlightedMessageId: highlightedMessageId == _sentinel
          ? this.highlightedMessageId
          : highlightedMessageId as int?,
      firstUnreadMessageId: firstUnreadMessageId == _sentinel
          ? this.firstUnreadMessageId
          : firstUnreadMessageId as int?,
      showUnreadDivider: showUnreadDivider ?? this.showUnreadDivider,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      hasNewerMessages: hasNewerMessages ?? this.hasNewerMessages,
      shouldRefreshChats: shouldRefreshChats ?? this.shouldRefreshChats,
    );
  }
}

const _sentinel = Object();

final chatDetailViewModelProvider =
    AsyncNotifierProvider.family<
      ChatDetailViewModel,
      ChatDetailState,
      ChatDetailArgs
    >(ChatDetailViewModel.new);
