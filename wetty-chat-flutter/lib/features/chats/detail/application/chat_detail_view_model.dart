import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/chat_input_state.dart';
import '../../models/message_models.dart';
import 'chat_draft_store.dart';
import 'message_realtime_controller.dart';
import '../data/message_repository.dart';

class ChatDetailViewModel extends ChangeNotifier {
  static const int initialWindowSize = 100;
  static const int pageSize = 50;
  static const int maxWindowSize = 300;
  static const Duration readSyncDebounce = Duration(milliseconds: 100);

  final MessageRepository _repository;
  late final MessageRealtimeController _realtimeController;
  final String chatId;
  final int unreadCount;

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

  ChatDetailViewModel({
    required this.chatId,
    this.unreadCount = 0,
    MessageRepository? repository,
  }) : _repository = repository ?? MessageRepository(chatId: chatId) {
    _repository.store.addListener(_onStoreChanged);
    _realtimeController = MessageRealtimeController(_repository)..start();
  }

  @override
  void dispose() {
    _readSyncDebounceTimer?.cancel();
    _realtimeController.dispose();
    _repository.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  List<MessageItem> _displayItems = [];
  List<MessageItem> get displayItems => _displayItems;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _showScrollToBottom = false;
  bool get showScrollToBottom => _showScrollToBottom;

  InputState _inputState = InputEmpty();
  InputState get inputState => _inputState;

  int? _highlightedMessageId;
  int? get highlightedMessageId => _highlightedMessageId;

  int? _firstUnreadMessageId;
  int? get firstUnreadMessageId => _firstUnreadMessageId;

  bool _showUnreadDivider = false;
  bool get showUnreadDivider => _showUnreadDivider;

  bool get hasMoreMessages => _hasOlder;
  bool get hasNewerMessages => _hasNewer;
  bool get shouldRefreshChats => _didSyncReadState;
  int? get newestVisibleId => _newestVisibleId;
  int? get oldestVisibleId => _oldestVisibleId;

  void _onStoreChanged() {
    if (_isLoading ||
        _displayItems.isEmpty ||
        _isApplyingExplicitWindowChange) {
      return;
    }

    final rebuilt = _repository.rebuildWindow(
      limit: maxWindowSize,
      anchorMessageId: _windowAnchorMessageId ?? _displayItems.first.id,
      liveEdge: _windowMode == ChatWindowMode.latest && _isAtLiveEdge,
    );
    if (rebuilt.isEmpty) return;

    _setDisplayItems(rebuilt, anchorMessageId: _windowAnchorMessageId);
    notifyListeners();
  }

  Future<void> loadMessages() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final items = await _repository.initLoadMessages(
        limit: initialWindowSize,
      );
      _lastReadSyncId = null;
      _currentReadId = null;
      _didSyncReadState = false;
      _firstUnreadMessageId = null;
      _showUnreadDivider = false;
      _windowMode = ChatWindowMode.latest;
      _windowAnchorMessageId = null;
      _isLoading = false;
      _errorMessage = null;
      _setDisplayItems(items);
      await _loadInitialUnreadWindowIfNeeded();
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> _loadInitialUnreadWindowIfNeeded() async {
    if (unreadCount <= 0) return;

    int? targetId = _repository.findUnreadBoundaryId(unreadCount);
    while (targetId == null && _repository.nextCursor != null) {
      final oldestLoadedId = _repository.store.oldestId;
      if (oldestLoadedId == null) break;

      final olderItems = await _repository.extendOlderWindow(
        oldestLoadedId,
        pageSize: pageSize,
      );
      if (olderItems.isEmpty) break;
      targetId = _repository.findUnreadBoundaryId(unreadCount);
    }
    if (targetId == null) return;

    final unreadWindow = await _repository.getWindowAround(
      targetId,
      before: initialWindowSize ~/ 2,
      after: initialWindowSize ~/ 2,
    );
    if (unreadWindow.isEmpty) return;

    _firstUnreadMessageId = targetId;
    _showUnreadDivider = true;
    _windowMode = ChatWindowMode.unreadBoundary;
    _windowAnchorMessageId = targetId;
    _setDisplayItems(
      unreadWindow.take(maxWindowSize).toList(growable: false),
      anchorMessageId: targetId,
    );
  }

  Future<bool> loadMoreMessages() async {
    if (_displayItems.isEmpty || _isLoadingMore || !_hasOlder) {
      return false;
    }

    _isLoadingMore = true;
    _isApplyingExplicitWindowChange = true;
    notifyListeners();

    try {
      final olderItems = await _repository.extendOlderWindow(
        _oldestVisibleId!,
        pageSize: pageSize,
      );
      if (olderItems.isEmpty) {
        _syncWindowFlags();
        return false;
      }

      var nextItems = <MessageItem>[..._displayItems, ...olderItems];
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
      _errorMessage = e.toString();
      return false;
    } finally {
      _isApplyingExplicitWindowChange = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<bool> loadNewerMessages() async {
    if (_displayItems.isEmpty || _isLoadingMore || !_hasNewer) {
      return false;
    }

    _isLoadingMore = true;
    _isApplyingExplicitWindowChange = true;
    notifyListeners();

    try {
      final newerItems = await _repository.extendNewerWindow(
        _newestVisibleId!,
        pageSize: pageSize,
      );
      if (newerItems.isEmpty) {
        _syncWindowFlags();
        return false;
      }

      var nextItems = <MessageItem>[...newerItems, ..._displayItems];
      if (nextItems.length > maxWindowSize) {
        nextItems = nextItems.sublist(0, maxWindowSize);
      }

      final anchorMessageId = nextItems.first.id;
      if (!_repository.hasNewerAdjacent(anchorMessageId)) {
        _windowMode = ChatWindowMode.latest;
        _isAtLiveEdge = true;
        _showScrollToBottom = false;
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
      _errorMessage = e.toString();
      return false;
    } finally {
      _isApplyingExplicitWindowChange = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> jumpToBottom() async {
    if (_isLoadingMore) return;

    _isLoadingMore = true;
    _isApplyingExplicitWindowChange = true;
    notifyListeners();

    try {
      final latestWindow = await _repository.refreshLatestWindow(
        limit: initialWindowSize,
      );
      if (latestWindow.isEmpty && _displayItems.isNotEmpty) {
        return;
      }
      _windowMode = ChatWindowMode.latest;
      _windowAnchorMessageId = null;
      _firstUnreadMessageId = null;
      _showUnreadDivider = false;
      _isAtLiveEdge = true;
      _showScrollToBottom = false;
      _setDisplayItems(latestWindow);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isApplyingExplicitWindowChange = false;
      _isLoadingMore = false;
      notifyListeners();
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
      return true;
    } catch (_) {
      return false;
    }
  }

  void updateScrollToBottom(bool shouldShow) {
    final changed = shouldShow != _showScrollToBottom;
    _showScrollToBottom = shouldShow;
    _isAtLiveEdge = !shouldShow;
    if (changed) {
      notifyListeners();
    }
  }

  void setReplyTo(MessageItem msg) {
    _inputState = InputReplying(msg);
    notifyListeners();
  }

  void clearInputState() {
    _inputState = InputEmpty();
    notifyListeners();
  }

  void startEditing(MessageItem msg) {
    _inputState = InputEditing(msg);
    notifyListeners();
  }

  Future<bool> jumpToMessage(int messageId) async {
    final existingIndex = _displayItems.indexWhere(
      (item) => item.id == messageId,
    );
    if (existingIndex >= 0) {
      _windowMode = ChatWindowMode.aroundMessage;
      _windowAnchorMessageId = messageId;
      _highlightMessage(messageId);
      return true;
    }

    _isLoadingMore = true;
    _isApplyingExplicitWindowChange = true;
    notifyListeners();

    try {
      final window = await _repository.getWindowAround(
        messageId,
        before: initialWindowSize ~/ 2,
        after: initialWindowSize ~/ 2,
      );
      if (window.isEmpty) {
        return false;
      }

      _windowMode = ChatWindowMode.aroundMessage;
      _windowAnchorMessageId = messageId;
      _setDisplayItems(
        window.take(maxWindowSize).toList(growable: false),
        anchorMessageId: messageId,
      );
      _highlightMessage(messageId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to jump: $e';
      return false;
    } finally {
      _isApplyingExplicitWindowChange = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void _highlightMessage(int messageId) {
    _highlightedMessageId = messageId;
    notifyListeners();
    _clearHighlightAfterDelay();
  }

  void _clearHighlightAfterDelay() {
    Future.delayed(const Duration(milliseconds: 2000), () {
      _highlightedMessageId = null;
      notifyListeners();
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
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      ChatDraftStore.instance.setDraft(chatId, trimmed);
    } else {
      ChatDraftStore.instance.clearDraft(chatId);
    }
  }

  String? loadDraft() {
    return ChatDraftStore.instance.getDraft(chatId);
  }

  void clearDraft() {
    ChatDraftStore.instance.clearDraft(chatId);
  }

  void _setDisplayItems(List<MessageItem> items, {int? anchorMessageId}) {
    _displayItems = List.unmodifiable(items);
    if (_displayItems.isNotEmpty) {
      _newestVisibleId = _displayItems.first.id;
      _oldestVisibleId = _displayItems.last.id;
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
}
