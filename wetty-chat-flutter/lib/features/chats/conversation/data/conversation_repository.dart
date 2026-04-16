import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/messages_api_models.dart';
import '../../../../core/api/models/websocket_api_models.dart';
import '../application/conversation_cache_revision_registry.dart';
import '../../message_domain/domain/message_domain.dart';
import '../../models/message_api_mapper.dart';
import '../../models/message_models.dart';
import '../domain/conversation_message.dart';
import '../domain/conversation_scope.dart';
import 'message_api_service.dart';

class ConversationRepository {
  ConversationRepository({
    required this.scope,
    required MessageApiService service,
    required MessageDomainStore store,
  }) : _service = service,
       _store = store;

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
  final MessageDomainStore _store;
  final Map<String, ConversationMessage> _optimisticSnapshots = {};
  Ref? _ref;

  bool _hasReachedOldest = false;
  bool _hasReachedNewest = false;

  void attachRef(Ref ref) {
    _ref = ref;
  }

  void _bumpRevision() {
    _ref?.read(conversationCacheRevisionProvider(scope).notifier).bump();
  }

  Future<List<ConversationMessage>> loadLatestWindow({
    int limit = defaultWindowSize,
  }) async {
    final response = await _service.fetchConversationMessages(
      scope,
      max: limit,
    );
    _reconcileLatestDtos(response.messages, limit: limit);
    _store.activateLatestRange(scope, limit: limit);
    _hasReachedNewest = true;
    _hasReachedOldest = response.messages.length < limit;
    final keys = _store.activeRangeStableKeys(scope);
    _bumpRevision();
    return _messagesForWindow(keys);
  }

  Future<List<ConversationMessage>> refreshLatestWindow({
    int limit = defaultWindowSize,
  }) async {
    final response = await _service.fetchConversationMessages(
      scope,
      max: limit,
    );
    _reconcileLatestDtos(response.messages, limit: limit);
    _store.activateLatestRange(scope, limit: limit);
    _hasReachedNewest = true;
    _hasReachedOldest = response.messages.length < limit;
    final keys = _store.activeRangeStableKeys(scope);
    _bumpRevision();
    return _messagesForWindow(keys);
  }

  Future<int?> resolveUnreadAnchorMessageId(int lastReadMessageId) async {
    for (final message in _store.selectVisibleWindow(scope)) {
      final serverMessageId = message.serverMessageId;
      if (serverMessageId != null && serverMessageId > lastReadMessageId) {
        return serverMessageId;
      }
    }

    final response = await _service.fetchConversationMessages(
      scope,
      after: lastReadMessageId,
      max: 1,
    );
    _mergeFetchedCanonicalDtos(response.messages);
    _bumpRevision();
    return response.messages.firstOrNull?.id;
  }

  Future<List<ConversationMessage>> loadAroundMessage(
    int messageId, {
    int before = defaultWindowSize ~/ 2,
    int after = defaultWindowSize ~/ 2,
  }) async {
    final alreadyCached = _containsServerMessage(messageId);
    final hasCachedWindow = _hasRangeAroundServerMessage(
      messageId,
      before: before,
      after: after,
    );
    developer.log(
      'loadAroundMessage: msgId=$messageId, '
      'alreadyCached=$alreadyCached, '
      'hasCachedWindow=$hasCachedWindow, '
      'stableKey=${_store.stableKeyForServerId(messageId)}',
      name: 'ConvRepo',
    );
    if (!hasCachedWindow) {
      final response = await _service.fetchConversationMessages(
        scope,
        around: messageId,
        max: before + after + 1,
      );
      _updateReachabilityFromAroundResponse(
        response.messages,
        anchorMessageId: messageId,
        before: before,
        after: after,
      );
      _mergeFetchedCanonicalDtos(response.messages);
      developer.log(
        'loadAroundMessage: fetched ${response.messages.length} msgs, '
        'stableKey after merge=${_store.stableKeyForServerId(messageId)}, '
        'containsNow=${_containsServerMessage(messageId)}',
        name: 'ConvRepo',
      );
    }
    final keys = _store.activateHistoricalRangeAroundServerMessage(
      scope,
      messageId,
      before: before,
      after: after,
    );
    developer.log(
      'loadAroundMessage: produced ${keys.length} window keys '
      '(first=${keys.firstOrNull}, last=${keys.lastOrNull})',
      name: 'ConvRepo',
    );
    _bumpRevision();
    return _messagesForWindow(keys);
  }

