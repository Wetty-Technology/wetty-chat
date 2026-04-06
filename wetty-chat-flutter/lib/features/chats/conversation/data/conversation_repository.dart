import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/messages_api_models.dart';
import '../../../../core/api/models/websocket_api_models.dart';
import '../../models/message_api_mapper.dart';
import '../../models/message_models.dart';
import '../domain/conversation_message.dart';
import '../domain/conversation_scope.dart';
import 'message_api_service.dart';

class ConversationRepository {
  ConversationRepository({
    required this.scope,
    required MessageApiService service,
  }) : _service = service;

  static const int defaultWindowSize = 100;
  static const int pageSize = 40;
  static const int maxRenderEntries = 350;

  final ConversationScope scope;
  final MessageApiService _service;

  final Map<String, ConversationMessage> _messagesByStableKey = {};
  final Map<int, String> _stableKeyByServerId = {};
  final Map<String, String> _stableKeyByClientGeneratedId = {};
  final List<String> _orderedStableKeys = <String>[];
  final Map<String, ConversationMessage> _optimisticSnapshots = {};

  bool _hasReachedOldest = false;
  bool _hasReachedNewest = false;

  Future<List<ConversationMessage>> loadLatestWindow({
    int limit = defaultWindowSize,
  }) async {
    final response = await _service.fetchConversationMessages(
      scope,
      max: limit,
    );
    _mergeDtos(response.messages);
    _hasReachedNewest = true;
    _hasReachedOldest = response.messages.length < limit;
    final keys = _latestWindowStableKeys(limit);
    return _messagesForWindow(keys);
  }

  Future<List<ConversationMessage>> refreshLatestWindow({
    int limit = defaultWindowSize,
  }) async {
    final response = await _service.fetchConversationMessages(
      scope,
      max: limit,
    );
    _mergeDtos(response.messages);
    _hasReachedNewest = true;
    _hasReachedOldest = response.messages.length < limit;
    final keys = _latestWindowStableKeys(limit);
    return _messagesForWindow(keys);
  }

  Future<List<ConversationMessage>> loadAroundMessage(
    int messageId, {
    int before = defaultWindowSize ~/ 2,
    int after = defaultWindowSize ~/ 2,
  }) async {
    if (!_containsServerMessage(messageId)) {
      final response = await _service.fetchConversationMessages(
        scope,
        around: messageId,
        max: before + after + 1,
      );
      _mergeDtos(response.messages);
    }
    final keys = _windowKeysAroundServerMessage(
      messageId,
      before: before,
      after: after,
    );
    return _messagesForWindow(keys);
  }

  Future<int?> resolveFirstUnreadMessageId(int lastReadMessageId) async {
    final response = await _service.fetchConversationMessages(
      scope,
      after: lastReadMessageId,
      max: 1,
    );
    _mergeDtos(response.messages);
    if (response.messages.isEmpty) {
      return null;
    }
    return response.messages.first.id;
  }

  Future<List<ConversationMessage>> extendOlder({
    required String anchorStableKey,
    int pageSize = ConversationRepository.pageSize,
  }) async {
    final anchor = _messagesByStableKey[anchorStableKey];
    final oldestId = anchor?.serverMessageId;
    if (oldestId == null) {
      return const <ConversationMessage>[];
    }

    final response = await _service.fetchConversationMessages(
      scope,
      before: oldestId,
      max: pageSize,
    );
    _mergeDtos(response.messages);
    if (response.messages.length < pageSize) {
      _hasReachedOldest = true;
    }
    return response.messages
        .map((dto) => _messageForServerId(dto.id))
        .whereType<ConversationMessage>()
        .toList(growable: false);
  }

  Future<List<ConversationMessage>> extendNewer({
    required String anchorStableKey,
    int pageSize = ConversationRepository.pageSize,
  }) async {
    final anchor = _messagesByStableKey[anchorStableKey];
    final newestId = anchor?.serverMessageId;
    if (newestId == null) {
      return const <ConversationMessage>[];
    }

    final response = await _service.fetchConversationMessages(
      scope,
      after: newestId,
      max: pageSize,
    );
    _mergeDtos(response.messages);
    if (response.messages.length < pageSize) {
      _hasReachedNewest = true;
    }
    return response.messages
        .map((dto) => _messageForServerId(dto.id))
        .whereType<ConversationMessage>()
        .toList(growable: false);
  }

  bool hasOlderOutsideWindow(List<String> windowStableKeys) {
    if (windowStableKeys.isEmpty) {
      return false;
    }
    final oldestIndex = _orderedStableKeys.indexOf(windowStableKeys.first);
    return oldestIndex > 0 || !_hasReachedOldest;
  }

