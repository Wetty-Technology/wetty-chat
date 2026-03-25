import 'package:flutter/foundation.dart';
import 'dart:convert';

import '../../config/api_config.dart';
import '../models/chat_models.dart';
import '../models/message_models.dart';
import '../services/chat_service.dart';
import '../services/websocket_service.dart';

/// Source of truth for chat list data.
/// Manages pagination and caching.
class ChatRepository extends ChangeNotifier {
  final ChatService _service;

  ChatRepository({ChatService? service}) : _service = service ?? ChatService() {
    _initRealTime();
  }

  void _initRealTime() {
    WebSocketService.instance.events.listen((event) {
      final type = event['type'];
      final payload = event['payload'];
      if (payload == null) return;

      final chatId = payload['chat_id']?.toString() ?? '';
      
      // Find index of the chat
      final index = _chats.indexWhere((c) => c.id == chatId);
      if (index >= 0) {
        final old = _chats[index];
        final msg = MessageItem.fromJson(payload as Map<String, dynamic>);

        if (type == 'message') {
          final senderUid = payload['sender']?['uid'] as int?;
          final createdAt = payload['created_at'] as String?;
          final updated = old.copyWith(
            lastMessage: msg,
            lastMessageAt: createdAt,
            unreadCount: (senderUid != curUserId) 
                ? old.unreadCount + 1 
                : old.unreadCount,
          );
          _chats.removeAt(index);
          _chats.insert(0, updated);
          notifyListeners();
        } else if (type == 'message_updated' || type == 'message_deleted') {
          // If it's the last message, update it
          if (old.lastMessage?.id == msg.id) {
            final updated = old.copyWith(lastMessage: msg);
            _chats[index] = updated;
            notifyListeners();
          }
        }
      }
    });
  }

  List<ChatListItem> _chats = [];
  String? _nextCursor;

  List<ChatListItem> get chats => _chats;
  String? get nextCursor => _nextCursor;
  bool get hasMore => _nextCursor != null && _nextCursor!.isNotEmpty;

  /// Load the first page of chats.
  Future<void> loadChats({int limit = 11}) async {
    final res = await _service.fetchChats(limit: limit);
    _chats = res.chats;
    _nextCursor = res.nextCursor;
  }

  /// Load more chats (next page).
  Future<void> loadMoreChats({int limit = 11}) async {
    if (!hasMore || _chats.isEmpty) return;
    final lastId = _chats.last.id;
    final res = await _service.fetchChats(limit: limit, after: lastId);
    final existingIds = _chats.map((c) => c.id).toSet();
    final newChats =
        res.chats.where((c) => !existingIds.contains(c.id)).toList();
    _chats = [..._chats, ...newChats];
    _nextCursor = res.nextCursor;
  }

  /// Insert a newly created chat at the top.
  void insertChat(ChatListItem chat) {
    _chats.insert(0, chat);
  }

  /// Create a new chat via the service.
  /// Returns the new ChatListItem on success, null on failure.
  Future<ChatListItem?> createChat({String? name}) async {
    final response = await _service.createChat(name: name);
    if (response.statusCode == 201) {
      final body =
          jsonDecode(response.body) as Map<String, dynamic>;
      final id = body['id']?.toString() ?? '';
      final createdName = body['name'] as String?;
      return ChatListItem(id: id, name: createdName);
    }
    throw Exception('Server error: ${response.body}');
  }
}
