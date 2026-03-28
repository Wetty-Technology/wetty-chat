import 'package:flutter/foundation.dart';

import '../../data/models/chat_models.dart';
import '../../data/repositories/chat_repository.dart';

class ChatListViewModel extends ChangeNotifier {
  final ChatRepository _repository;

  ChatListViewModel({ChatRepository? repository})
    : _repository = repository ?? ChatRepository() {
    _repository.addListener(notifyListeners);
  }

  List<ChatListItem> get chats => _repository.chats;
  bool get hasMore => _repository.hasMore;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadChats() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.loadChats();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> initLoadChats() => loadChats();

  Future<void> loadMoreChats() async {
    if (!hasMore || _isLoadingMore || chats.isEmpty) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      await _repository.loadMoreChats();
    } catch (_) {
      // Silently fail pagination.
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refreshChats({bool userInitiated = false}) async {
    if (_isLoading || _isLoadingMore || _isRefreshing) {
      return;
    }
    _isRefreshing = true;
    if (userInitiated) {
      notifyListeners();
    }
    try {
      final limit = chats.isEmpty ? 11 : chats.length;
      await _repository.loadChats(limit: limit);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  void insertChat(ChatListItem chat) {
    _repository.insertChat(chat);
    notifyListeners();
  }

  Future<ChatListItem?> createChat({String? name}) async {
    return _repository.createChat(name: name);
  }

  @override
  void dispose() {
    _repository.removeListener(notifyListeners);
    super.dispose();
  }
}
