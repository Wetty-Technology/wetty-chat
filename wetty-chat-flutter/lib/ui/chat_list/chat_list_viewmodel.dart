import 'package:flutter/foundation.dart';

import '../../data/models/chat_models.dart';
import '../../data/repositories/chat_repository.dart';

/// ViewModel for the chat list screen.
/// Manages state and logic; the View just renders.
class ChatListViewModel extends ChangeNotifier {
  final ChatRepository _repository;

  ChatListViewModel({ChatRepository? repository})
    : _repository = repository ?? ChatRepository() {
    _repository.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _repository.removeListener(notifyListeners);
    super.dispose();
  }

  List<ChatListItem> get chats => _repository.chats;
  bool get hasMore => _repository.hasMore;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Load the first page of chats.
  Future<void> initLoadChats() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.loadChats();
      _isLoading = false;
      _errorMessage = null;

      // Print unread counts for debugging
      for (final chat in chats) {
        print(
          "Chat: ${chat.name ?? chat.id}, Unread Count: ${chat.unreadCount}",
        );
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Load the more pages of chats after init.
  Future<void> loadMoreChats() async {
    if (!hasMore || _isLoadingMore || chats.isEmpty) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      await _repository.loadMoreChats();
      // Print unread counts for newly fetched chats
      for (final chat in chats) {
        print(
          "Chat: ${chat.name ?? chat.id}, Unread Count: ${chat.unreadCount}",
        );
      }
    } catch (_) {
      // Silently fail pagination
    }
    _isLoadingMore = false;
    notifyListeners();
  }

  /// Insert a newly created chat at the top.
  void insertChat(ChatListItem chat) {
    _repository.insertChat(chat);
    notifyListeners();
  }

  /// Create a new chat.
  Future<ChatListItem?> createChat({String? name}) async {
    return _repository.createChat(name: name);
  }
}
