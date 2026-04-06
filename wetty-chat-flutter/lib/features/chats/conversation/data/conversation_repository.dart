import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/websocket_api_models.dart';
import '../../../../core/network/websocket_service.dart';
import '../../detail/data/message_api_service.dart';
import '../../models/message_models.dart';
import 'conversation_api_mapper.dart';
import 'conversation_store.dart';
import '../models/conversation_models.dart';

class ConversationRepository {
  ConversationRepository({
    required this.scope,
    required MessageApiService service,
  }) : _service = service;

  static const int defaultWindowSize = 100;
  static const int defaultPageSize = 40;

  final ConversationScope scope;
  final MessageApiService _service;
  final ConversationStore _store = ConversationStore();
  final StreamController<void> _changes = StreamController<void>.broadcast();

  ConversationViewportCache _viewportCache = const ConversationViewportCache();
  String _draft = '';
  bool _hasReachedOldest = false;
  bool _hasReachedNewest = true;
  int _localIdCounter = 0;

  Stream<void> get changes => _changes.stream;
  ConversationViewportCache get viewportCache => _viewportCache;
  String get draft => _draft;
  bool get hasWarmWindow => _viewportCache.visibleMessageIds.isNotEmpty;

  List<ConversationMessage> latestSync({int limit = defaultWindowSize}) {
    return _store.latest(limit: limit);
  }

  TimelineWindow currentAroundSync(
    int messageId, {
    int before = defaultWindowSize ~/ 2,
    int after = defaultWindowSize ~/ 2,
  }) {
    final messages = _store.around(messageId, before: before, after: after);
    return TimelineWindow(
      messages: messages,
      hasOlder: messageId == messages.lastServerId
          ? !_hasReachedOldest
          : (messages.lastServerId != null
                ? _store.hasOlderAdjacent(messages.lastServerId!) ||
                      !_hasReachedOldest
                : false),
      hasNewer: messages.firstServerId != null
          ? _store.hasNewerAdjacent(messages.firstServerId!) ||
                !_hasReachedNewest
          : false,
      anchorMessageId: messageId,
    );
  }

  bool hasOlderAvailable(int oldestVisibleServerId) {
    return _store.hasOlderAdjacent(oldestVisibleServerId) || !_hasReachedOldest;
  }

  bool hasNewerAvailable(int newestVisibleServerId) {
    return _store.hasNewerAdjacent(newestVisibleServerId) || !_hasReachedNewest;
  }

  Future<TimelineWindow> loadLatest({int limit = defaultWindowSize}) async {
    final response = await _service.fetchMessages(
      scope.chatId,
      max: limit,
      threadId: _threadId,
    );
    final messages = response.messages
        .map((message) => message.toConversationMessage(scope))
        .toList(growable: false);
    _store.clear();
    _store.mergeServerMessages(messages);
    _hasReachedNewest = true;
    _hasReachedOldest = messages.length < limit;
    final window = TimelineWindow(
      messages: _store.latest(limit: limit),
      hasOlder: !_hasReachedOldest,
      hasNewer: false,
    );
    _cacheWindow(
      launchRequest: const LaunchLatestRequest(),
      anchorMessageId: window.messages.firstOrNull?.serverId,
      visibleMessageIds: window.messages.serverIds,
      isAtLiveEdge: true,
    );
    _emitChange();
    return window;
  }

  Future<TimelineWindow> refreshLatest({int limit = defaultWindowSize}) async {
    final response = await _service.fetchMessages(
      scope.chatId,
      max: limit,
      threadId: _threadId,
    );
    _store.mergeServerMessages(
      response.messages
          .map((message) => message.toConversationMessage(scope))
          .toList(growable: false),
    );
    _hasReachedNewest = true;
    _hasReachedOldest = response.messages.length < limit;
    final window = TimelineWindow(
      messages: _store.latest(limit: limit),
      hasOlder: !_hasReachedOldest,
      hasNewer: false,
    );
    _emitChange();
    return window;
  }