  Future<List<ConversationMessage>> extendOlder({
    required String anchorStableKey,
    int pageSize = ConversationRepository.pageSize,
  }) async {
    final resolvedAnchorStableKey = _resolvePagingAnchorStableKey(
      anchorStableKey,
      preferOldest: true,
    );
    final anchor = resolvedAnchorStableKey == null
        ? null
        : _store.messageForStableKey(resolvedAnchorStableKey);
    final oldestId = anchor?.serverMessageId;
    if (oldestId == null) {
      return const <ConversationMessage>[];
    }

    final response = await _service.fetchConversationMessages(
      scope,
      before: oldestId,
      max: pageSize,
    );
    _mergeActiveRangePageDtos(
      response.messages,
      direction: MessageWindowPageDirection.older,
    );
    if (response.messages.length < pageSize) {
      _hasReachedOldest = true;
    }
    _bumpRevision();
    return response.messages
        .map((dto) => _messageForServerId(dto.id))
        .whereType<ConversationMessage>()
        .toList(growable: false);
  }

  Future<List<ConversationMessage>> extendNewer({
    required String anchorStableKey,
    int pageSize = ConversationRepository.pageSize,
  }) async {
    final resolvedAnchorStableKey = _resolvePagingAnchorStableKey(
      anchorStableKey,
      preferOldest: false,
    );
    final anchor = resolvedAnchorStableKey == null
        ? null
        : _store.messageForStableKey(resolvedAnchorStableKey);
    final newestId = anchor?.serverMessageId;
    if (newestId == null) {
      return const <ConversationMessage>[];
    }

    final response = await _service.fetchConversationMessages(
      scope,
      after: newestId,
      max: pageSize,
    );
    _mergeActiveRangePageDtos(
      response.messages,
      direction: MessageWindowPageDirection.newer,
    );
    if (response.messages.length < pageSize) {
      _hasReachedNewest = true;
    }
    _bumpRevision();
    return response.messages
        .map((dto) => _messageForServerId(dto.id))
        .whereType<ConversationMessage>()
        .toList(growable: false);
  }

  bool hasOlderOutsideWindow(List<String> windowStableKeys) {
    if (windowStableKeys.isEmpty) {
      return false;
    }
    return _store.hasOlderOutsideWindow(scope, windowStableKeys) ||
        !_hasReachedOldest;
  }

  bool hasNewerOutsideWindow(List<String> windowStableKeys) {
    if (windowStableKeys.isEmpty) {
      return false;
    }
    return _store.hasNewerOutsideWindow(scope, windowStableKeys) ||
        !_hasReachedNewest;
  }

  List<String> latestWindowStableKeys({int limit = defaultWindowSize}) =>
      _store.latestRangeStableKeys(scope, limit: limit);

  List<ConversationMessage> cachedWindowAroundMessage(
    int messageId, {
    int before = defaultWindowSize ~/ 2,
    int after = defaultWindowSize ~/ 2,
  }) {
    final keys = _store.historicalRangeSnapshotAroundServerMessage(
      scope,
      messageId,
      before: before,
      after: after,
    );
    return _messagesForWindow(keys);
  }

  bool hasWindowAroundMessage(
    int messageId, {
    int before = defaultWindowSize ~/ 2,
    int after = defaultWindowSize ~/ 2,
  }) {
    return _hasRangeAroundServerMessage(
      messageId,
      before: before,
      after: after,
    );
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
    _updateReachabilityFromAroundResponse(
      response.messages,
      anchorMessageId: messageId,
      before: before,
      after: after,
    );
    _mergeFetchedCanonicalDtos(response.messages);
    if (response.messages.isEmpty) {
      _bumpRevision();
      return const <ConversationMessage>[];
    }
    final keys = _store.activateHistoricalRangeAroundServerMessage(
      scope,
      messageId,
      before: before,
      after: after,
    );
    _bumpRevision();
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
  ) => _store.prependWindowPage(
    scope,
    currentWindow,
    oldestStableKey,
    pageSize: pageSize,
  );

