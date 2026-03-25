import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/models/message_models.dart';
import '../../data/repositories/message_repository.dart';
import '../shared/draft_store.dart';

// ---------------------------------------------------------------------------
// InputState – the three mutually exclusive states for the input bar
// ---------------------------------------------------------------------------

sealed class InputState {}

class InputEmpty extends InputState {}

class InputReplying extends InputState {
  final MessageItem message;
  InputReplying(this.message);
}

class InputEditing extends InputState {
  final MessageItem message;
  InputEditing(this.message);
}

// ---------------------------------------------------------------------------
// ChatDetailViewModel
// ---------------------------------------------------------------------------

/// ViewModel for the chat detail (message list) screen.
class ChatDetailViewModel extends ChangeNotifier {
  final MessageRepository _repository;
  final String chatId;
  final int unreadCount;

  Timer? _syncTimer;
  String? _lastReadSyncId;
  String? _currentReadId;

  ChatDetailViewModel({
    required this.chatId,
    this.unreadCount = 0,
    MessageRepository? repository,
  }) : _repository = repository ?? MessageRepository(chatId: chatId) {
    _repository.store.addListener(_rebuildDisplay);
    _startSyncTimer();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _repository.store.removeListener(_rebuildDisplay);
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

  String? _highlightedMessageId;
  String? get highlightedMessageId => _highlightedMessageId;

  String? _firstUnreadMessageId;
  String? get firstUnreadMessageId => _firstUnreadMessageId;

  bool _showUnreadDivider = false;
  bool get showUnreadDivider => _showUnreadDivider;

  String? get nextCursor => _repository.nextCursor;
  bool get hasMoreMessages => _repository.nextCursor != null;

  void _rebuildDisplay() {
    _displayItems = _repository.displayItems;
    notifyListeners();
  }

  // ---- Loading ----

  Future<void> loadMessages() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.initLoadMessages();
      _isLoading = false;
      _errorMessage = null;
      _rebuildDisplay();

      // Determine first unread and jump
      await _handleInitialJump();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> _handleInitialJump() async {
    if (unreadCount <= 0) return;

    print("unread count: $unreadCount");

    // Fetch more messages if unreadCount is larger than what we currently have
    while (unreadCount > _displayItems.length &&
        _repository.nextCursor != null) {
      await _repository.loadMoreMessages();
      _rebuildDisplay();
    }

    String? targetId;
    if (_displayItems.isNotEmpty) {
      print("item len: ${_displayItems.length}");
      for (var i = 0; i < _displayItems.length; i++) {
        print("message id: ${_displayItems[i].id}");
      }
      if (unreadCount <= _displayItems.length) {
        targetId = _displayItems[_displayItems.length - unreadCount].id;
      } else {
        // Even after fetching all, we don't have enough? Just jump to the oldest.
        targetId = _displayItems.first.id;
      }
    }

    if (targetId != null) {
      _firstUnreadMessageId = targetId;

      // Only show divider if there's actually a "read" message boundary.
      // If targetId is the oldest message and no more history, don't show divider.
      final targetIdx = _displayItems.indexWhere((m) => m.id == targetId);
      if (targetIdx < _displayItems.length - 1 || hasMoreMessages) {
        _showUnreadDivider = true;
      } else {
        _showUnreadDivider = false;
      }

      notifyListeners();
      await jumpToMessage(targetId);
    }
  }

  Future<void> loadMoreMessages() async {
    if (_repository.store.isEmpty || _isLoadingMore || nextCursor == null) {
      return;
    }
    _isLoadingMore = true;
    notifyListeners();
    try {
      await _repository.loadMoreMessages();
      _isLoadingMore = false;
      _rebuildDisplay();
    } catch (e) {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ---- Read status sync ----

  void onMessageVisible(String messageId) {
    // Keep track of the highest message ID seen
    if (_currentReadId == null ||
        (int.tryParse(messageId) ?? 0) > (int.tryParse(_currentReadId!) ?? 0)) {
      _currentReadId = messageId;
    }
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _syncReadStatus();
    });
  }

  Future<void> _syncReadStatus() async {
    if (_currentReadId == null || _currentReadId == _lastReadSyncId) return;

    final toSync = _currentReadId!;
    try {
      await _repository.markAsRead(toSync);
      _lastReadSyncId = toSync;
    } catch (e) {
      print("Sync read status failed: $e");
    }
  }

  // ---- Scroll ----

  void updateScrollToBottom(bool shouldShow) {
    if (shouldShow != _showScrollToBottom) {
      _showScrollToBottom = shouldShow;
      notifyListeners();
    }
  }

  // ---- Input state ----

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

  // ---- Jump to message ----

  Future<bool> jumpToMessage(String messageId) async {
    int idx = _displayItems.indexWhere((m) => m.id == messageId);
    // if found, highlight the message
    if (idx >= 0) {
      _highlightedMessageId = messageId;
      notifyListeners();
      _clearHighlightAfterDelay();
      return true;
    }

    _isLoadingMore = true;
    notifyListeners();
    try {
      await _repository.fetchAround(messageId);
      _isLoadingMore = false;
      _rebuildDisplay();
      idx = _displayItems.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        _highlightedMessageId = messageId;
        notifyListeners();
        _clearHighlightAfterDelay();
        return true;
      }
    } catch (e) {
      _isLoadingMore = false;
      _errorMessage = 'Failed to jump: $e';
      notifyListeners();
    }
    return false;
  }

  void _clearHighlightAfterDelay() {
    Future.delayed(const Duration(milliseconds: 2000), () {
      _highlightedMessageId = null;
      notifyListeners();
    });
  }

  // ---- Send / Edit / Delete ----

  Future<void> sendMessage(String text, {String? replyToId}) async {
    try {
      await _repository.sendMessage(text, replyToId: replyToId);
      _rebuildDisplay();
    } catch (e) {
      throw Exception('Failed to send: $e');
    }
  }

  Future<void> editMessage(String messageId, String newText) async {
    try {
      await _repository.editMessage(messageId, newText);
      _rebuildDisplay();
    } catch (e) {
      throw Exception('Failed to edit: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _repository.deleteMessage(messageId);
      _rebuildDisplay();
    } catch (e) {
      throw Exception('Failed to delete: $e');
    }
  }

  // ---- Draft ----

  void saveDraft(String text) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      DraftStore.instance.setDraft(chatId, trimmed);
    } else {
      DraftStore.instance.clearDraft(chatId);
    }
  }

  String? loadDraft() {
    return DraftStore.instance.getDraft(chatId);
  }

  void clearDraft() {
    DraftStore.instance.clearDraft(chatId);
  }
}
