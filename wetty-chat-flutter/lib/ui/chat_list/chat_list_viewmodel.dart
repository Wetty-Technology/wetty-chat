import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/realtime_service.dart';
import '../../data/models/chat_models.dart';
import '../../data/repositories/chat_repository.dart';

class ChatListViewModel extends ChangeNotifier {
  final ChatRepository _repository;
  late final StreamSubscription<RealtimeEvent> _realtimeSubscription;
  Timer? _refreshTimer;

  ChatListViewModel({ChatRepository? repository})
    : _repository = repository ?? ChatRepository() {
    _realtimeSubscription = RealtimeService.instance.events.listen(
      _handleRealtimeEvent,
    );
  }

  List<ChatListItem> get chats => _repository.chats;
  bool get hasMore => _repository.hasMore;
  bool get isRealtimeConnected => RealtimeService.instance.isConnected;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[ChatListVM] $message');
    }
  }

  Future<void> loadChats() async {
    _log('loadChats');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.loadChats();
      _log('loadChats success count=${_repository.chats.length}');
      _isLoading = false;
      _errorMessage = null;
    } catch (e) {
      _log('loadChats failed: $e');
      _isLoading = false;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> loadMoreChats() async {
    if (!hasMore || _isLoadingMore || chats.isEmpty) return;
    _log('loadMoreChats');
    _isLoadingMore = true;
    notifyListeners();
    try {
      await _repository.loadMoreChats();
    } catch (_) {
      // Silently fail pagination.
    }
    _isLoadingMore = false;
    notifyListeners();
  }

  void insertChat(ChatListItem chat) {
    _repository.insertChat(chat);
    notifyListeners();
  }

  Future<ChatListItem?> createChat({String? name}) async {
    return _repository.createChat(name: name);
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    switch (event) {
      case RealtimeMessageReceived(:final message):
        _log('realtime message chatId=${message.chatId} id=${message.id}');
        _scheduleRefresh();
        break;
      case RealtimeMessageUpdated(:final message):
        _log('realtime update chatId=${message.chatId} id=${message.id}');
        _scheduleRefresh();
        break;
      case RealtimeMessageDeleted(:final message):
        _log('realtime delete chatId=${message.chatId} id=${message.id}');
        _scheduleRefresh();
        break;
      case RealtimeConnectionChanged(:final connected):
        _log('realtime connection changed -> $connected');
        notifyListeners();
        break;
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _log('scheduleRefresh');
    _refreshTimer = Timer(const Duration(milliseconds: 250), () {
      if (_isLoading) return;
      _log('scheduleRefresh fired');
      unawaited(loadChats());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _realtimeSubscription.cancel();
    super.dispose();
  }
}