  Future<TimelineWindow> loadAround(
    int messageId, {
    int before = defaultWindowSize ~/ 2,
    int after = defaultWindowSize ~/ 2,
  }) async {
    var window = _store.around(messageId, before: before, after: after);
    if (window.isEmpty) {
      final response = await _service.fetchMessages(
        scope.chatId,
        around: messageId,
        max: before + after + 1,
        threadId: _threadId,
      );
      _store.mergeServerMessages(
        response.messages
            .map((message) => message.toConversationMessage(scope))
            .toList(growable: false),
      );
      window = _store.around(messageId, before: before, after: after);
    }
    final result = TimelineWindow(
      messages: window,
      hasOlder: window.lastServerId != null
          ? _store.hasOlderAdjacent(window.lastServerId!) || !_hasReachedOldest
          : false,
      hasNewer: window.firstServerId != null
          ? _store.hasNewerAdjacent(window.firstServerId!) || !_hasReachedNewest
          : false,
      anchorMessageId: messageId,
    );
    _cacheWindow(
      launchRequest: LaunchMessageRequest(messageId, highlight: false),
      anchorMessageId: messageId,
      visibleMessageIds: result.messages.serverIds,
      isAtLiveEdge: false,
    );
    _emitChange();
    return result;
  }

  Future<List<ConversationMessage>> loadOlder(
    int oldestVisibleServerId, {
    int pageSize = defaultPageSize,
  }) async {
    final cached = _store.olderThan(oldestVisibleServerId, limit: pageSize);
    if (cached.isNotEmpty) {
      return cached;
    }
    final response = await _service.fetchMessages(
      scope.chatId,
      before: oldestVisibleServerId,
      max: pageSize,
      threadId: _threadId,
    );
    final messages = response.messages
        .map((message) => message.toConversationMessage(scope))
        .toList(growable: false);
    _store.mergeServerMessages(messages);
    _hasReachedOldest = messages.length < pageSize;
    _emitChange();
    return _store.olderThan(oldestVisibleServerId, limit: pageSize);
  }

  Future<List<ConversationMessage>> loadNewer(
    int newestVisibleServerId, {
    int pageSize = defaultPageSize,
  }) async {
    final cached = _store.newerThan(newestVisibleServerId, limit: pageSize);
    if (cached.isNotEmpty) {
      return cached;
    }
    final response = await _service.fetchMessages(
      scope.chatId,
      after: newestVisibleServerId,
      max: pageSize,
      threadId: _threadId,
    );
    final messages = response.messages
        .map((message) => message.toConversationMessage(scope))
        .toList(growable: false);
    _store.mergeServerMessages(messages);
    _hasReachedNewest = messages.length < pageSize;
    _emitChange();
    return _store.newerThan(newestVisibleServerId, limit: pageSize);
  }

  Future<int?> resolveFirstUnreadMessageId(int lastReadMessageId) async {
    final cached = _store.firstNewerServerId(lastReadMessageId);
    if (cached != null) {
      return cached;
    }
    final response = await _service.fetchMessages(
      scope.chatId,
      after: lastReadMessageId,
      max: 1,
      threadId: _threadId,
    );
    final messages = response.messages
        .map((message) => message.toConversationMessage(scope))
        .toList(growable: false);
    _store.mergeServerMessages(messages);
    _hasReachedNewest = messages.length < 1;
    _emitChange();
    return messages.firstOrNull?.serverId;
  }

  List<ConversationMessage> warmWindow({int limit = defaultWindowSize}) {
    if (_viewportCache.visibleMessageIds.isEmpty) {
      return _store.latest(limit: limit);
    }
    final messages = _viewportCache.visibleMessageIds
        .map(_store.messageByServerId)
        .whereType<ConversationMessage>()
        .toList(growable: false);
    return messages.isEmpty ? _store.latest(limit: limit) : messages;
  }

  void cacheDraft(String draft) {
    _draft = draft;
  }