  bool hasNewerOutsideWindow(List<String> windowStableKeys) {
    if (windowStableKeys.isEmpty) {
      return false;
    }
    final newestIndex = _orderedStableKeys.indexOf(windowStableKeys.last);
    return newestIndex >= 0 && newestIndex < _orderedStableKeys.length - 1 ||
        !_hasReachedNewest;
  }

  List<String> latestWindowStableKeys({int limit = defaultWindowSize}) =>
      _latestWindowStableKeys(limit);

  List<String> trimWindowAroundAnchor(
    List<String> stableKeys, {
    required int? anchorMessageId,
    int maxEntries = maxRenderEntries,
  }) {
    if (stableKeys.length <= maxEntries) {
      return stableKeys;
    }
    if (anchorMessageId == null) {
      return stableKeys.sublist(stableKeys.length - maxEntries);
    }

    final anchorKey = _stableKeyByServerId[anchorMessageId];
    if (anchorKey == null) {
      return stableKeys.sublist(stableKeys.length - maxEntries);
    }

    final anchorIndex = stableKeys.indexOf(anchorKey);
    if (anchorIndex < 0) {
      return stableKeys.sublist(stableKeys.length - maxEntries);
    }

    final before = maxEntries ~/ 2;
    final start = (anchorIndex - before).clamp(0, stableKeys.length);
    final end = (start + maxEntries).clamp(0, stableKeys.length);
    final adjustedStart = (end - maxEntries).clamp(0, stableKeys.length);
    return stableKeys.sublist(adjustedStart, end);
  }

  List<String> prependWindowPage(
    List<String> currentWindow,
    String oldestStableKey,
  ) {
    final oldestIndex = _orderedStableKeys.indexOf(oldestStableKey);
    if (oldestIndex <= 0) {
      return currentWindow;
    }
    final start = (oldestIndex - pageSize).clamp(0, oldestIndex);
    return _orderedStableKeys.sublist(start, oldestIndex) + currentWindow;
  }

  List<String> appendWindowPage(
    List<String> currentWindow,
    String newestStableKey,
  ) {
    final newestIndex = _orderedStableKeys.indexOf(newestStableKey);
    if (newestIndex < 0 || newestIndex >= _orderedStableKeys.length - 1) {
      return currentWindow;
    }
    final end = (newestIndex + 1 + pageSize).clamp(
      0,
      _orderedStableKeys.length,
    );
    return currentWindow + _orderedStableKeys.sublist(newestIndex + 1, end);
  }

