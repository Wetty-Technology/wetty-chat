import '../../conversation/domain/conversation_message.dart';
import '../../conversation/domain/conversation_scope.dart';
import '../../models/message_models.dart';
import 'message_domain_models.dart';

/// Authoritative message-domain projection for chat and thread message flows.
class MessageDomainStore {
  final Map<String, ConversationMessage> _messagesByStableKey =
      <String, ConversationMessage>{};
  final Map<int, String> _stableKeyByServerId = <int, String>{};
  final Map<String, String> _stableKeyByClientGeneratedId = <String, String>{};
  final Map<String, List<String>> _windowMemberships = <String, List<String>>{};
  final Map<String, MessageRangeState> _activeRanges =
      <String, MessageRangeState>{};
  final Map<int, MessageThreadAnchorState> _threadAnchorStates =
      <int, MessageThreadAnchorState>{};
  final Map<int, _DeleteTransaction> _deleteTransactions =
      <int, _DeleteTransaction>{};
  final Set<String> _pendingOptimisticThreadReplyClientIds = <String>{};

  int _nextLocalMessageId = 0;

  ConversationMessage applyOptimisticNormalMessageSend(
    MessageDomainDraftMessage draft,
  ) {
    if (draft.scope.isThread) {
      throw ArgumentError(
        'applyOptimisticNormalMessageSend requires a chat scope.',
      );
    }

    final message = ConversationMessage(
      scope: draft.scope,
      localMessageId: _nextLocalMessageKey(),
      clientGeneratedId: draft.clientGeneratedId,
      sender: draft.sender,
      message: draft.message,
      messageType: draft.messageType,
      sticker: draft.sticker,
      createdAt: draft.createdAt ?? DateTime.now().toUtc(),
      replyRootId: null,
      hasAttachments: draft.attachments.isNotEmpty,
      replyToMessage: draft.replyToMessage,
      attachments: draft.attachments,
      reactions: draft.reactions,
      mentions: draft.mentions,
      deliveryState: ConversationDeliveryState.sending,
    );
    _upsertCanonical(message);
    _ensureInLatestWindow(message.scope, message.stableKey);
    _ensureInActiveRangeIfTracked(message.scope, message.stableKey);
    return message;
  }

  ConversationMessage applyOptimisticThreadReplySend(
    MessageDomainDraftMessage draft,
  ) {
    final threadRootId = draft.scope.threadRootId;
    if (threadRootId == null) {
      throw ArgumentError(
        'applyOptimisticThreadReplySend requires a thread scope.',
      );
    }

    final anchorId = int.parse(threadRootId);
    final message = ConversationMessage(
      scope: draft.scope,
      localMessageId: _nextLocalMessageKey(),
      clientGeneratedId: draft.clientGeneratedId,
      sender: draft.sender,
      message: draft.message,
      messageType: draft.messageType,
      sticker: draft.sticker,
      createdAt: draft.createdAt ?? DateTime.now().toUtc(),
      replyRootId: anchorId,
      hasAttachments: draft.attachments.isNotEmpty,
      replyToMessage: draft.replyToMessage,
      attachments: draft.attachments,
      reactions: draft.reactions,
      mentions: draft.mentions,
      deliveryState: ConversationDeliveryState.sending,
    );
    _upsertCanonical(message);
    _ensureThreadWindowContainsAnchor(
      chatId: draft.scope.chatId,
      anchorId: anchorId,
    );
    _ensureInLatestWindow(message.scope, message.stableKey);
    _ensureInActiveRangeIfTracked(message.scope, message.stableKey);
    _incrementThreadAnchorReplyCount(anchorId, chatId: draft.scope.chatId);
    _pendingOptimisticThreadReplyClientIds.add(draft.clientGeneratedId);
    return message;
  }

  ConversationMessage applySendAccepted(String clientGeneratedId) {
    final stableKey = _stableKeyByClientGeneratedId[clientGeneratedId];
    if (stableKey == null) {
      throw StateError(
        'Message not found for clientGeneratedId: $clientGeneratedId',
      );
    }
    final current = _messagesByStableKey[stableKey];
    if (current == null) {
      throw StateError('Message not found for stableKey: $stableKey');
    }
    final accepted = current.copyWith(
      deliveryState: _resolveDeliveryState(
        previous: current.deliveryState,
        incoming: ConversationDeliveryState.sent,
      ),
    );
    _messagesByStableKey[stableKey] = accepted;
    return accepted;
  }

  ConversationMessage applySendConfirmed(ConversationMessage message) {
    final serverMessageId = message.serverMessageId;
    final wasKnownServerMessage =
        serverMessageId != null &&
        _stableKeyByServerId.containsKey(serverMessageId);
    final clientGeneratedId = message.clientGeneratedId;
    final hadPendingOptimisticReply =
        clientGeneratedId.isNotEmpty &&
        _pendingOptimisticThreadReplyClientIds.contains(clientGeneratedId);

    final merged = _mergeIncoming(
      message.copyWith(deliveryState: ConversationDeliveryState.confirmed),
    );
    _ensureInLatestWindow(merged.scope, merged.stableKey);
    _ensureInActiveRangeIfTracked(merged.scope, merged.stableKey);

    if (_isThreadReply(merged)) {
      final anchorId = merged.replyRootId!;
      _ensureThreadWindowContainsAnchor(
        chatId: merged.scope.chatId,
        anchorId: anchorId,
      );
      if (hadPendingOptimisticReply) {
        _pendingOptimisticThreadReplyClientIds.remove(clientGeneratedId);
      } else if (!wasKnownServerMessage) {
        _incrementThreadAnchorReplyCount(anchorId, chatId: merged.scope.chatId);
      }
      return merged;
    }

    _syncThreadAnchorStateFromMessage(merged);
    if (_isThreadAnchor(merged)) {
      _ensureThreadWindowContainsAnchor(
        chatId: merged.scope.chatId,
        anchorId: merged.serverMessageId!,
      );
    }
    return merged;
  }

  ConversationMessage applyEditConfirmed(ConversationMessage message) {
    final merged = _mergeIncoming(
      message.copyWith(deliveryState: ConversationDeliveryState.confirmed),
    );
    _syncThreadAnchorStateFromMessage(merged);
    if (_isThreadAnchor(merged)) {
      _ensureThreadWindowContainsAnchor(
        chatId: merged.scope.chatId,
        anchorId: merged.serverMessageId!,
      );
    }
    return merged;
  }

  ConversationMessage applyEditAccepted(ConversationMessage message) {
    final merged = _mergeIncoming(
      message.copyWith(deliveryState: ConversationDeliveryState.sent),
    );
    _syncThreadAnchorStateFromMessage(merged);
    if (_isThreadAnchor(merged)) {
      _ensureThreadWindowContainsAnchor(
        chatId: merged.scope.chatId,
        anchorId: merged.serverMessageId!,
      );
    }
    return merged;
  }

