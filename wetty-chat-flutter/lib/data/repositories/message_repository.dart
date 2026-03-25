import '../models/message_models.dart';
import '../services/message_service.dart';
import '../../domain/message_store.dart';

/// Source of truth for messages in a single chat.
/// Owns the MessageStore and pagination state.
class MessageRepository {
  final MessageService _service;
  final String chatId;
  final String? threadId;
  final MessageStore store = MessageStore();
  String? nextCursor;

  MessageRepository({
    required this.chatId,
    this.threadId,
    MessageService? service,
  }) : _service = service ?? MessageService();

  /// Load the initial set of messages.
  Future<void> loadMessages() async {
    final res = await _service.fetchMessages(chatId, threadId: threadId);
    store.clear();
    store.addMessages(res.messages);
    nextCursor = res.nextCursor;
  }

  /// Load older messages (scroll up).
  Future<bool> loadMoreMessages() async {
    if (store.isEmpty || nextCursor == null) return false;
    final res = await _service.fetchMessages(
      chatId,
      before: store.oldestId,
      threadId: threadId,
    );
    store.addMessages(res.messages);
    nextCursor = res.nextCursor;
    return res.messages.isNotEmpty;
  }

  /// Fetch messages around a specific message (for jump-to-reply).
  Future<void> fetchAround(String messageId) async {
    final msgs = await _service.fetchAround(
      chatId,
      messageId,
      threadId: threadId,
    );
    store.addMessages(msgs);
  }

  /// Send a new message.
  Future<MessageItem> sendMessage(
    String text, {
    String? replyToId,
    List<String> attachmentIds = const [],
  }) async {
    final res = await _service.sendMessage(
      chatId,
      text,
      replyToId: replyToId,
      threadId: threadId,
      attachmentIds: attachmentIds,
    );
    store.addMessages([res]);
    return res;
  }

  /// Edit an existing message.
  Future<MessageItem> editMessage(
    String messageId,
    String newText, {
    List<String> attachmentIds = const [],
  }) async {
    final updated = await _service.editMessage(
      chatId,
      messageId,
      newText,
      attachmentIds: attachmentIds,
    );
    store.replaceWhere((m) => m.id == messageId, updated);
    return updated;
  }

  /// Delete a message.
  Future<void> deleteMessage(String messageId) async {
    await _service.deleteMessage(chatId, messageId);
    store.removeById(messageId);
  }

  Future<void> markAsRead(String messageId) async {
    await _service.markAsRead(chatId, messageId);
  }

  void applyRealtimeMessage(MessageItem message) {
    if (!_matchesCurrentFeed(message)) {
      return;
    }
    store.upsert(message);
  }

  void applyRealtimeUpdate(MessageItem message) {
    if (!_matchesCurrentFeed(message) && store.findById(message.id) == null) {
      return;
    }
    store.upsert(message);
  }

  void applyRealtimeDeletion(MessageItem message) {
    if (store.findById(message.id) == null) {
      return;
    }
    store.removeById(message.id);
  }

  /// Get display items
  List<MessageItem> get displayItems => store.buildDisplayItems();

  bool _matchesCurrentFeed(MessageItem message) {
    if (message.chatId != chatId) {
      return false;
    }
    if (threadId != null) {
      return message.replyRootId == threadId;
    }
    return message.replyRootId == null;
  }
}