  int? findWindowIndex(List<String> windowStableKeys, int messageId) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return null;
    }
    return windowStableKeys.indexOf(stableKey);
  }

  Future<void> markAsRead(int messageId) {
    return _service.markMessagesAsRead(scope.chatId, messageId);
  }

  ConversationMessage insertOptimisticSend({
    required Sender sender,
    required String text,
    required List<AttachmentItem> attachments,
    required String clientGeneratedId,
    int? replyToId,
  }) {
    final localMessage = ConversationMessage(
      scope: scope,
      localMessageId: 'local-${DateTime.now().microsecondsSinceEpoch}',
      clientGeneratedId: clientGeneratedId,
      sender: sender,
      message: text,
      messageType: 'text',
      createdAt: DateTime.now().toUtc(),
      isEdited: false,
      isDeleted: false,
      replyRootId: replyToId,
      hasAttachments: attachments.isNotEmpty,
      replyToMessage: _replyToMessageForId(replyToId),
      attachments: attachments,
      threadInfo: null,
      deliveryState: ConversationDeliveryState.sending,
    );
    _upsertMessage(localMessage, appendLocalOnly: true);
    return localMessage;
  }

  Future<ConversationMessage> commitSend({
    required String clientGeneratedId,
    required String text,
    required List<String> attachmentIds,
    int? replyToId,
  }) async {
    final response = await _service.sendConversationMessage(
      scope,
      text,
      replyToId: replyToId,
      attachmentIds: attachmentIds,
      clientGeneratedId: clientGeneratedId,
    );
    return _mergeMessage(
      response.toConversation(scope),
      preferredState: ConversationDeliveryState.sent,
    );
  }

  void markSendFailed(String clientGeneratedId) {
    final stableKey = _stableKeyByClientGeneratedId[clientGeneratedId];
    if (stableKey == null) {
      return;
    }
    final message = _messagesByStableKey[stableKey];
    if (message == null) {
      return;
    }
    _messagesByStableKey[stableKey] = message.copyWith(
      deliveryState: ConversationDeliveryState.failed,
    );
  }

  Future<ConversationMessage> retryFailedSend(
    ConversationMessage message,
  ) async {
    final optimistic = message.copyWith(
      deliveryState: ConversationDeliveryState.sending,
    );
    _messagesByStableKey[optimistic.stableKey] = optimistic;
    return commitSend(
      clientGeneratedId: optimistic.clientGeneratedId,
      text: optimistic.message ?? '',
      attachmentIds: optimistic.attachments.map((item) => item.id).toList(),
      replyToId: optimistic.replyRootId,
    );
  }

  void discardFailedMessage(ConversationMessage message) {
    _removeStableKey(message.stableKey);
  }

  ConversationMessage? beginOptimisticEdit(int messageId) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return null;
    }
    final message = _messagesByStableKey[stableKey];
    if (message == null) {
      return null;
    }
    _optimisticSnapshots[stableKey] = message;
    final updating = message.copyWith(
      deliveryState: ConversationDeliveryState.editing,
    );
    _messagesByStableKey[stableKey] = updating;
    return updating;
  }

  Future<ConversationMessage> commitEdit(int messageId, String newText) async {
    final response = await _service.editMessage(
      scope.chatId,
      messageId,
      newText,
    );
    return _mergeMessage(
      response.toConversation(scope),
      preferredState: ConversationDeliveryState.sent,
    );
  }

  void rollbackEdit(int messageId) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return;
    }
    final snapshot = _optimisticSnapshots.remove(stableKey);
    if (snapshot != null) {
      _messagesByStableKey[stableKey] = snapshot;
    }
  }

  ConversationMessage? beginOptimisticDelete(int messageId) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return null;
    }
    final message = _messagesByStableKey[stableKey];
    if (message == null) {
      return null;
    }
    _optimisticSnapshots[stableKey] = message;
    final deleting = message.copyWith(
      deliveryState: ConversationDeliveryState.deleting,
    );
    _messagesByStableKey[stableKey] = deleting;
    return deleting;
  }

  Future<void> commitDelete(int messageId) async {
    await _service.deleteMessage(scope.chatId, messageId);
    _tombstoneMessage(messageId);
  }

  void rollbackDelete(int messageId) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return;
    }
    final snapshot = _optimisticSnapshots.remove(stableKey);
    if (snapshot != null) {
      _messagesByStableKey[stableKey] = snapshot;
    }
  }

  bool applyRealtimeEvent(ApiWsEvent event) {
    final payload = switch (event) {
      MessageCreatedWsEvent(:final payload) => payload,
      MessageUpdatedWsEvent(:final payload) => payload,
      MessageDeletedWsEvent(:final payload) => payload,
      _ => null,
    };
    if (payload == null || payload.chatId.toString() != scope.chatId) {
      return false;
    }
    if (scope.threadRootId != null &&
        payload.replyRootId?.toString() != scope.threadRootId) {
      return false;
    }

    if (event is MessageDeletedWsEvent) {
      _mergeMessage(
        payload.toConversation(scope),
        preferredState: ConversationDeliveryState.sent,
      );
      _tombstoneMessage(payload.id);
      return true;
    }

    _mergeMessage(
      payload.toConversation(scope),
      preferredState: ConversationDeliveryState.sent,
    );
    return true;
  }

  List<ConversationMessage> messagesForWindow(List<String> stableKeys) =>
      _messagesForWindow(stableKeys);

  ConversationMessage? messageForServerId(int messageId) =>
      _messageForServerId(messageId);

  ConversationMessage _mergeMessage(
    ConversationMessage incoming, {
    required ConversationDeliveryState preferredState,
  }) {
    final stableKey = _stableKeyByServerId[incoming.serverMessageId ?? -1];
    if (stableKey != null) {
      final previous = _messagesByStableKey[stableKey];
      final merged = incoming.copyWith(
        localMessageId: previous?.localMessageId,
        deliveryState: preferredState,
      );
      _messagesByStableKey[stableKey] = merged;
      _optimisticSnapshots.remove(stableKey);
      return merged;
    }

    final optimisticKey =
        _stableKeyByClientGeneratedId[incoming.clientGeneratedId];
    if (optimisticKey != null) {
      final previous = _messagesByStableKey[optimisticKey];
      final merged = incoming.copyWith(
        localMessageId: previous?.localMessageId,
        deliveryState: preferredState,
      );
      final previousIndex = _orderedStableKeys.indexOf(optimisticKey);
      if (previousIndex >= 0) {
        _orderedStableKeys[previousIndex] = merged.stableKey;
      } else {
        _insertOrderedStableKey(merged.stableKey, merged.serverMessageId);
      }
      _messagesByStableKey.remove(optimisticKey);
      _messagesByStableKey[merged.stableKey] = merged;
      _stableKeyByServerId[merged.serverMessageId!] = merged.stableKey;
      _stableKeyByClientGeneratedId[merged.clientGeneratedId] =
          merged.stableKey;
      _optimisticSnapshots.remove(optimisticKey);
      return merged;
    }

    final merged = incoming.copyWith(deliveryState: preferredState);
    _upsertMessage(merged);
    return merged;
  }

  void _mergeDtos(List<MessageItemDto> messages) {
    for (final dto in messages) {
      _mergeMessage(
        dto.toConversation(scope),
        preferredState: ConversationDeliveryState.sent,
      );
    }
  }

  void _upsertMessage(
    ConversationMessage message, {
    bool appendLocalOnly = false,
  }) {
    _messagesByStableKey[message.stableKey] = message;
    _stableKeyByClientGeneratedId[message.clientGeneratedId] =
        message.stableKey;
    final serverMessageId = message.serverMessageId;
    if (serverMessageId != null) {
      _stableKeyByServerId[serverMessageId] = message.stableKey;
      _insertOrderedStableKey(message.stableKey, serverMessageId);
      return;
    }
    if (appendLocalOnly && !_orderedStableKeys.contains(message.stableKey)) {
      _orderedStableKeys.add(message.stableKey);
    }
  }

  void _insertOrderedStableKey(String stableKey, int? serverMessageId) {
    final existingIndex = _orderedStableKeys.indexOf(stableKey);
    if (existingIndex >= 0) {
      return;
    }
    if (serverMessageId == null || _orderedStableKeys.isEmpty) {
      _orderedStableKeys.add(stableKey);
      return;
    }
    final insertAt = _orderedStableKeys.indexWhere((candidateKey) {
      final candidateId = _messagesByStableKey[candidateKey]?.serverMessageId;
      return candidateId != null && candidateId > serverMessageId;
    });
    if (insertAt < 0) {
      _orderedStableKeys.add(stableKey);
    } else {
      _orderedStableKeys.insert(insertAt, stableKey);
    }
  }

  void _removeStableKey(String stableKey) {
    final message = _messagesByStableKey.remove(stableKey);
    if (message == null) {
      return;
    }
    _orderedStableKeys.remove(stableKey);
    if (message.serverMessageId != null) {
      _stableKeyByServerId.remove(message.serverMessageId);
    }
    _stableKeyByClientGeneratedId.remove(message.clientGeneratedId);
  }

  List<String> _latestWindowStableKeys(int limit) {
    if (_orderedStableKeys.isEmpty) {
      return const <String>[];
    }
    final start = (_orderedStableKeys.length - limit).clamp(
      0,
      _orderedStableKeys.length,
    );
    return _orderedStableKeys.sublist(start);
  }

  List<String> _windowKeysAroundServerMessage(
    int messageId, {
    required int before,
    required int after,
  }) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return const <String>[];
    }
    final index = _orderedStableKeys.indexOf(stableKey);
    if (index < 0) {
      return const <String>[];
    }
    final start = (index - before).clamp(0, _orderedStableKeys.length);
    final end = (index + after + 1).clamp(0, _orderedStableKeys.length);
    return _orderedStableKeys.sublist(start, end);
  }

  List<ConversationMessage> _messagesForWindow(List<String> stableKeys) {
    return stableKeys
        .map((stableKey) => _messagesByStableKey[stableKey])
        .whereType<ConversationMessage>()
        .toList(growable: false);
  }

  ConversationMessage? _messageForServerId(int messageId) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return null;
    }
    return _messagesByStableKey[stableKey];
  }

  bool _containsServerMessage(int messageId) =>
      _stableKeyByServerId.containsKey(messageId);

  ReplyToMessage? _replyToMessageForId(int? replyToId) {
    if (replyToId == null) {
      return null;
    }
    final message = _messageForServerId(replyToId);
    if (message == null) {
      return null;
    }
    return ReplyToMessage(
      id: replyToId,
      message: message.message,
      sender: message.sender,
      isDeleted: message.isDeleted,
    );
  }

  void _tombstoneMessage(int messageId) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return;
    }
    final current = _messagesByStableKey[stableKey];
    if (current == null) {
      return;
    }
    _messagesByStableKey[stableKey] = current.copyWith(
      isDeleted: true,
      message: null,
      attachments: const <AttachmentItem>[],
      hasAttachments: false,
      deliveryState: ConversationDeliveryState.sent,
    );
  }
}

final conversationRepositoryProvider =
    Provider.family<ConversationRepository, ConversationScope>((ref, scope) {
      return ConversationRepository(
        scope: scope,
        service: ref.read(messageApiServiceProvider),
      );
    });