  List<String> appendWindowPage(
    List<String> currentWindow,
    String newestStableKey,
  ) => _store.appendWindowPage(
    scope,
    currentWindow,
    newestStableKey,
    pageSize: pageSize,
  );

  List<String> appendVisibleTail(List<String> currentWindow) {
    if (currentWindow.isEmpty) {
      return currentWindow;
    }
    final newestStableKey = currentWindow.last;
    final visibleKeys = _store.activeRangeStableKeys(scope);
    final newestIndex = visibleKeys.indexOf(newestStableKey);
    if (newestIndex < 0 || newestIndex >= visibleKeys.length - 1) {
      return currentWindow;
    }
    final nextWindow = <String>[
      ...currentWindow,
      ...visibleKeys.sublist(newestIndex + 1),
    ];
    return _store
        .selectActiveWindow(scope)
        .map((message) => message.stableKey)
        .where(nextWindow.contains)
        .toList(growable: false);
  }

  int? findWindowIndex(List<String> windowStableKeys, int messageId) {
    final stableKey = _store.stableKeyForServerId(messageId);
    if (stableKey == null) {
      return null;
    }
    final index = windowStableKeys.indexOf(stableKey);
    return index >= 0 ? index : null;
  }

  ConversationMessage? messageForStableKey(String stableKey) =>
      _store.messageForStableKey(stableKey);

  Future<void> markAsRead(int messageId) {
    return _service.markMessagesAsRead(scope.chatId, messageId);
  }