  void applySendFailed(String clientGeneratedId) {
    final stableKey = _stableKeyByClientGeneratedId[clientGeneratedId];
    if (stableKey == null) {
      return;
    }
    final current = _messagesByStableKey[stableKey];
    if (current == null) {
      return;
    }
    _messagesByStableKey[stableKey] = current.copyWith(
      deliveryState: ConversationDeliveryState.failed,
    );
    if (_pendingOptimisticThreadReplyClientIds.remove(clientGeneratedId)) {
      final anchorId = current.replyRootId;
      if (anchorId != null) {
        _decrementThreadAnchorReplyCount(
          anchorId,
          chatId: current.scope.chatId,
        );
      }
    }
  }

  ConversationMessage retryFailedSend(ConversationMessage message) {
    final retried = message.copyWith(
      deliveryState: ConversationDeliveryState.sending,
    );
    _upsertCanonical(retried);
    if (_isThreadReply(retried) &&
        retried.clientGeneratedId.isNotEmpty &&
        !_pendingOptimisticThreadReplyClientIds.contains(
          retried.clientGeneratedId,
        )) {
      _pendingOptimisticThreadReplyClientIds.add(retried.clientGeneratedId);
      _incrementThreadAnchorReplyCount(
        retried.replyRootId!,
        chatId: retried.scope.chatId,
      );
    }
    return retried;
  }

