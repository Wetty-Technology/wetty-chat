import '../../domain/message_store.dart';
import '../models/message_models.dart';
import '../services/message_service.dart';
import '../services/websocket_service.dart';

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
      if (payload is! Map<String, dynamic>) return;

      final eventChatId = payload['chat_id']?.toString();
      if (eventChatId != chatId) return;

      final message = MessageItem.fromJson(payload);
      if (type == 'message') {
        store.addMessages([message]);
      } else if (type == 'message_updated') {
        store.replaceWhere((item) => item.id == message.id, message);
      } else if (type == 'message_deleted') {
        store.removeById(message.id);
      }
    });
  }

  Future<List<MessageItem>> initLoadMessages({int limit = 100}) async {
    final response = await _service.fetchMessages(chatId, max: limit);
    store.clear();
    store.addMessages(response.messages);
    nextCursor = response.nextCursor;
    return store.newest(limit: limit);
  }

  Future<List<MessageItem>> refreshLatestWindow({int limit = 100}) async {
    final response = await _service.fetchMessages(chatId, max: limit);
    store.addMessages(response.messages);
    nextCursor = response.nextCursor;
    return store.newest(limit: limit);
  }

  List<MessageItem> getLatestWindow({int limit = 100}) {
    return store.newest(limit: limit);
  }

  List<MessageItem> rebuildWindow({
    required int limit,
    required int anchorMessageId,
    bool liveEdge = false,
  }) {
    if (liveEdge) {
      return getLatestWindow(limit: limit);
    }

    final slice = store.getWindowAround(
      anchorMessageId,
      before: limit ~/ 2,
      after: limit ~/ 2,
    );
    if (slice.isEmpty) {
      return getLatestWindow(limit: limit);
    }
    if (slice.length <= limit) {
      return slice;
    }
    return slice.sublist(0, limit);
  }

  Future<List<MessageItem>> extendOlderWindow(
    int oldestVisibleId, {
    int pageSize = 50,
  }) async {
    final cached = store.takeOlderAdjacent(oldestVisibleId, pageSize);
    if (cached.isNotEmpty) return cached;

    final response = await _service.fetchMessages(
      chatId,
      before: oldestVisibleId,
      max: pageSize,
    );
    store.addOlderPage(
      olderThanId: oldestVisibleId,
      items: response.messages,
    );
    nextCursor = response.nextCursor;
    return store.takeOlderAdjacent(oldestVisibleId, pageSize);
  }

  Future<List<MessageItem>> extendNewerWindow(
    int newestVisibleId, {
    int pageSize = 50,
  }) async {
    final cached = store.takeNewerAdjacent(newestVisibleId, pageSize);
    if (cached.isNotEmpty) return cached;

    final response = await _service.fetchMessages(
      chatId,
      after: newestVisibleId,
      max: pageSize,
    );
    store.addNewerPage(
      newerThanId: newestVisibleId,
      items: response.messages,
    );
    return store.takeNewerAdjacent(newestVisibleId, pageSize);
  }

  Future<List<MessageItem>> getWindowAround(
    int messageId, {
    int before = 75,
    int after = 75,
  }) async {
    var cached = store.getWindowAround(
      messageId,
      before: before,
      after: after,
    );
    if (cached.isNotEmpty) return cached;

    final response = await _service.fetchMessages(
      chatId,
      around: messageId,
      max: before + after + 1,
    );
    store.addMessages(response.messages);
    nextCursor = response.nextCursor;
    cached = store.getWindowAround(
      messageId,
      before: before,
      after: after,
    );
    return cached;
  }

  int? findUnreadBoundaryId(int unreadCount) {
    if (unreadCount <= 0) return null;
    return store.findNthNewestId(unreadCount - 1);
  }

  bool hasOlderAdjacent(int oldestVisibleId) {
    return store.takeOlderAdjacent(oldestVisibleId, 1).isNotEmpty ||
        nextCursor != null;
  }

  bool hasNewerAdjacent(int newestVisibleId) {
    final latestCachedId = store.newestId;
    if (latestCachedId != null && latestCachedId > newestVisibleId) {
      return true;
    }
    return store.takeNewerAdjacent(newestVisibleId, 1).isNotEmpty;
  }

  int? findIndexInWindow({
    required int newestVisibleId,
    required int oldestVisibleId,
    required int messageId,
  }) {
    return store.findIndexInSlice(
      newestId: newestVisibleId,
      oldestId: oldestVisibleId,
      messageId: messageId,
    );
  }

  Future<void> markAsRead(int messageId) async {
    try {
      await _service.markMessagesAsRead(chatId, messageId);
    } catch (_) {}
  }

  Future<MessageItem> sendMessage(
    String text, {
    int? replyToId,
    List<String>? attachmentIds,
  }) async {
    final message = await _service.sendMessage(
      chatId,
      text,
      replyToId: replyToId,
      attachmentIds: attachmentIds ?? const <String>[],
    );
    store.addMessages([message]);
    return message;
  }

  Future<MessageItem> editMessage(int messageId, String newText) async {
    final message = await _service.editMessage(chatId, messageId, newText);
    store.replaceWhere((item) => item.id == messageId, message);
    return message;
  }

  Future<void> deleteMessage(int messageId) async {
    await _service.deleteMessage(chatId, messageId);
    store.removeById(messageId);
  }

  List<MessageItem> get displayItems => store.buildDisplayItems();
}
