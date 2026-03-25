import '../models/message_models.dart';
import '../services/message_service.dart';
import '../services/websocket_service.dart';
import '../../domain/message_store.dart';

/// Source of truth for messages in a single chat.
/// Owns the MessageStore and pagination state.
class MessageRepository {
  final MessageService _service;
  final String chatId;
  final MessageStore store = MessageStore();
  String? nextCursor;

  MessageRepository({required this.chatId, MessageService? service})
    : _service = service ?? MessageService() {
    _initRealTime();
  }

  void _initRealTime() {
    WebSocketService.instance.events.listen((event) {
      final type = event['type'];
      final payload = event['payload'];
      if (payload == null) return;

      // Filter by chatId
      final eventChatId = payload['chat_id']?.toString();
      if (eventChatId != chatId) return;

      final msg = MessageItem.fromJson(payload as Map<String, dynamic>);

      if (type == 'message') {
        store.addMessages([msg]);
      } else if (type == 'message_updated') {
        store.replaceWhere((m) => m.id == msg.id, msg);
      } else if (type == 'message_deleted') {
        store.removeById(msg.id);
      }
    });
  }

  /// Load the initial set of messages.
  Future<void> initLoadMessages() async {
    final res = await _service.fetchMessages(chatId);
    store.clear();
    store.addMessages(res.messages);
    nextCursor = res.nextCursor;
  }

  /// Load older messages (scroll up).
  Future<bool> loadMoreMessages() async {
    if (store.isEmpty || nextCursor == null) return false;
    final res = await _service.fetchMessages(chatId, before: store.oldestId);
    store.addMessages(res.messages);
    nextCursor = res.nextCursor;
    return res.messages.isNotEmpty;
  }

  /// Fetch messages around a specific message (for jump-to-reply).
  Future<void> fetchAround(String messageId) async {
    final msgs = await _service.fetchAround(chatId, messageId);
    store.addMessages(msgs);
  }

  /// Mark message as read on the server.
  Future<void> markAsRead(String messageId) async {
    try {
      await _service.markAsRead(chatId, messageId);
    } catch (e) {
      // Log error but don't block
      print("Failed to sync markAsRead to server: $e");
    }
  }

  /// Send a new message.
  Future<MessageItem> sendMessage(String text, {String? replyToId}) async {
    return await _service.sendMessage(chatId, text, replyToId: replyToId);
  }

  /// Edit an existing message.
  Future<MessageItem> editMessage(String messageId, String newText) async {
    return await _service.editMessage(chatId, messageId, newText);
  }

  /// Delete a message.
  Future<void> deleteMessage(String messageId) async {
    await _service.deleteMessage(chatId, messageId);
  }

  /// Get display items
  List<MessageItem> get displayItems => store.buildDisplayItems();
}
