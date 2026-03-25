import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/realtime_service.dart';
import '../../data/models/message_models.dart';
import '../../data/repositories/message_repository.dart';
import '../shared/draft_store.dart';

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

class ChatDetailViewModel extends ChangeNotifier {
  final MessageRepository _repository;
  final String chatId;
  final String? threadId;
  late final StreamSubscription<RealtimeEvent> _realtimeSubscription;

  ChatDetailViewModel({
    required this.chatId,
    this.threadId,
    MessageRepository? repository,
  }) : _repository =
           repository ?? MessageRepository(chatId: chatId, threadId: threadId) {
    _realtimeSubscription = RealtimeService.instance.events.listen(
      _handleRealtimeEvent,
    );
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
  String? _lastMarkedReadMessageId;

  String? get nextCursor => _repository.nextCursor;
  bool get hasMoreMessages => _repository.nextCursor != null;
  bool get isRealtimeConnected => RealtimeService.instance.isConnected;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(
        '[ChatDetailVM chatId=$chatId threadId=${threadId ?? 'main'}] $message',
      );
    }
  }

  void _rebuildDisplay() {
    _displayItems = _repository.displayItems;
    notifyListeners();
  }

  Future<void> loadMessages() async {
    _log('loadMessages');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.loadMessages();
      _log('loadMessages success count=${_repository.displayItems.length}');
      _isLoading = false;
      _errorMessage = null;
      _rebuildDisplay();
    } catch (e) {
      _log('loadMessages failed: $e');
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadMoreMessages() async {
    if (_repository.store.isEmpty || _isLoadingMore || nextCursor == null) {
      return;
    }
    _log('loadMoreMessages before=${_repository.store.oldestId}');
    _isLoadingMore = true;
    notifyListeners();
    try {
      await _repository.loadMoreMessages();
      _log('loadMoreMessages success count=${_repository.displayItems.length}');
      _isLoadingMore = false;
      _rebuildDisplay();
    } catch (e) {
      _log('loadMoreMessages failed: $e');
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void updateScrollToBottom(bool shouldShow) {
    if (shouldShow != _showScrollToBottom) {
      _showScrollToBottom = shouldShow;
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

  Future<bool> jumpToMessage(String messageId) async {
    var idx = _displayItems.indexWhere((m) => m.id == messageId);

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
      _log('jumpToMessage failed messageId=$messageId error=$e');
      _isLoadingMore = false;
      _errorMessage = 'Failed to jump: $e';
      notifyListeners();
    }
    return false;
  }

  Future<void> sendMessage(
    String text, {
    String? replyToId,
    List<String> attachmentIds = const [],
  }) async {
    try {
      _log(
        'sendMessage replyToId=${replyToId ?? '-'} attachments=${attachmentIds.length}',
      );
      await _repository.sendMessage(
        text,
        replyToId: replyToId,
        attachmentIds: attachmentIds,
      );
      _rebuildDisplay();
    } catch (e) {
      _log('sendMessage failed: $e');
      throw Exception('Failed to send: $e');
    }
  }

  Future<void> editMessage(
    String messageId,
    String newText, {
    List<String> attachmentIds = const [],
  }) async {
    try {
      _log(
        'editMessage messageId=$messageId attachments=${attachmentIds.length}',
      );
      await _repository.editMessage(
        messageId,
        newText,
        attachmentIds: attachmentIds,
      );
      _rebuildDisplay();
    } catch (e) {
      _log('editMessage failed: $e');
      throw Exception('Failed to edit: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      _log('deleteMessage messageId=$messageId');
      await _repository.deleteMessage(messageId);
      _rebuildDisplay();
    } catch (e) {
      _log('deleteMessage failed: $e');
      throw Exception('Failed to delete: $e');
    }
  }

  Future<void> markAsReadUpToLatest() async {
    final latest = _displayItems.isNotEmpty ? _displayItems.last : null;
    if (latest == null ||
        latest.id.isEmpty ||
        _lastMarkedReadMessageId == latest.id) {
      return;
    }
    _log('markAsRead latest=${latest.id}');
    await _repository.markAsRead(latest.id);
    _lastMarkedReadMessageId = latest.id;
  }

  void saveDraft(String text) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      DraftStore.instance.setDraft(_draftKey, trimmed);
    } else {
      DraftStore.instance.clearDraft(_draftKey);
    }
  }

  String? loadDraft() {
    return DraftStore.instance.getDraft(_draftKey);
  }

  void clearDraft() {
    DraftStore.instance.clearDraft(_draftKey);
  }

  String get _draftKey =>
      threadId == null ? chatId : '${chatId}_thread_$threadId';

  void _handleRealtimeEvent(RealtimeEvent event) {
    switch (event) {
      case RealtimeMessageReceived(:final message):
        _log(
          'realtime message chatId=${message.chatId} id=${message.id} replyRoot=${message.replyRootId}',
        );
        _repository.applyRealtimeMessage(message);
        _rebuildDisplay();
        break;
      case RealtimeMessageUpdated(:final message):
        _log('realtime update chatId=${message.chatId} id=${message.id}');
        _repository.applyRealtimeUpdate(message);
        _rebuildDisplay();
        break;
      case RealtimeMessageDeleted(:final message):
        _log('realtime delete chatId=${message.chatId} id=${message.id}');
        _repository.applyRealtimeDeletion(message);
        _rebuildDisplay();
        break;
      case RealtimeConnectionChanged(:final connected):
        _log('realtime connection changed -> $connected');
        notifyListeners();
        break;
    }
  }

  @override
  void dispose() {
    _realtimeSubscription.cancel();
    super.dispose();
  }
}