  Future<void> markAsRead(int messageId) =>
      _service.markMessagesAsRead(scope.chatId, messageId);

  Future<void> applyRealtimeEvent(ApiWsEvent event) async {
    final payload = switch (event) {
      MessageCreatedWsEvent(:final payload) => payload,
      MessageUpdatedWsEvent(:final payload) => payload,
      MessageDeletedWsEvent(:final payload) => payload,
      _ => null,
    };
    if (payload == null || payload.chatId.toString() != scope.chatId) {
      return;
    }
    if (_threadId != null && payload.replyRootId != int.tryParse(_threadId!)) {
      return;
    }
    if (event is MessageDeletedWsEvent) {
      _store.tombstoneMessage(payload.id);
    } else {
      _store.mergeServerMessage(payload.toConversationMessage(scope));
    }
    _emitChange();
  }

  Future<ConversationMessage> sendMessage(
    String text, {
    int? replyToId,
    List<String> attachmentIds = const <String>[],
  }) async {
    final clientGeneratedId = _service.nextClientGeneratedId();
    final optimistic = ConversationMessage(
      localId: 'temp-${++_localIdCounter}',
      clientGeneratedId: clientGeneratedId,
      scope: scope,
      message: text,
      messageType: 'text',
      sender: const Sender(uid: 0, name: 'You'),
      createdAt: DateTime.now(),
      isEdited: false,
      isDeleted: false,
      replyRootId: scope is ThreadConversationScope
          ? (scope as ThreadConversationScope).threadRootId
          : null,
      hasAttachments: attachmentIds.isNotEmpty,
      attachments: const <AttachmentItem>[],
      deliveryState: ConversationDeliveryState.sending,
    );
    _store.insertOptimisticMessage(optimistic);
    _emitChange();

    try {
      final created = await _service.sendMessage(
        scope.chatId,
        text,
        replyToId: replyToId,
        threadId: _threadId,
        attachmentIds: attachmentIds,
        clientGeneratedId: clientGeneratedId,
      );
      final message = created.toConversationMessage(scope);
      _store.mergeServerMessage(message);
      _emitChange();
      return message;
    } catch (_) {
      _store.updateMessage(
        optimistic.copyWith(deliveryState: ConversationDeliveryState.failed),
      );
      _emitChange();
      rethrow;
    }
  }

  Future<ConversationMessage> editMessage(int messageId, String text) async {
    final existing = _store.messageByServerId(messageId);
    if (existing != null) {
      _store.updateMessage(
        existing.copyWith(
          message: text,
          deliveryState: ConversationDeliveryState.editing,
          isEdited: true,
        ),
      );
      _emitChange();
    }
    try {
      final updated = await _service.editMessage(scope.chatId, messageId, text);
      final message = updated.toConversationMessage(scope);
      _store.mergeServerMessage(message);
      _emitChange();
      return message;
    } catch (_) {
      if (existing != null) {
        _store.updateMessage(existing);
        _emitChange();
      }
      rethrow;
    }
  }

  Future<void> deleteMessage(int messageId) async {
    final existing = _store.messageByServerId(messageId);
    if (existing != null) {
      _store.updateMessage(
        existing.copyWith(deliveryState: ConversationDeliveryState.deleting),
      );
      _emitChange();
    }
    try {
      await _service.deleteMessage(scope.chatId, messageId);
      _store.tombstoneMessage(messageId);
      _emitChange();
    } catch (_) {
      if (existing != null) {
        _store.updateMessage(existing);
        _emitChange();
      }
      rethrow;
    }
  }

