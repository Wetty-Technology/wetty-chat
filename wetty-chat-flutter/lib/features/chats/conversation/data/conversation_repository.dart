import 'dart:developer' as developer;

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
  static const int pageSize = 50;

  /// Safety net: absolute max window size in [trimWindow]. Should never fire
  /// in practice — if you see "trimWindow: safety cap" in logs, something is
  /// broken upstream.
  static const int maxRenderEntries = 5000;

  /// Trigger: when the window exceeds this after a load, the view model stops
  /// the scroll, trims to [trimTarget], and transitions to topPreferred mode.
  static const int softWindowCap = 2500;

  /// Floor: the window size after a trim. Biased 2/3 older so the user has
  /// context ahead. Cycle: grow from trimTarget → softWindowCap, trim, repeat.
  static const int trimTarget = 300;

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
    final alreadyCached = _containsServerMessage(messageId);
    final hasCachedWindow = _hasWindowAroundServerMessage(
      messageId,
      before: before,
      after: after,
    );
    developer.log(
      'loadAroundMessage: msgId=$messageId, '
      'alreadyCached=$alreadyCached, '
      'hasCachedWindow=$hasCachedWindow, '
      'stableKey=${_stableKeyByServerId[messageId]}',
      name: 'ConvRepo',
    );
    if (!hasCachedWindow) {
      final response = await _service.fetchConversationMessages(
        scope,
        around: messageId,
        max: before + after + 1,
      );
      _mergeDtos(response.messages);
      developer.log(
        'loadAroundMessage: fetched ${response.messages.length} msgs, '
        'stableKey after merge=${_stableKeyByServerId[messageId]}, '
        'containsNow=${_containsServerMessage(messageId)}',
        name: 'ConvRepo',
      );
    }
    final keys = _windowKeysAroundServerMessage(
      messageId,
      before: before,
      after: after,
    );
    developer.log(
      'loadAroundMessage: produced ${keys.length} window keys '
      '(first=${keys.firstOrNull}, last=${keys.lastOrNull})',
      name: 'ConvRepo',
    );
    return _messagesForWindow(keys);
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

  List<ConversationMessage> cachedWindowAroundMessage(
    int messageId, {
    int before = defaultWindowSize ~/ 2,
    int after = defaultWindowSize ~/ 2,
  }) {
    final keys = _windowKeysAroundServerMessage(
      messageId,
      before: before,
      after: after,
    );
    return _messagesForWindow(keys);
  }

  Future<List<ConversationMessage>> refreshAroundMessage(
    int messageId, {
    int before = defaultWindowSize ~/ 2,
    int after = defaultWindowSize ~/ 2,
  }) async {
    final response = await _service.fetchConversationMessages(
      scope,
      around: messageId,
      max: before + after + 1,
    );
    if (response.messages.isEmpty) {
      return const <ConversationMessage>[];
    }
    _mergeDtos(response.messages);
    final keys = _windowKeysAroundServerMessage(
      messageId,
      before: before,
      after: after,
    );
    return _messagesForWindow(keys);
  }

  /// Trim a window to [maxEntries] entries centered around [anchorKey],
  /// biased toward the [olderBias] direction. Returns null if the anchor is
  /// not found in [stableKeys].
  List<String>? trimWindowAroundKey(
    List<String> stableKeys, {
    required String anchorKey,
    int maxEntries = trimTarget,
  }) {
    if (stableKeys.length <= maxEntries) return stableKeys;
    final anchorIndex = stableKeys.indexOf(anchorKey);
    if (anchorIndex < 0) return null;
    // Bias toward older side (user is scrolling up).
    final keepBefore = (maxEntries * 2) ~/ 3;
    final start = (anchorIndex - keepBefore).clamp(0, stableKeys.length);
    final end = (start + maxEntries).clamp(0, stableKeys.length);
    final adjustedStart = (end - maxEntries).clamp(0, stableKeys.length);
    developer.log(
      'trimWindowAroundKey: ${stableKeys.length} → $maxEntries, '
      'anchor=$anchorKey at $anchorIndex, '
      'result=[$adjustedStart..$end)',
      name: 'ConvRepo',
    );
    return stableKeys.sublist(adjustedStart, end);
  }

  /// Safety cap: if the window somehow exceeds [maxEntries], keep the newest.
  ///
  /// Directional trimming is handled by the callers ([prependWindowPage] /
  /// [appendWindowPage] cap via the view-model before reaching here), so this
  /// is only a last-resort guard.
  List<String> trimWindow(
    List<String> stableKeys, {
    int maxEntries = maxRenderEntries,
  }) {
    if (stableKeys.length <= maxEntries) {
      return stableKeys;
    }
    developer.log(
      'trimWindow: safety cap ${stableKeys.length} → $maxEntries (newest)',
      name: 'ConvRepo',
    );
    return stableKeys.sublist(stableKeys.length - maxEntries);
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
    final index = windowStableKeys.indexOf(stableKey);
    return index >= 0 ? index : null;
  }

  ConversationMessage? messageForStableKey(String stableKey) =>
      _messagesByStableKey[stableKey];

  Future<void> markAsRead(int messageId) {
    return _service.markMessagesAsRead(scope.chatId, messageId);
  }

  Future<ConversationMessage> toggleReaction({
    required int messageId,
    required String emoji,
  }) async {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      throw StateError('Message not found: $messageId');
    }
    final message = _messagesByStableKey[stableKey];
    if (message == null) {
      throw StateError('Message not found: $messageId');
    }
    if (_isStickerMessage(message)) {
      throw UnsupportedError('Sticker reactions are not supported');
    }

    final snapshot = message;
    _optimisticSnapshots[stableKey] = snapshot;
    final updatedReactions = _toggleReactionLocal(message, emoji);
    final optimistic = message.copyWith(reactions: updatedReactions);
    _messagesByStableKey[stableKey] = optimistic;

    try {
      final currentlyReacted = message.reactions.any(
        (reaction) => reaction.emoji == emoji && reaction.reactedByMe == true,
      );
      if (currentlyReacted) {
        await _service.deleteReaction(scope, messageId, emoji);
      } else {
        await _service.putReaction(scope, messageId, emoji);
      }
      _optimisticSnapshots.remove(stableKey);
      return optimistic;
    } catch (_) {
      _messagesByStableKey[stableKey] = snapshot;
      _optimisticSnapshots.remove(stableKey);
      rethrow;
    }
  }

  ConversationMessage insertOptimisticSend({
    required Sender sender,
    required String text,
    required String messageType,
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
      messageType: messageType,
      sticker: null,
      createdAt: DateTime.now().toUtc(),
      isEdited: false,
      isDeleted: false,
      replyRootId: replyToId,
      hasAttachments: attachments.isNotEmpty,
      replyToMessage: _replyToMessageForId(replyToId),
      attachments: attachments,
      reactions: const <ReactionSummary>[],
      mentions: const <MentionInfo>[],
      threadInfo: null,
      deliveryState: ConversationDeliveryState.sending,
    );
    _upsertMessage(localMessage, appendLocalOnly: true);
    return localMessage;
  }

  Future<ConversationMessage> commitSend({
    required String clientGeneratedId,
    required String text,
    required String messageType,
    required List<String> attachmentIds,
    int? replyToId,
  }) async {
    final response = await _service.sendConversationMessage(
      scope,
      text,
      messageType: messageType,
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
      messageType: optimistic.messageType,
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
    return switch (event) {
      MessageCreatedWsEvent(:final payload) => _applyMessageEvent(
        payload,
        deleted: false,
      ),
      MessageUpdatedWsEvent(:final payload) => _applyMessageEvent(
        payload,
        deleted: false,
      ),
      MessageDeletedWsEvent(:final payload) => _applyMessageEvent(
        payload,
        deleted: true,
      ),
      ReactionUpdatedWsEvent(:final payload) => _applyReactionEvent(payload),
      _ => false,
    };
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
        reactions: _mergeReactions(previous?.reactions, incoming.reactions),
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
        reactions: _mergeReactions(previous?.reactions, incoming.reactions),
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

  bool _applyMessageEvent(MessageItemDto payload, {required bool deleted}) {
    if (payload.chatId.toString() != scope.chatId) {
      return false;
    }
    if (scope.threadRootId != null &&
        payload.replyRootId?.toString() != scope.threadRootId) {
      return false;
    }

    if (deleted) {
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

  bool _applyReactionEvent(ReactionUpdatePayloadDto payload) {
    if (payload.chatId.toString() != scope.chatId) {
      return false;
    }

    final stableKey = _stableKeyByServerId[payload.messageId];
    if (stableKey == null) {
      return false;
    }
    final message = _messagesByStableKey[stableKey];
    if (message == null || !_messageBelongsToScope(message)) {
      return false;
    }

    _messagesByStableKey[stableKey] = message.copyWith(
      reactions: _mergeReactions(
        message.reactions,
        payload.reactions.map((reaction) => reaction.toDomain()).toList(),
      ),
    );
    _optimisticSnapshots.remove(stableKey);
    return true;
  }

  bool _messageBelongsToScope(ConversationMessage message) {
    final threadRootId = scope.threadRootId;
    if (threadRootId == null) {
      return true;
    }
    final messageId = message.serverMessageId?.toString();
    final replyRootId = message.replyRootId?.toString();
    return messageId == threadRootId || replyRootId == threadRootId;
  }

  bool _isStickerMessage(ConversationMessage message) =>
      message.messageType == 'sticker';

  List<ReactionSummary> _toggleReactionLocal(
    ConversationMessage message,
    String emoji,
  ) {
    final next = <ReactionSummary>[];
    var handled = false;
    for (final reaction in message.reactions) {
      if (reaction.emoji != emoji) {
        next.add(reaction);
        continue;
      }
      handled = true;
      final currentlyReacted = reaction.reactedByMe == true;
      final updatedCount = currentlyReacted
          ? reaction.count - 1
          : reaction.count + 1;
      if (updatedCount <= 0) {
        continue;
      }
      next.add(
        ReactionSummary(
          emoji: reaction.emoji,
          count: updatedCount,
          reactedByMe: currentlyReacted ? false : true,
          reactors: reaction.reactors,
        ),
      );
    }

    if (!handled) {
      next.add(ReactionSummary(emoji: emoji, count: 1, reactedByMe: true));
    }

    return next;
  }

  List<ReactionSummary> _mergeReactions(
    List<ReactionSummary>? previous,
    List<ReactionSummary> incoming,
  ) {
    if (incoming.isEmpty) {
      return const <ReactionSummary>[];
    }

    final previousByEmoji = <String, ReactionSummary>{
      for (final reaction in previous ?? const <ReactionSummary>[])
        reaction.emoji: reaction,
    };
    return incoming
        .map((reaction) {
          final prior = previousByEmoji[reaction.emoji];
          return ReactionSummary(
            emoji: reaction.emoji,
            count: reaction.count,
            reactedByMe: reaction.reactedByMe ?? prior?.reactedByMe,
            reactors: reaction.reactors ?? prior?.reactors,
          );
        })
        .toList(growable: false);
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

  bool _hasWindowAroundServerMessage(
    int messageId, {
    required int before,
    required int after,
  }) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return false;
    }
    final index = _orderedStableKeys.indexOf(stableKey);
    if (index < 0) {
      return false;
    }
    final availableBefore = index;
    final availableAfter = _orderedStableKeys.length - index - 1;
    final hasEnoughBefore = availableBefore >= before || _hasReachedOldest;
    final hasEnoughAfter = availableAfter >= after || _hasReachedNewest;
    return hasEnoughBefore && hasEnoughAfter;
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
      messageType: message.messageType,
      sticker: message.sticker,
      sender: message.sender,
      isDeleted: message.isDeleted,
      attachments: message.attachments,
      firstAttachmentKind: message.attachments.isEmpty
          ? null
          : message.attachments.first.kind,
      mentions: message.mentions,
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
