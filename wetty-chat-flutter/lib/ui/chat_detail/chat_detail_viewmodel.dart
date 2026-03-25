import 'package:flutter/foundation.dart';

import '../../data/models/message_models.dart';
import '../../data/repositories/message_repository.dart';
import '../shared/draft_store.dart';

// ---------------------------------------------------------------------------
// InputState 閳?the three mutually exclusive states for the input bar
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

  ChatDetailViewModel({required this.chatId, MessageRepository? repository})
    : _repository = repository ?? MessageRepository(chatId: chatId);

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
      await _repository.loadMessages();
      _isLoading = false;
      _errorMessage = null;
      _rebuildDisplay();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
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

    if (idx >= 0) {
      _highlightedMessageId = messageId;
      notifyListeners();
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
        return true;
      }
    } catch (e) {
      _isLoadingMore = false;
      _errorMessage = 'Failed to jump: $e';
      notifyListeners();
    }
    return false;
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