  List<TimelineEntry> buildTimelineEntries({
    required List<ConversationMessage> messages,
    int? unreadMarkerMessageId,
    bool isLoadingOlder = false,
    bool isLoadingNewer = false,
    bool hasOlder = false,
    bool hasNewer = false,
  }) {
    final entries = <TimelineEntry>[];
    if (isLoadingOlder) {
      entries.add(const TimelineLoadingOlderEntry());
    } else if (hasOlder) {
      entries.add(const TimelineHistoryGapOlderEntry());
    }
    DateTime? previousDay;
    for (var index = messages.length - 1; index >= 0; index--) {
      final message = messages[index];
      final day = _calendarDay(message.createdAt);
      if (day != null && (previousDay == null || !_sameDay(previousDay, day))) {
        entries.insert(
          0,
          TimelineDateSeparatorEntry(
            date: day,
            key: 'date:${day.toIso8601String()}',
          ),
        );
        previousDay = day;
      }
      entries.insert(0, TimelineMessageEntry(message: message));
      if (unreadMarkerMessageId != null &&
          message.serverId == unreadMarkerMessageId) {
        entries.insert(0, const TimelineUnreadMarkerEntry());
      }
    }
    if (isLoadingNewer) {
      entries.insert(0, const TimelineLoadingNewerEntry());
    } else if (hasNewer) {
      entries.insert(0, const TimelineHistoryGapNewerEntry());
    }
    return entries;
  }

  void cacheViewport({
    required LaunchRequest launchRequest,
    required int? anchorMessageId,
    required List<int> visibleMessageIds,
    required bool isAtLiveEdge,
  }) {
    _cacheWindow(
      launchRequest: launchRequest,
      anchorMessageId: anchorMessageId,
      visibleMessageIds: visibleMessageIds,
      isAtLiveEdge: isAtLiveEdge,
    );
  }

  void _cacheWindow({
    required LaunchRequest launchRequest,
    required int? anchorMessageId,
    required List<int> visibleMessageIds,
    required bool isAtLiveEdge,
  }) {
    _viewportCache = ConversationViewportCache(
      launchRequest: launchRequest,
      anchorMessageId: anchorMessageId,
      visibleMessageIds: visibleMessageIds,
      isAtLiveEdge: isAtLiveEdge,
    );
  }

  void _emitChange() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  String? get _threadId => switch (scope) {
    ThreadConversationScope(:final threadRootId) => '$threadRootId',
    _ => null,
  };

  DateTime? _calendarDay(DateTime? value) {
    if (value == null) {
      return null;
    }
    return DateTime(value.year, value.month, value.day);
  }

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

class ConversationRepositoryCache {
  static final Map<String, ConversationRepository> _cache = {};

  static ConversationRepository instance({
    required ConversationScope scope,
    required MessageApiService service,
  }) {
    return _cache.putIfAbsent(
      scope.cacheKey,
      () => ConversationRepository(scope: scope, service: service),
    );
  }
}

final conversationRepositoryProvider =
    Provider.family<ConversationRepository, ConversationScope>((ref, scope) {
      final repository = ConversationRepositoryCache.instance(
        scope: scope,
        service: ref.watch(messageApiServiceProvider),
      );
      ref.listen<AsyncValue<ApiWsEvent>>(wsEventsProvider, (_, next) {
        final event = next.valueOrNull;
        if (event != null) {
          unawaited(repository.applyRealtimeEvent(event));
        }
      });
      return repository;
    });

extension on List<ConversationMessage> {
  List<int> get serverIds => map(
    (message) => message.serverId,
  ).whereType<int>().toList(growable: false);

  int? get firstServerId =>
      firstWhereOrNull((message) => message.serverId != null)?.serverId;

  int? get lastServerId =>
      lastWhereOrNull((message) => message.serverId != null)?.serverId;

  ConversationMessage? get firstOrNull => isEmpty ? null : first;

  ConversationMessage? firstWhereOrNull(
    bool Function(ConversationMessage message) test,
  ) {
    for (final message in this) {
      if (test(message)) {
        return message;
      }
    }
    return null;
  }

  ConversationMessage? lastWhereOrNull(
    bool Function(ConversationMessage message) test,
  ) {
    for (final message in reversed) {
      if (test(message)) {
        return message;
      }
    }
    return null;
  }
}