  ConversationMessage? applyOptimisticDelete(int messageId) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return null;
    }
    final current = _messagesByStableKey[stableKey];
    if (current == null) {
      return null;
    }

    final transaction = _buildDeleteTransaction(current);
    _deleteTransactions[messageId] = transaction;
    _messagesByStableKey[stableKey] = current.copyWith(
      deliveryState: ConversationDeliveryState.deleting,
    );
    _applyDeleteVisibility(
      current,
      stableKey: stableKey,
      summaryAlreadyAdjusted: false,
    );
    return _messagesByStableKey[stableKey];
  }

  void applyDeleteConfirmed(int messageId) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return;
    }
    final current = _messagesByStableKey[stableKey];
    if (current == null) {
      return;
    }
    final transaction = _deleteTransactions.remove(messageId);
    final isAnchorDelete = _isThreadAnchor(current);
    final deleted = current.copyWith(
      isDeleted: true,
      message: null,
      hasAttachments: false,
      attachments: const <AttachmentItem>[],
      threadInfo: isAnchorDelete ? _threadInfoFromAnchorState(messageId) : null,
      deliveryState: ConversationDeliveryState.confirmed,
    );
    _messagesByStableKey[stableKey] = deleted;
    _applyDeleteVisibility(
      deleted,
      stableKey: stableKey,
      summaryAlreadyAdjusted: transaction != null,
    );
  }

  void rollbackOptimisticDelete(int messageId) {
    final transaction = _deleteTransactions.remove(messageId);
    if (transaction == null) {
      return;
    }

    final stableKey = transaction.message.stableKey;
    _messagesByStableKey[stableKey] = transaction.message;
    for (final patch in transaction.membershipPatches) {
      if (_windowMemberships.containsKey(patch.windowKey)) {
        final window = _windowMemberships.putIfAbsent(
          patch.windowKey,
          () => <String>[],
        );
        _insertStableKey(window, stableKey, patch.index);
        continue;
      }
      final range = _activeRanges[patch.windowKey];
      if (range == null) {
        continue;
      }
      _insertStableKey(range.stableKeys, stableKey, patch.index);
    }

    final summaryAnchorId = transaction.summaryAnchorId;
    if (summaryAnchorId == null) {
      return;
    }
    _threadAnchorStates.putIfAbsent(
      summaryAnchorId,
      () => const MessageThreadAnchorState(replyCount: 0),
    );
    _recomputeThreadAnchorSummary(
      summaryAnchorId,
      chatId: transaction.message.scope.chatId,
    );
  }

  ConversationMessage applyWebsocketMessageCreated(
    ConversationMessage message,
  ) {
    final merged = _mergeIncoming(
      message.copyWith(deliveryState: ConversationDeliveryState.confirmed),
    );
    _ensureInLatestWindow(merged.scope, merged.stableKey);

    if (_isThreadReply(merged)) {
      final anchorId = merged.replyRootId!;
      _ensureThreadWindowContainsAnchor(
        chatId: merged.scope.chatId,
        anchorId: anchorId,
      );
      if (!_stableKeyByServerId.containsKey(anchorId)) {
        _incrementThreadAnchorReplyCount(anchorId, chatId: merged.scope.chatId);
      } else {
        _incrementThreadAnchorReplyCount(anchorId, chatId: merged.scope.chatId);
      }
      if (_activeRanges[merged.scope.storageKey]?.kind ==
          MessageRangeKind.latest) {
        _ensureInActiveRangeIfTracked(merged.scope, merged.stableKey);
      }
      return merged;
    }

    _syncThreadAnchorStateFromMessage(merged);
    if (_isThreadAnchor(merged)) {
      _ensureThreadWindowContainsAnchor(
        chatId: merged.scope.chatId,
        anchorId: merged.serverMessageId!,
      );
    }
    if (_activeRanges[merged.scope.storageKey]?.kind ==
        MessageRangeKind.latest) {
      _ensureInActiveRangeIfTracked(merged.scope, merged.stableKey);
    }
    return merged;
  }

  ConversationMessage applyWebsocketMessageUpdated(
    ConversationMessage message,
  ) {
    return applyEditConfirmed(message);
  }

  void applyWebsocketMessageDeleted(ConversationMessage message) {
    _mergeIncoming(
      message.copyWith(deliveryState: ConversationDeliveryState.confirmed),
    );
    applyDeleteConfirmed(message.serverMessageId!);
  }

  void applyThreadAnchorSummaryUpdated({
    required String chatId,
    required int threadAnchorId,
    required MessageThreadAnchorState summary,
  }) {
    _threadAnchorStates[threadAnchorId] = summary;
    _patchAnchorThreadInfo(
      threadAnchorId,
      ThreadInfo(replyCount: summary.replyCount),
    );
    _ensureThreadWindowContainsAnchor(chatId: chatId, anchorId: threadAnchorId);
  }

  List<String> latestRangeStableKeys(
    ConversationScope scope, {
    required int limit,
  }) {
    final latestKeys = _windowMemberships[scope.storageKey];
    if (latestKeys != null && latestKeys.isNotEmpty) {
      return _normalizeRangeStableKeys(scope, latestKeys);
    }
    return _latestProjectedStableKeys(scope, limit: limit);
  }

  List<String> activeRangeStableKeys(ConversationScope scope) {
    final activeRange = _activeRanges[scope.storageKey];
    if (activeRange != null && activeRange.stableKeys.isNotEmpty) {
      return _normalizeRangeStableKeys(scope, activeRange.stableKeys);
    }
    final latestKeys = _windowMemberships[scope.storageKey];
    if (latestKeys == null || latestKeys.isEmpty) {
      return const <String>[];
    }
    return _normalizeRangeStableKeys(scope, latestKeys);
  }

  List<ConversationMessage> selectActiveWindow(ConversationScope scope) {
    final keys = activeRangeStableKeys(scope);
    return keys
        .map((stableKey) => _messagesByStableKey[stableKey])
        .whereType<ConversationMessage>()
        .where((message) => _isVisibleInWindow(message, scope))
        .toList(growable: false);
  }

  bool hasCachedActiveRangeForScope(ConversationScope scope) {
    return activeRangeStableKeys(scope).isNotEmpty;
  }

  bool activeRangeContainsMessage(ConversationScope scope, int messageId) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return false;
    }
    return activeRangeStableKeys(scope).contains(stableKey);
  }

  void activateLatestRange(ConversationScope scope, {required int limit}) {
    final stableKeys = latestRangeStableKeys(scope, limit: limit);
    _activeRanges[scope.storageKey] = MessageRangeState(
      kind: MessageRangeKind.latest,
      stableKeys: List<String>.from(stableKeys),
      hasReachedNewest: true,
    );
  }

  List<String> historicalRangeSnapshotAroundServerMessage(
    ConversationScope scope,
    int messageId, {
    required int before,
    required int after,
  }) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return const <String>[];
    }
    final persistedKeys = _canonicalPersistedStableKeys(scope);
    if (!scope.isThread) {
      final index = persistedKeys.indexOf(stableKey);
      if (index < 0) {
        return const <String>[];
      }
      final start = (index - before).clamp(0, persistedKeys.length);
      final end = (index + after + 1).clamp(0, persistedKeys.length);
      return persistedKeys.sublist(start, end);
    }

    final anchorKey = _threadAnchorStableKey(scope);
    final replyKeys = persistedKeys
        .where((candidateKey) => candidateKey != anchorKey)
        .toList(growable: false);
    if (stableKey == anchorKey) {
      final replyEnd = after.clamp(0, replyKeys.length);
      return <String>[?anchorKey, ...replyKeys.sublist(0, replyEnd)];
    }

    final replyIndex = replyKeys.indexOf(stableKey);
    if (replyIndex < 0) {
      return const <String>[];
    }
    final replyStart = (replyIndex - before).clamp(0, replyKeys.length);
    final replyEnd = (replyIndex + after + 1).clamp(0, replyKeys.length);
    return <String>[?anchorKey, ...replyKeys.sublist(replyStart, replyEnd)];
  }

  List<String> activateHistoricalRangeAroundServerMessage(
    ConversationScope scope,
    int messageId, {
    required int before,
    required int after,
  }) {
    final stableKeys = historicalRangeSnapshotAroundServerMessage(
      scope,
      messageId,
      before: before,
      after: after,
    );
    _activeRanges[scope.storageKey] = MessageRangeState(
      kind: MessageRangeKind.active,
      stableKeys: List<String>.from(stableKeys),
      anchorMessageId: messageId,
    );
    return stableKeys;
  }

  bool hasCanonicalRangeAroundServerMessage(
    ConversationScope scope,
    int messageId, {
    required int before,
    required int after,
  }) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return false;
    }

    final persistedKeys = _canonicalPersistedStableKeys(scope);
    if (!scope.isThread) {
      final index = persistedKeys.indexOf(stableKey);
      if (index < 0) {
        return false;
      }
      final availableBefore = index;
      final availableAfter = persistedKeys.length - index - 1;
      return availableBefore >= before && availableAfter >= after;
    }

    final anchorKey = _threadAnchorStableKey(scope);
    final replyKeys = persistedKeys
        .where((candidateKey) => candidateKey != anchorKey)
        .toList(growable: false);
    if (stableKey == anchorKey) {
      return replyKeys.length >= after;
    }

    final replyIndex = replyKeys.indexOf(stableKey);
    if (replyIndex < 0) {
      return false;
    }
    final availableBefore = replyIndex;
    final availableAfter = replyKeys.length - replyIndex - 1;
    return availableBefore >= before && availableAfter >= after;
  }

  void reconcileFetchedLatestRange({
    required ConversationScope scope,
    required List<ConversationMessage> messages,
    required int limit,
  }) {
    _mergeFetchedCanonicalMessages(scope: scope, messages: messages);
    final confirmedKeys = messages.map((message) => message.stableKey).toList();
    final existing = _windowMemberships[scope.storageKey] ?? const <String>[];
    final preservedPatches = <_WindowMembershipPatch>[];
    for (var index = 0; index < existing.length; index += 1) {
      final stableKey = existing[index];
      if (confirmedKeys.contains(stableKey)) {
        continue;
      }
      final message = _messagesByStableKey[stableKey];
      if (message == null || !_shouldPreserveDuringRefresh(scope, message)) {
        continue;
      }
      preservedPatches.add(
        _WindowMembershipPatch(windowKey: scope.storageKey, index: index),
      );
    }
    final nextWindow = List<String>.from(confirmedKeys);
    for (final patch in preservedPatches) {
      final stableKey = existing[patch.index];
      _insertStableKey(nextWindow, stableKey, patch.index);
    }
    final normalizedWindow = _normalizeRangeStableKeys(scope, nextWindow);
    final latestWindow = normalizedWindow.length <= limit
        ? normalizedWindow
        : normalizedWindow.sublist(normalizedWindow.length - limit);
    _windowMemberships[scope.storageKey] = List<String>.from(latestWindow);
    final activeRange = _activeRanges[scope.storageKey];
    if (activeRange?.kind == MessageRangeKind.latest) {
      activateLatestRange(scope, limit: limit);
    }
  }

  void mergeFetchedCanonicalMessages({
    required ConversationScope scope,
    required List<ConversationMessage> messages,
  }) {
    _mergeFetchedCanonicalMessages(scope: scope, messages: messages);
  }

  void mergeFetchedActiveRangePage({
    required ConversationScope scope,
    required List<ConversationMessage> messages,
    required MessageWindowPageDirection direction,
  }) {
    _mergeFetchedCanonicalMessages(scope: scope, messages: messages);
    final currentRange = _activeRanges[scope.storageKey];
    final currentKeys = currentRange?.stableKeys ?? const <String>[];
    if (currentKeys.isEmpty) {
      return;
    }

    final incomingKeys = messages
        .map(
          (message) => _canonicalScopeForFetchedMessage(scope, message).isThread
              ? message.copyWith(
                  scope: _canonicalScopeForFetchedMessage(scope, message),
                )
              : message,
        )
        .map((message) => message.stableKey)
        .toList(growable: false);
    final mergedKeys = direction == MessageWindowPageDirection.older
        ? <String>[...incomingKeys, ...currentKeys]
        : <String>[...currentKeys, ...incomingKeys];
    _activeRanges[scope.storageKey] = currentRange!.copyWith(
      stableKeys: _normalizeRangeStableKeys(scope, mergedKeys),
    );
    coalesceActiveWithLatestIfNeeded(scope);
  }

  bool coalesceActiveWithLatestIfNeeded(ConversationScope scope) {
    final activeRange = _activeRanges[scope.storageKey];
    final latestKeys = _windowMemberships[scope.storageKey] ?? const <String>[];
    if (activeRange == null ||
        activeRange.kind == MessageRangeKind.latest ||
        activeRange.stableKeys.isEmpty ||
        latestKeys.isEmpty) {
      return false;
    }

    final activePersistedIds = activeRange.stableKeys
        .where((key) => key.startsWith('server:'))
        .map((key) => int.tryParse(key.substring('server:'.length)))
        .whereType<int>()
        .toList(growable: false);
    final latestPersistedIds = latestKeys
        .where((key) => key.startsWith('server:'))
        .map((key) => int.tryParse(key.substring('server:'.length)))
        .whereType<int>()
        .toList(growable: false);
    if (activePersistedIds.isEmpty || latestPersistedIds.isEmpty) {
      return false;
    }

    final activeMax = activePersistedIds.last;
    final latestMin = latestPersistedIds.first;
    if (activeMax < latestMin - 1) {
      return false;
    }

    final mergedKeys = _normalizeRangeStableKeys(scope, <String>[
      ...activeRange.stableKeys,
      ...latestKeys,
    ]);
    _windowMemberships[scope.storageKey] = mergedKeys;
    _activeRanges[scope.storageKey] = MessageRangeState(
      kind: MessageRangeKind.latest,
      stableKeys: mergedKeys,
    );
    return true;
  }

  void replaceWindowMembership({
    required ConversationScope scope,
    required List<String> stableKeys,
  }) {
    _windowMemberships[scope.storageKey] = _normalizeRangeStableKeys(
      scope,
      stableKeys,
    );
  }

  void reconcileFetchedWindow({
    required ConversationScope scope,
    required List<ConversationMessage> messages,
  }) {
    reconcileFetchedLatestRange(
      scope: scope,
      messages: messages,
      limit:
          messages.length + (_windowMemberships[scope.storageKey]?.length ?? 0),
    );
  }

  void mergeFetchedWindowPage({
    required ConversationScope scope,
    required List<ConversationMessage> messages,
    required MessageWindowPageDirection direction,
  }) {
    _mergeFetchedCanonicalMessages(scope: scope, messages: messages);
    final existing = List<String>.from(
      _windowMemberships[scope.storageKey] ?? const <String>[],
    );
    final incomingKeys = messages.map((message) => message.stableKey).toList();
    final mergedKeys = direction == MessageWindowPageDirection.older
        ? <String>[...incomingKeys, ...existing]
        : <String>[...existing, ...incomingKeys];
    _windowMemberships[scope.storageKey] = _normalizeRangeStableKeys(
      scope,
      mergedKeys,
    );
  }

  List<String> latestVisibleStableKeys(
    ConversationScope scope, {
    required int limit,
  }) => latestRangeStableKeys(scope, limit: limit);

  List<String> visibleStableKeysAroundServerMessage(
    ConversationScope scope,
    int messageId, {
    required int before,
    required int after,
  }) => historicalRangeSnapshotAroundServerMessage(
    scope,
    messageId,
    before: before,
    after: after,
  );

  bool hasVisibleWindowAroundServerMessage(
    ConversationScope scope,
    int messageId, {
    required int before,
    required int after,
  }) {
    return hasCanonicalRangeAroundServerMessage(
      scope,
      messageId,
      before: before,
      after: after,
    );
  }

  bool hasOlderOutsideWindow(
    ConversationScope scope,
    List<String> windowStableKeys,
  ) {
    if (windowStableKeys.isEmpty) {
      return false;
    }
    final visibleKeys = _paginatableStableKeys(scope);
    final windowKeys = _paginatableSubset(scope, windowStableKeys);
    if (windowKeys.isEmpty) {
      return false;
    }
    final oldestIndex = visibleKeys.indexOf(windowKeys.first);
    return oldestIndex > 0;
  }

  bool hasNewerOutsideWindow(
    ConversationScope scope,
    List<String> windowStableKeys,
  ) {
    if (windowStableKeys.isEmpty) {
      return false;
    }
    final visibleKeys = _paginatableStableKeys(scope);
    final windowKeys = _paginatableSubset(scope, windowStableKeys);
    if (windowKeys.isEmpty) {
      return false;
    }
    final newestIndex = visibleKeys.indexOf(windowKeys.last);
    return newestIndex >= 0 && newestIndex < visibleKeys.length - 1;
  }

  List<String> prependWindowPage(
    ConversationScope scope,
    List<String> currentWindow,
    String oldestStableKey, {
    required int pageSize,
  }) {
    final visibleKeys = _paginatableStableKeys(scope);
    final currentKeys = _paginatableSubset(scope, currentWindow);
    if (visibleKeys.isEmpty || currentKeys.isEmpty) {
      return currentWindow;
    }

    final requestedKey = _resolvePagingStableKey(
      scope,
      currentWindow,
      requestedStableKey: oldestStableKey,
      preferOldest: true,
    );
    if (requestedKey == null) {
      return currentWindow;
    }
    final oldestIndex = visibleKeys.indexOf(requestedKey);
    if (oldestIndex <= 0) {
      return currentWindow;
    }
    final start = (oldestIndex - pageSize).clamp(0, oldestIndex);
    return _composeWindowWithAnchor(scope, <String>[
      ...visibleKeys.sublist(start, oldestIndex),
      ...currentKeys,
    ]);
  }

  List<String> appendWindowPage(
    ConversationScope scope,
    List<String> currentWindow,
    String newestStableKey, {
    required int pageSize,
  }) {
    final visibleKeys = _paginatableStableKeys(scope);
    final currentKeys = _paginatableSubset(scope, currentWindow);
    if (visibleKeys.isEmpty || currentKeys.isEmpty) {
      return currentWindow;
    }

    final requestedKey = _resolvePagingStableKey(
      scope,
      currentWindow,
      requestedStableKey: newestStableKey,
      preferOldest: false,
    );
    if (requestedKey == null) {
      return currentWindow;
    }
    final newestIndex = visibleKeys.indexOf(requestedKey);
    if (newestIndex < 0 || newestIndex >= visibleKeys.length - 1) {
      return currentWindow;
    }
    final end = (newestIndex + 1 + pageSize).clamp(0, visibleKeys.length);
    return _composeWindowWithAnchor(scope, <String>[
      ...currentKeys,
      ...visibleKeys.sublist(newestIndex + 1, end),
    ]);
  }

  List<ConversationMessage> selectVisibleWindow(ConversationScope scope) {
    final keys = _windowMemberships[scope.storageKey] ?? const <String>[];
    return keys
        .map((stableKey) => _messagesByStableKey[stableKey])
        .whereType<ConversationMessage>()
        .where((message) => _isVisibleInWindow(message, scope))
        .toList(growable: false);
  }

  List<String> selectVisibleStableKeys(ConversationScope scope) {
    return selectVisibleWindow(
      scope,
    ).map((message) => message.stableKey).toList(growable: false);
  }

  bool isVisibleInWindow({
    required ConversationScope scope,
    required String stableKey,
  }) {
    final message = _messagesByStableKey[stableKey];
    if (message == null) {
      return false;
    }
    return _isVisibleInWindow(message, scope);
  }

  ConversationMessage? messageForStableKey(String stableKey) {
    return _messagesByStableKey[stableKey];
  }

  ConversationMessage? messageForServerId(int messageId) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return null;
    }
    return _messagesByStableKey[stableKey];
  }

  ConversationMessage? messageForClientGeneratedId(String clientGeneratedId) {
    final stableKey = _stableKeyByClientGeneratedId[clientGeneratedId];
    if (stableKey == null) {
      return null;
    }
    return _messagesByStableKey[stableKey];
  }

  String? stableKeyForServerId(int messageId) {
    return _stableKeyByServerId[messageId];
  }

  String? stableKeyForClientGeneratedId(String clientGeneratedId) {
    return _stableKeyByClientGeneratedId[clientGeneratedId];
  }

  bool containsServerMessage(int messageId) {
    return _stableKeyByServerId.containsKey(messageId);
  }

  bool hasCachedWindowForScope(ConversationScope scope) {
    return (_windowMemberships[scope.storageKey] ?? const <String>[])
            .isNotEmpty ||
        (_activeRanges[scope.storageKey]?.stableKeys ?? const <String>[])
            .isNotEmpty;
  }

  bool hasCachedThreadWindow({
    required String chatId,
    required int threadRootId,
  }) {
    return hasCachedWindowForScope(
      ConversationScope.thread(
        chatId: chatId,
        threadRootId: threadRootId.toString(),
      ),
    );
  }

  List<ConversationScope> cachedScopesForMessageId(int messageId) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return const <ConversationScope>[];
    }

    final scopes = <ConversationScope>[];
    for (final entry in _windowMemberships.entries) {
      if (!entry.value.contains(stableKey)) {
        continue;
      }
      final scope = _scopeFromStorageKey(entry.key);
      if (scope != null) {
        scopes.add(scope);
      }
    }
    for (final entry in _activeRanges.entries) {
      if (!entry.value.stableKeys.contains(stableKey)) {
        continue;
      }
      final scope = _scopeFromStorageKey(entry.key);
      if (scope != null && !scopes.contains(scope)) {
        scopes.add(scope);
      }
    }
    return scopes;
  }

  void upsertCanonicalMessage(ConversationMessage message) {
    _upsertCanonical(message);
  }

  void removeMessageByStableKey(String stableKey) {
    final message = _messagesByStableKey.remove(stableKey);
    if (message == null) {
      return;
    }
    if (message.serverMessageId case final int serverMessageId) {
      _stableKeyByServerId.remove(serverMessageId);
    }
    if (message.clientGeneratedId.isNotEmpty) {
      _stableKeyByClientGeneratedId.remove(message.clientGeneratedId);
      _pendingOptimisticThreadReplyClientIds.remove(message.clientGeneratedId);
    }
    for (final window in _windowMemberships.values) {
      window.remove(stableKey);
    }
    for (final range in _activeRanges.values) {
      range.stableKeys.remove(stableKey);
    }
  }

  ConversationMessage? selectChatPreview(String chatId) {
    final scope = ConversationScope.chat(chatId: chatId);
    final keys = _windowMemberships[scope.storageKey] ?? const <String>[];
    for (var index = keys.length - 1; index >= 0; index -= 1) {
      final message = _messagesByStableKey[keys[index]];
      if (message == null || message.isDeleted || _isThreadReply(message)) {
        continue;
      }
      return message;
    }
    return null;
  }

  ConversationMessage? selectThreadPreview({
    required String chatId,
    required int threadAnchorId,
  }) {
    final scope = ConversationScope.thread(
      chatId: chatId,
      threadRootId: threadAnchorId.toString(),
    );
    final keys = _windowMemberships[scope.storageKey] ?? const <String>[];
    for (var index = keys.length - 1; index >= 0; index -= 1) {
      final message = _messagesByStableKey[keys[index]];
      if (message == null || message.isDeleted) {
        continue;
      }
      if (message.replyRootId == threadAnchorId) {
        return message;
      }
    }
    return null;
  }

  MessageThreadAnchorState? selectThreadAnchorState(int messageId) {
    return _threadAnchorStates[messageId];
  }

  ReplyToMessage? selectReplyReference(int messageId) {
    final stableKey = _stableKeyByServerId[messageId];
    if (stableKey == null) {
      return null;
    }
    final message = _messagesByStableKey[stableKey];
    if (message == null) {
      return null;
    }
    return ReplyToMessage(
      id: messageId,
      message: message.message,
      messageType: message.messageType,
      sticker: message.sticker,
      sender: message.sender,
      isDeleted: message.isDeleted,
      attachments: message.attachments,
      reactions: message.reactions,
      firstAttachmentKind: message.attachments.firstOrNull?.kind,
      mentions: message.mentions,
    );
  }

  bool isThreadRemoved(int threadAnchorId) {
    return !_threadAnchorStates.containsKey(threadAnchorId) &&
        !_hasThreadWindowForAnchor(threadAnchorId);
  }

  String _nextLocalMessageKey() {
    _nextLocalMessageId += 1;
    return 'local-$_nextLocalMessageId';
  }

  bool _isThreadReply(ConversationMessage message) =>
      message.replyRootId != null;

  ConversationScope _canonicalScopeForFetchedMessage(
    ConversationScope requestedScope,
    ConversationMessage message,
  ) {
    if (!requestedScope.isThread) {
      return requestedScope;
    }
    final threadRootId = requestedScope.threadRootId;
    if (threadRootId == null) {
      return requestedScope;
    }
    final anchorId = int.parse(threadRootId);
    final isAnchorMessage =
        message.replyRootId == null && message.serverMessageId == anchorId;
    if (isAnchorMessage) {
      return ConversationScope.chat(chatId: requestedScope.chatId);
    }
    return requestedScope;
  }

  bool _isThreadAnchor(ConversationMessage message) {
    final messageId = message.serverMessageId;
    if (messageId == null || _isThreadReply(message)) {
      return false;
    }
    return _threadAnchorStates.containsKey(messageId) ||
        _hasThreadWindowForAnchor(messageId, chatId: message.scope.chatId);
  }

  bool _hasThreadWindowForAnchor(int anchorId, {String? chatId}) {
    if (chatId case final String resolvedChatId) {
      final storageKey = ConversationScope.thread(
        chatId: resolvedChatId,
        threadRootId: anchorId.toString(),
      ).storageKey;
      return _windowMemberships.containsKey(storageKey) ||
          _activeRanges.containsKey(storageKey);
    }

    for (final windowKey in _windowMemberships.keys) {
      if (windowKey.endsWith('::thread::$anchorId')) {
        return true;
      }
    }
    for (final windowKey in _activeRanges.keys) {
      if (windowKey.endsWith('::thread::$anchorId')) {
        return true;
      }
    }
    return false;
  }

  ConversationScope? _scopeFromStorageKey(String storageKey) {
    const threadMarker = '::thread::';
    if (!storageKey.contains(threadMarker)) {
      return ConversationScope.chat(chatId: storageKey);
    }

    final parts = storageKey.split(threadMarker);
    if (parts.length != 2) {
      return null;
    }
    return ConversationScope.thread(
      chatId: parts.first,
      threadRootId: parts.last,
    );
  }

  String? _threadAnchorStableKey(ConversationScope scope) {
    final threadRootId = scope.threadRootId;
    if (threadRootId == null) {
      return null;
    }
    return _stableKeyByServerId[int.parse(threadRootId)];
  }

  List<String> _paginatableStableKeys(ConversationScope scope) {
    final visibleKeys = _canonicalPersistedStableKeys(scope);
    final anchorKey = _threadAnchorStableKey(scope);
    if (anchorKey == null) {
      return visibleKeys;
    }
    return visibleKeys
        .where((stableKey) => stableKey != anchorKey)
        .toList(growable: false);
  }

  List<String> _paginatableSubset(
    ConversationScope scope,
    List<String> stableKeys,
  ) {
    final anchorKey = _threadAnchorStableKey(scope);
    if (anchorKey == null) {
      return List<String>.from(stableKeys);
    }
    return stableKeys
        .where((stableKey) => stableKey != anchorKey)
        .toList(growable: false);
  }

  String? _resolvePagingStableKey(
    ConversationScope scope,
    List<String> currentWindow, {
    required String requestedStableKey,
    required bool preferOldest,
  }) {
    final anchorKey = _threadAnchorStableKey(scope);
    if (anchorKey == null || requestedStableKey != anchorKey) {
      return requestedStableKey;
    }
    final paginatableKeys = _paginatableSubset(scope, currentWindow);
    if (paginatableKeys.isEmpty) {
      return null;
    }
    return preferOldest ? paginatableKeys.first : paginatableKeys.last;
  }

  List<String> _composeWindowWithAnchor(
    ConversationScope scope,
    List<String> paginatableKeys,
  ) {
    final anchorKey = _threadAnchorStableKey(scope);
    if (anchorKey == null) {
      return paginatableKeys;
    }
    return <String>[
      if (_messagesByStableKey.containsKey(anchorKey) &&
          isVisibleInWindow(scope: scope, stableKey: anchorKey))
        anchorKey,
      ...paginatableKeys,
    ];
  }

  List<String> _normalizeRangeStableKeys(
    ConversationScope scope,
    List<String> stableKeys,
  ) {
    final deduped = <String>[];
    final seen = <String>{};
    for (final stableKey in stableKeys) {
      if (!seen.add(stableKey)) {
        continue;
      }
      final message = _messagesByStableKey[stableKey];
      if (message == null || !_isVisibleInWindow(message, scope)) {
        continue;
      }
      deduped.add(stableKey);
    }

    final anchorKey = _threadAnchorStableKey(scope);
    if (anchorKey == null) {
      return deduped;
    }
    final next = deduped.where((stableKey) => stableKey != anchorKey).toList();
    if (_messagesByStableKey.containsKey(anchorKey) &&
        isVisibleInWindow(scope: scope, stableKey: anchorKey)) {
      next.insert(0, anchorKey);
    }
    return next;
  }

  List<String> _latestProjectedStableKeys(
    ConversationScope scope, {
    required int limit,
  }) {
    final persistedKeys = _canonicalPersistedStableKeys(scope);
    if (persistedKeys.isEmpty) {
      return _localVisibleStableKeys(scope);
    }
    if (!scope.isThread) {
      final start = (persistedKeys.length - limit).clamp(
        0,
        persistedKeys.length,
      );
      return _normalizeRangeStableKeys(scope, <String>[
        ...persistedKeys.sublist(start),
        ..._localVisibleStableKeys(scope),
      ]);
    }

    final anchorKey = _threadAnchorStableKey(scope);
    final replyKeys = persistedKeys
        .where((stableKey) => stableKey != anchorKey)
        .toList(growable: false);
    if (limit <= 1) {
      return anchorKey == null ? const <String>[] : <String>[anchorKey];
    }
    final start = (replyKeys.length - (limit - 1)).clamp(0, replyKeys.length);
    return _normalizeRangeStableKeys(scope, <String>[
      ?anchorKey,
      ...replyKeys.sublist(start),
      ..._localVisibleStableKeys(scope),
    ]);
  }

  List<String> _canonicalPersistedStableKeys(ConversationScope scope) {
    final persistedMessages =
        _messagesByStableKey.values
            .where((message) => message.serverMessageId != null)
            .where((message) => _messageBelongsToScope(message, scope))
            .where((message) => _isVisibleInWindow(message, scope))
            .toList(growable: false)
          ..sort(
            (left, right) =>
                left.serverMessageId!.compareTo(right.serverMessageId!),
          );
    if (!scope.isThread) {
      return persistedMessages
          .map((message) => message.stableKey)
          .toList(growable: false);
    }

    final anchorKey = _threadAnchorStableKey(scope);
    final replyKeys = persistedMessages
        .where((message) => message.replyRootId != null)
        .map((message) => message.stableKey)
        .toList(growable: false);
    return <String>[?anchorKey, ...replyKeys];
  }

  List<String> _localVisibleStableKeys(ConversationScope scope) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final localMessages =
        _messagesByStableKey.values
            .where((message) => message.serverMessageId == null)
            .where((message) => _messageBelongsToScope(message, scope))
            .where((message) => _isVisibleInWindow(message, scope))
            .toList(growable: false)
          ..sort((left, right) {
            final byCreatedAt = (left.createdAt ?? epoch).compareTo(
              right.createdAt ?? epoch,
            );
            if (byCreatedAt != 0) {
              return byCreatedAt;
            }
            return left.stableKey.compareTo(right.stableKey);
          });
    return localMessages
        .map((message) => message.stableKey)
        .toList(growable: false);
  }

  bool _messageBelongsToScope(
    ConversationMessage message,
    ConversationScope scope,
  ) {
    if (message.scope.chatId != scope.chatId) {
      return false;
    }
    final threadRootId = scope.threadRootId;
    if (threadRootId == null) {
      return message.replyRootId == null;
    }
    final anchorId = int.tryParse(threadRootId);
    return message.serverMessageId == anchorId ||
        message.replyRootId == anchorId;
  }

  void _mergeFetchedCanonicalMessages({
    required ConversationScope scope,
    required List<ConversationMessage> messages,
  }) {
    for (final message in messages) {
      final scoped = message.copyWith(
        scope: _canonicalScopeForFetchedMessage(scope, message),
        deliveryState: ConversationDeliveryState.confirmed,
      );
      final merged = _mergeIncoming(scoped);
      if (_isThreadReply(merged)) {
        _ensureThreadWindowContainsAnchor(
          chatId: scope.chatId,
          anchorId: merged.replyRootId!,
        );
      } else {
        _syncThreadAnchorStateFromMessage(merged);
      }
    }

    if (scope.threadRootId case final String threadRootId) {
      _ensureThreadWindowContainsAnchor(
        chatId: scope.chatId,
        anchorId: int.parse(threadRootId),
      );
    }
  }

  ConversationMessage _mergeIncoming(ConversationMessage incoming) {
    final serverMessageId = incoming.serverMessageId;
    if (serverMessageId != null) {
      final serverKey = _stableKeyByServerId[serverMessageId];
      if (serverKey != null) {
        final previous = _messagesByStableKey[serverKey];
        final merged = _mergeMessage(previous, incoming, stableKey: serverKey);
        _messagesByStableKey[serverKey] = merged;
        _indexMessage(merged, stableKey: serverKey);
        return merged;
      }
    }

    final clientGeneratedId = incoming.clientGeneratedId;
    if (clientGeneratedId.isNotEmpty) {
      final clientKey = _stableKeyByClientGeneratedId[clientGeneratedId];
      if (clientKey != null) {
        final previous = _messagesByStableKey[clientKey];
        final merged = _mergeMessage(previous, incoming);
        _replaceStableKey(clientKey, merged.stableKey);
        _messagesByStableKey.remove(clientKey);
        _messagesByStableKey[merged.stableKey] = merged;
        _indexMessage(merged);
        return merged;
      }
    }

    _messagesByStableKey[incoming.stableKey] = incoming;
    _indexMessage(incoming);
    return incoming;
  }

  ConversationMessage _mergeMessage(
    ConversationMessage? previous,
    ConversationMessage incoming, {
    String? stableKey,
  }) {
    final resolvedThreadInfo =
        incoming.threadInfo ??
        _threadInfoFromAnchorState(incoming.serverMessageId);
    return incoming.copyWith(
      localMessageId: previous?.localMessageId,
      threadInfo: resolvedThreadInfo,
      deliveryState: _resolveDeliveryState(
        previous: previous?.deliveryState,
        incoming: incoming.deliveryState,
      ),
    );
  }

  ConversationDeliveryState _resolveDeliveryState({
    ConversationDeliveryState? previous,
    required ConversationDeliveryState incoming,
  }) {
    if (previous == ConversationDeliveryState.confirmed &&
        (incoming == ConversationDeliveryState.sending ||
            incoming == ConversationDeliveryState.sent)) {
      return ConversationDeliveryState.confirmed;
    }
    return incoming;
  }

  void _upsertCanonical(ConversationMessage message) {
    _messagesByStableKey[message.stableKey] = message;
    _indexMessage(message);
  }

  void _indexMessage(ConversationMessage message, {String? stableKey}) {
    final resolvedStableKey = stableKey ?? message.stableKey;
    if (message.serverMessageId case final int serverMessageId) {
      _stableKeyByServerId[serverMessageId] = resolvedStableKey;
    }
    if (message.clientGeneratedId.isNotEmpty) {
      _stableKeyByClientGeneratedId[message.clientGeneratedId] =
          resolvedStableKey;
    }
  }

  void _ensureInLatestWindow(ConversationScope scope, String stableKey) {
    final window = List<String>.from(
      _windowMemberships.putIfAbsent(scope.storageKey, () => <String>[]),
    );
    if (!window.contains(stableKey)) {
      window.add(stableKey);
    }
    _windowMemberships[scope.storageKey] = window;
  }

  void _ensureInActiveRangeIfTracked(
    ConversationScope scope,
    String stableKey,
  ) {
    final range = _activeRanges[scope.storageKey];
    if (range == null || range.stableKeys.contains(stableKey)) {
      return;
    }
    _activeRanges[scope.storageKey] = range.copyWith(
      stableKeys: <String>[...range.stableKeys, stableKey],
    );
  }

  void _ensureThreadWindowContainsAnchor({
    required String chatId,
    required int anchorId,
  }) {
    final scope = ConversationScope.thread(
      chatId: chatId,
      threadRootId: anchorId.toString(),
    );
    final window = _windowMemberships.putIfAbsent(
      scope.storageKey,
      () => <String>[],
    );
    final stableKey = _stableKeyByServerId[anchorId];
    if (stableKey == null) {
      return;
    }

    final existingIndex = window.indexOf(stableKey);
    if (existingIndex == 0) {
      return;
    }
    if (existingIndex > 0) {
      window.removeAt(existingIndex);
    }
    window.insert(0, stableKey);
  }

  void _replaceStableKey(String oldKey, String newKey) {
    for (final window in _windowMemberships.values) {
      final index = window.indexOf(oldKey);
      if (index >= 0) {
        window[index] = newKey;
      }
    }
    for (final range in _activeRanges.values) {
      final index = range.stableKeys.indexOf(oldKey);
      if (index >= 0) {
        range.stableKeys[index] = newKey;
      }
    }
  }

  void _syncThreadAnchorStateFromMessage(ConversationMessage message) {
    final messageId = message.serverMessageId;
    if (messageId == null || _isThreadReply(message)) {
      return;
    }
    final threadInfo = message.threadInfo;
    if (threadInfo == null) {
      return;
    }
    final previous = _threadAnchorStates[messageId];
    _threadAnchorStates[messageId] = MessageThreadAnchorState(
      replyCount: threadInfo.replyCount,
      lastReplyAt: previous?.lastReplyAt,
    );
  }

  void _patchAnchorThreadInfo(int anchorId, ThreadInfo? threadInfo) {
    final stableKey = _stableKeyByServerId[anchorId];
    if (stableKey == null) {
      return;
    }
    final current = _messagesByStableKey[stableKey];
    if (current == null) {
      return;
    }
    _messagesByStableKey[stableKey] = current.copyWith(threadInfo: threadInfo);
  }

  ThreadInfo? _threadInfoFromAnchorState(int? messageId) {
    if (messageId == null) {
      return null;
    }
    final state = _threadAnchorStates[messageId];
    if (state == null) {
      return null;
    }
    return ThreadInfo(replyCount: state.replyCount);
  }

  void _incrementThreadAnchorReplyCount(
    int anchorId, {
    required String chatId,
  }) {
    final current = _threadAnchorStates[anchorId];
    final latestReplyAt = _latestVisibleReplyAt(anchorId, chatId: chatId);
    final next = MessageThreadAnchorState(
      replyCount: (current?.replyCount ?? 0) + 1,
      lastReplyAt: latestReplyAt ?? current?.lastReplyAt,
    );
    _threadAnchorStates[anchorId] = next;
    _patchAnchorThreadInfo(anchorId, ThreadInfo(replyCount: next.replyCount));
  }

  void _decrementThreadAnchorReplyCount(
    int anchorId, {
    required String chatId,
  }) {
    final current = _threadAnchorStates[anchorId];
    if (current == null) {
      return;
    }
    final nextCount = current.replyCount > 0 ? current.replyCount - 1 : 0;
    final latestReplyAt = _latestVisibleReplyAt(anchorId, chatId: chatId);
    final next = MessageThreadAnchorState(
      replyCount: nextCount,
      lastReplyAt: nextCount == 0
          ? null
          : (latestReplyAt ?? current.lastReplyAt),
    );
    _threadAnchorStates[anchorId] = next;
    _patchAnchorThreadInfo(anchorId, ThreadInfo(replyCount: next.replyCount));
  }

  void _recomputeThreadAnchorSummary(int anchorId, {required String chatId}) {
    final current = _threadAnchorStates[anchorId];
    if (current == null) {
      return;
    }
    final scope = ConversationScope.thread(
      chatId: chatId,
      threadRootId: anchorId.toString(),
    );
    final keys = _windowMemberships[scope.storageKey] ?? const <String>[];
    var replyCount = 0;
    for (final stableKey in keys) {
      final message = _messagesByStableKey[stableKey];
      if (message == null ||
          message.isDeleted ||
          message.replyRootId != anchorId) {
        continue;
      }
      replyCount += 1;
    }
    final latestReplyAt = _latestVisibleReplyAt(anchorId, chatId: chatId);
    final next = MessageThreadAnchorState(
      replyCount: replyCount,
      lastReplyAt: replyCount == 0 ? null : latestReplyAt,
    );
    _threadAnchorStates[anchorId] = next;
    _patchAnchorThreadInfo(anchorId, ThreadInfo(replyCount: next.replyCount));
  }

  DateTime? _latestVisibleReplyAt(int anchorId, {required String chatId}) {
    final scope = ConversationScope.thread(
      chatId: chatId,
      threadRootId: anchorId.toString(),
    );
    final keys = _windowMemberships[scope.storageKey] ?? const <String>[];
    for (var index = keys.length - 1; index >= 0; index -= 1) {
      final message = _messagesByStableKey[keys[index]];
      if (message == null ||
          message.isDeleted ||
          message.replyRootId != anchorId) {
        continue;
      }
      return message.createdAt;
    }
    return null;
  }

  _DeleteTransaction _buildDeleteTransaction(ConversationMessage message) {
    final stableKey = message.stableKey;
    final membershipPatches = <_WindowMembershipPatch>[];
    for (final entry in _windowMemberships.entries) {
      if (!entry.value.contains(stableKey)) {
        continue;
      }
      if (!_shouldRemoveFromWindowOnDelete(message, entry.key)) {
        continue;
      }
      membershipPatches.add(
        _WindowMembershipPatch(
          windowKey: entry.key,
          index: entry.value.indexOf(stableKey),
        ),
      );
    }
    for (final entry in _activeRanges.entries) {
      if (!entry.value.stableKeys.contains(stableKey)) {
        continue;
      }
      if (!_shouldRemoveFromWindowOnDelete(message, entry.key)) {
        continue;
      }
      membershipPatches.add(
        _WindowMembershipPatch(
          windowKey: entry.key,
          index: entry.value.stableKeys.indexOf(stableKey),
        ),
      );
    }

    final summaryAnchorId = message.replyRootId;
    return _DeleteTransaction(
      message: message,
      membershipPatches: membershipPatches,
      summaryAnchorId: summaryAnchorId,
    );
  }

  void _applyDeleteVisibility(
    ConversationMessage message, {
    required String stableKey,
    required bool summaryAlreadyAdjusted,
  }) {
    for (final entry in _windowMemberships.entries) {
      if (_shouldRemoveFromWindowOnDelete(message, entry.key)) {
        entry.value.remove(stableKey);
      }
    }
    for (final entry in _activeRanges.entries) {
      if (_shouldRemoveFromWindowOnDelete(message, entry.key)) {
        entry.value.stableKeys.remove(stableKey);
      }
    }

    if (message.replyRootId case final int replyAnchorId
        when !summaryAlreadyAdjusted) {
      _decrementThreadAnchorReplyCount(
        replyAnchorId,
        chatId: message.scope.chatId,
      );
    }

    final anchorId = message.serverMessageId;
    if (anchorId != null && _isThreadAnchor(message)) {
      _patchAnchorThreadInfo(anchorId, _threadInfoFromAnchorState(anchorId));
      _ensureThreadWindowContainsAnchor(
        chatId: message.scope.chatId,
        anchorId: anchorId,
      );
    }
  }

  bool _shouldRemoveFromWindowOnDelete(
    ConversationMessage message,
    String windowKey,
  ) {
    if (_isThreadAnchor(message)) {
      return false;
    }
    return _windowMemberships[windowKey]?.contains(message.stableKey) ?? false;
  }

  bool _shouldPreserveDuringRefresh(
    ConversationScope scope,
    ConversationMessage message,
  ) {
    if (message.isLocalOnly) {
      return message.isPending || message.isFailed;
    }
    return message.isDeleted && _shouldKeepDeletedAnchorVisible(message, scope);
  }

  bool _isVisibleInWindow(
    ConversationMessage message,
    ConversationScope scope,
  ) {
    if (!message.isDeleted) {
      return true;
    }
    return _shouldKeepDeletedAnchorVisible(message, scope);
  }

  bool _shouldKeepDeletedAnchorVisible(
    ConversationMessage message,
    ConversationScope scope,
  ) {
    if (!_isThreadAnchor(message) || _isThreadReply(message)) {
      return false;
    }
    if (scope.threadRootId case final String threadRootId) {
      return message.serverMessageId?.toString() == threadRootId;
    }
    return message.scope.chatId == scope.chatId;
  }

  void _insertStableKey(List<String> window, String stableKey, int index) {
    if (window.contains(stableKey)) {
      return;
    }
    final resolvedIndex = index < 0
        ? 0
        : (index > window.length ? window.length : index);
    window.insert(resolvedIndex, stableKey);
  }
}

class _DeleteTransaction {
  const _DeleteTransaction({
    required this.message,
    required this.membershipPatches,
    required this.summaryAnchorId,
  });

  final ConversationMessage message;
  final List<_WindowMembershipPatch> membershipPatches;
  final int? summaryAnchorId;
}

class _WindowMembershipPatch {
  const _WindowMembershipPatch({required this.windowKey, required this.index});

  final String windowKey;
  final int index;
}