  Future<ConversationMessage> toggleReaction({
    required int messageId,
    required String emoji,
  }) async {
    final stableKey = _store.stableKeyForServerId(messageId);
    if (stableKey == null) {
      throw StateError('Message not found: $messageId');
    }
    final message = _store.messageForStableKey(stableKey);
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
    _store.upsertCanonicalMessage(optimistic);
    _bumpRevision();

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
      _store.upsertCanonicalMessage(snapshot);
      _optimisticSnapshots.remove(stableKey);
      _bumpRevision();
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
    StickerSummary? sticker,
  }) {
    final draft = MessageDomainDraftMessage(
      scope: scope,
      clientGeneratedId: clientGeneratedId,
      sender: sender,
      message: text,
      messageType: messageType,
      sticker: sticker,
      replyToMessage: _replyToMessageForId(replyToId),
      attachments: attachments,
    );
    final localMessage = scope.isThread
        ? _store.applyOptimisticThreadReplySend(draft)
        : _store.applyOptimisticNormalMessageSend(draft);
    _bumpRevision();
    return localMessage;
  }

  Future<ConversationMessage> commitSend({
    required String clientGeneratedId,
    required String text,
    required String messageType,
    required List<String> attachmentIds,
    int? replyToId,
    String? stickerId,
  }) async {
    await _service.sendConversationMessage(
      scope,
      text,
      messageType: messageType,
      replyToId: replyToId,
      attachmentIds: attachmentIds,
      clientGeneratedId: clientGeneratedId,
      stickerId: stickerId,
    );
    final message = _store.applySendAccepted(clientGeneratedId);
    _bumpRevision();
    return message;
  }

  void markSendFailed(String clientGeneratedId) {
    _store.applySendFailed(clientGeneratedId);
    _bumpRevision();
  }

  ConversationMessage restartFailedSend(ConversationMessage message) {
    final restarted = _store.retryFailedSend(message);
    _bumpRevision();
    return restarted;
  }

  Future<ConversationMessage> retryFailedSend(
    ConversationMessage message,
  ) async {
    final optimistic = restartFailedSend(message);
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
    _bumpRevision();
  }

  ConversationMessage? beginOptimisticEdit(int messageId, String newText) {
    final stableKey = _store.stableKeyForServerId(messageId);
    if (stableKey == null) {
      return null;
    }
    final message = _store.messageForStableKey(stableKey);
    if (message == null) {
      return null;
    }
    _optimisticSnapshots[stableKey] = message;
    final updating = message.copyWith(
      message: newText,
      isEdited: true,
      deliveryState: ConversationDeliveryState.sending,
    );
    _store.upsertCanonicalMessage(updating);
    _bumpRevision();
    return updating;
  }

  Future<ConversationMessage> commitEdit(int messageId, String newText) async {
    final response = await _service.editMessage(
      scope.chatId,
      messageId,
      newText,
    );
    return _applyServerUpdated(_messageFromDto(response));
  }

  void rollbackEdit(int messageId) {
    final stableKey = _store.stableKeyForServerId(messageId);
    if (stableKey == null) {
      return;
    }
    final snapshot = _optimisticSnapshots.remove(stableKey);
    if (snapshot != null) {
      _store.upsertCanonicalMessage(snapshot);
      _bumpRevision();
    }
  }

  ConversationMessage? beginOptimisticDelete(int messageId) {
    final message = _store.applyOptimisticDelete(messageId);
    if (message != null) {
      _bumpRevision();
    }
    return message;
  }

  Future<void> commitDelete(int messageId) async {
    await _service.deleteMessage(scope.chatId, messageId);
    _store.applyDeleteConfirmed(messageId);
    _bumpRevision();
  }

  void rollbackDelete(int messageId) {
    _store.rollbackOptimisticDelete(messageId);
    _bumpRevision();
  }

  bool applyRealtimeEvent(ApiWsEvent event) {
    final applied = switch (event) {
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
    if (applied) {
      _bumpRevision();
    }
    return applied;
  }

  bool applyThreadSummaryUpdate({
    required int threadRootId,
    required int replyCount,
    required DateTime lastReplyAt,
  }) {
    if (scope.threadRootId != threadRootId.toString()) {
      return false;
    }
    _store.applyThreadAnchorSummaryUpdated(
      chatId: scope.chatId,
      threadAnchorId: threadRootId,
      summary: MessageThreadAnchorState(
        replyCount: replyCount,
        lastReplyAt: lastReplyAt,
      ),
    );
    _bumpRevision();
    return true;
  }

  bool matchesRealtimeEvent(ApiWsEvent event) {
    return switch (event) {
      MessageCreatedWsEvent(:final payload) => _matchesMessagePayload(payload),
      MessageUpdatedWsEvent(:final payload) => _matchesMessagePayload(payload),
      MessageDeletedWsEvent(:final payload) => _matchesMessagePayload(payload),
      ReactionUpdatedWsEvent(:final payload) => _matchesReactionPayload(
        payload,
      ),
      ThreadUpdatedWsEvent(:final payload) =>
        scope.threadRootId == payload.threadRootId.toString() &&
            scope.chatId == payload.chatId.toString(),
      StickerPackOrderUpdatedWsEvent() => false,
      PongWsEvent() => false,
    };
  }

  List<ConversationMessage> messagesForWindow(List<String> stableKeys) =>
      _messagesForWindow(stableKeys);

  ConversationMessage? messageForServerId(int messageId) =>
      _messageForServerId(messageId);

  bool _applyMessageEvent(MessageItemDto payload, {required bool deleted}) {
    if (!_matchesMessagePayload(payload)) {
      return false;
    }

    final message = _messageFromDto(payload);
    if (deleted) {
      _store.applyWebsocketMessageDeleted(
        _mergeIncomingSnapshot(
          message,
          deliveryState: ConversationDeliveryState.confirmed,
        ),
      );
      return true;
    }

    final merged = _mergeIncomingSnapshot(
      message,
      deliveryState: ConversationDeliveryState.confirmed,
    );
    switch (_eventTypeFor(payload, deleted: deleted)) {
      case _ConversationRealtimeEventType.created:
        _store.applyWebsocketMessageCreated(merged);
      case _ConversationRealtimeEventType.updated:
        _store.applyWebsocketMessageUpdated(merged);
      case _ConversationRealtimeEventType.deleted:
        throw StateError('Deleted realtime events should return earlier.');
    }
    return true;
  }

  _ConversationRealtimeEventType _eventTypeFor(
    MessageItemDto payload, {
    required bool deleted,
  }) {
    if (deleted) {
      return _ConversationRealtimeEventType.deleted;
    }
    return _messageForServerId(payload.id) == null
        ? _ConversationRealtimeEventType.created
        : _ConversationRealtimeEventType.updated;
  }

  bool _applyReactionEvent(ReactionUpdatePayloadDto payload) {
    if (payload.chatId.toString() != scope.chatId) {
      return false;
    }

    final stableKey = _store.stableKeyForServerId(payload.messageId);
    if (stableKey == null) {
      return false;
    }
    final message = _store.messageForStableKey(stableKey);
    if (message == null || !_messageBelongsToScope(message)) {
      return false;
    }

    _store.upsertCanonicalMessage(
      message.copyWith(
        reactions: _mergeReactions(
          message.reactions,
          payload.reactions.map((reaction) => reaction.toDomain()).toList(),
        ),
      ),
    );
    _optimisticSnapshots.remove(stableKey);
    _bumpRevision();
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

  bool _matchesMessagePayload(MessageItemDto payload) {
    if (payload.chatId.toString() != scope.chatId) {
      return false;
    }
    if (scope.threadRootId != null &&
        payload.id.toString() != scope.threadRootId &&
        payload.replyRootId?.toString() != scope.threadRootId) {
      return false;
    }
    if (scope.threadRootId == null && payload.replyRootId != null) {
      return false;
    }
    return true;
  }

  bool _matchesReactionPayload(ReactionUpdatePayloadDto payload) {
    if (payload.chatId.toString() != scope.chatId) {
      return false;
    }
    if (scope.threadRootId == null) {
      return true;
    }

    final stableKey = _store.stableKeyForServerId(payload.messageId);
    if (stableKey == null) {
      return false;
    }
    final message = _store.messageForStableKey(stableKey);
    return message != null && _messageBelongsToScope(message);
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

  void _reconcileLatestDtos(
    List<MessageItemDto> messages, {
    required int limit,
  }) {
    _store.reconcileFetchedLatestRange(
      scope: scope,
      messages: messages.map(_messageFromDto).toList(growable: false),
      limit: limit,
    );
  }

  void _mergeFetchedCanonicalDtos(List<MessageItemDto> messages) {
    _store.mergeFetchedCanonicalMessages(
      scope: scope,
      messages: messages.map(_messageFromDto).toList(growable: false),
    );
  }

  void _mergeActiveRangePageDtos(
    List<MessageItemDto> messages, {
    required MessageWindowPageDirection direction,
  }) {
    _store.mergeFetchedActiveRangePage(
      scope: scope,
      messages: messages.map(_messageFromDto).toList(),
      direction: direction,
    );
  }

  ConversationMessage _applyServerUpdated(ConversationMessage incoming) {
    final message = _store.applyEditAccepted(
      _mergeIncomingSnapshot(
        incoming,
        deliveryState: ConversationDeliveryState.sent,
      ),
    );
    _optimisticSnapshots.remove(message.stableKey);
    return message;
  }

  ConversationMessage _mergeIncomingSnapshot(
    ConversationMessage incoming, {
    required ConversationDeliveryState deliveryState,
  }) {
    final previous = incoming.serverMessageId != null
        ? _store.messageForServerId(incoming.serverMessageId!)
        : _store.messageForClientGeneratedId(incoming.clientGeneratedId);
    return incoming.copyWith(
      localMessageId: previous?.localMessageId,
      reactions: _mergeReactions(previous?.reactions, incoming.reactions),
      deliveryState: deliveryState,
    );
  }

  ConversationMessage _messageFromDto(MessageItemDto dto) {
    if (scope.threadRootId == null) {
      return dto.toConversation(scope);
    }
    final isAnchorMessage =
        dto.replyRootId == null && dto.id.toString() == scope.threadRootId;
    final messageScope = isAnchorMessage
        ? ConversationScope.chat(chatId: scope.chatId)
        : scope;
    return dto.toConversation(messageScope);
  }

  void _removeStableKey(String stableKey) {
    _store.removeMessageByStableKey(stableKey);
  }

  bool _hasRangeAroundServerMessage(
    int messageId, {
    required int before,
    required int after,
  }) {
    if (_store.hasCanonicalRangeAroundServerMessage(
      scope,
      messageId,
      before: before,
      after: after,
    )) {
      return true;
    }

    final stableKey = _store.stableKeyForServerId(messageId);
    if (stableKey == null) {
      return false;
    }

    if (!scope.isThread) {
      final visibleKeys = _store.activeRangeStableKeys(scope);
      final index = visibleKeys.indexOf(stableKey);
      if (index < 0) {
        return false;
      }
      final availableBefore = index;
      final availableAfter = visibleKeys.length - index - 1;
      return (availableBefore >= before || _hasReachedOldest) &&
          (availableAfter >= after || _hasReachedNewest);
    }

    final anchorKey = _threadAnchorStableKey();
    if (anchorKey == null) {
      return false;
    }
    final replyKeys = _paginatableVisibleKeys();
    if (stableKey == anchorKey) {
      return _hasReachedOldest &&
          (replyKeys.length >= after || _hasReachedNewest);
    }

    final replyIndex = replyKeys.indexOf(stableKey);
    if (replyIndex < 0) {
      return false;
    }
    final availableBefore = replyIndex;
    final availableAfter = replyKeys.length - replyIndex - 1;
    return (availableBefore >= before || _hasReachedOldest) &&
        (availableAfter >= after || _hasReachedNewest);
  }

  void _updateReachabilityFromAroundResponse(
    List<MessageItemDto> messages, {
    required int anchorMessageId,
    required int before,
    required int after,
  }) {
    if (messages.isEmpty) {
      _hasReachedOldest = false;
      _hasReachedNewest = false;
      return;
    }

    if (!scope.isThread) {
      final anchorIndex = messages.indexWhere(
        (message) => message.id == anchorMessageId,
      );
      if (anchorIndex < 0) {
        _hasReachedOldest = false;
        _hasReachedNewest = false;
        return;
      }
      final availableBefore = anchorIndex;
      final availableAfter = messages.length - anchorIndex - 1;
      _hasReachedOldest = availableBefore < before;
      _hasReachedNewest = availableAfter < after;
      return;
    }

    final threadRootId = int.tryParse(scope.threadRootId ?? '');
    final replyMessages = messages
        .where((message) => message.id != threadRootId)
        .toList(growable: false);
    if (anchorMessageId == threadRootId) {
      _hasReachedOldest = true;
      _hasReachedNewest = replyMessages.length < after;
      return;
    }

    final replyIndex = replyMessages.indexWhere(
      (message) => message.id == anchorMessageId,
    );
    if (replyIndex < 0) {
      _hasReachedOldest = false;
      _hasReachedNewest = false;
      return;
    }
    final availableBefore = replyIndex;
    final availableAfter = replyMessages.length - replyIndex - 1;
    _hasReachedOldest = availableBefore < before;
    _hasReachedNewest = availableAfter < after;
  }

  String? _resolvePagingAnchorStableKey(
    String requestedStableKey, {
    required bool preferOldest,
  }) {
    final anchorKey = _threadAnchorStableKey();
    if (anchorKey == null || requestedStableKey != anchorKey) {
      return requestedStableKey;
    }
    final replyKeys = _paginatableVisibleKeys();
    if (replyKeys.isEmpty) {
      return null;
    }
    return preferOldest ? replyKeys.first : replyKeys.last;
  }

  String? _threadAnchorStableKey() {
    final threadRootId = scope.threadRootId;
    if (threadRootId == null) {
      return null;
    }
    return _store.stableKeyForServerId(int.parse(threadRootId));
  }

  List<String> _paginatableVisibleKeys() {
    final visibleKeys = _store.activeRangeStableKeys(scope);
    final anchorKey = _threadAnchorStableKey();
    if (anchorKey == null) {
      return visibleKeys;
    }
    return visibleKeys
        .where((stableKey) => stableKey != anchorKey)
        .toList(growable: false);
  }

  List<ConversationMessage> _messagesForWindow(List<String> stableKeys) {
    return stableKeys
        .map((stableKey) => _store.messageForStableKey(stableKey))
        .whereType<ConversationMessage>()
        .where(
          (message) => _store.isVisibleInWindow(
            scope: scope,
            stableKey: message.stableKey,
          ),
        )
        .toList(growable: false);
  }

  ConversationMessage? _messageForServerId(int messageId) {
    return _store.messageForServerId(messageId);
  }

  bool _containsServerMessage(int messageId) =>
      _store.containsServerMessage(messageId);

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
}

enum _ConversationRealtimeEventType { created, updated, deleted }

final conversationRepositoryProvider =
    Provider.family<ConversationRepository, ConversationScope>((ref, scope) {
      final repository = ConversationRepository(
        scope: scope,
        service: ref.read(messageApiServiceProvider),
        store: ref.read(messageDomainStoreProvider),
      );
      repository.attachRef(ref);
      return repository;
    });
