import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_config.dart';
import '../../models/chat_models.dart';
import '../../models/message_models.dart';
import 'chat_api_service.dart';

/// Source of truth for chat list data.
/// Manages pagination and caching.
class ChatRepository extends ChangeNotifier {
  final ChatApiService _service;

  ChatRepository({ChatApiService? service})
    : _service = service ?? ChatApiService();

  List<ChatListItem> _chats = [];
  String? _nextCursor;
  bool _isRealtimeRefreshing = false;

  List<ChatListItem> get chats => _chats;
  String? get nextCursor => _nextCursor;
  bool get hasMore => _nextCursor != null && _nextCursor!.isNotEmpty;

  /// Load the first page of chats.
  Future<void> loadChats({int limit = 11}) async {
    final res = await _service.fetchChats(limit: limit);
    _chats = res.chats;
    _nextCursor = res.nextCursor;
    notifyListeners();
  }

  /// Load more chats (next page).
  Future<void> loadMoreChats({int limit = 11}) async {
    if (!hasMore || _chats.isEmpty) return;
    final lastId = _chats.last.id;
    final res = await _service.fetchChats(limit: limit, after: lastId);
    final existingIds = _chats.map((c) => c.id).toSet();
    final newChats = res.chats
        .where((c) => !existingIds.contains(c.id))
        .toList();
    _chats = [..._chats, ...newChats];
    _nextCursor = res.nextCursor;
    notifyListeners();
  }

  /// Insert a newly created chat at the top.
  void insertChat(ChatListItem chat) {
    _chats.insert(0, chat);
    notifyListeners();
  }

  /// Create a new chat via the service.
  /// Returns the new ChatListItem on success, null on failure.
  Future<ChatListItem?> createChat({String? name}) async {
    final response = await _service.createChat(name: name);
    if (response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final id = body['id']?.toString() ?? '';
      final createdName = body['name'] as String?;
      return ChatListItem(id: id, name: createdName);
    }
    throw Exception('Server error: ${response.body}');
  }

  void applyRealtimeEvent(Map<String, dynamic> event) {
    final type = event['type'];
    final payload = event['payload'];
    if (payload is! Map<String, dynamic>) return;

    final chatId = payload['chatId']?.toString() ?? '';
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) {
      if (type == 'message') {
        unawaited(_refreshForRealtimeMiss());
      }
      return;
    }

    final previous = _chats[index];
    final message = MessageItem.fromJson(payload);
    if (type == 'message') {
      final senderUid = payload['sender']?['uid'] as int?;
      final createdAt = payload['createdAt'] as String?;
      final updated = previous.copyWith(
        lastMessage: message,
        lastMessageAt: createdAt,
        unreadCount: senderUid != ApiSession.currentUserId
            ? previous.unreadCount + 1
            : previous.unreadCount,
      );
      _chats
        ..removeAt(index)
        ..insert(0, updated);
      notifyListeners();
      return;
    }

    if (type == 'messageUpdated' || type == 'messageDeleted') {
      if (previous.lastMessage?.id != message.id) return;
      _chats[index] = previous.copyWith(lastMessage: message);
      notifyListeners();
    }
  }

  Future<void> _refreshForRealtimeMiss() async {
    if (_isRealtimeRefreshing) return;

    _isRealtimeRefreshing = true;
    try {
      final limit = _chats.isEmpty ? 11 : _chats.length;
      await loadChats(limit: limit);
    } catch (_) {
      // Ignore realtime refresh failures and rely on the next manual refresh.
    } finally {
      _isRealtimeRefreshing = false;
    }
  }
}
