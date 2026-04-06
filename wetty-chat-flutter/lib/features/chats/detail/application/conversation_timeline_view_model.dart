import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/websocket_api_models.dart';
import '../../../../core/network/websocket_service.dart';
import '../data/conversation_repository.dart';
import '../domain/conversation_message.dart';
import '../domain/conversation_scope.dart';
import '../domain/launch_request.dart';
import '../domain/timeline_entry.dart';

typedef ConversationTimelineArgs = ({
  ConversationScope scope,
  LaunchRequest launchRequest,
});

enum ConversationWindowMode { liveLatest, anchoredTarget, historyBrowsing }

enum ConversationLocateTarget { latest, message }

enum ConversationLocatePlacement { liveEdge, topPreferred }

enum ConversationLocateExecution { preparedViewport, interactiveViewport }

class ConversationLocatePlan {
  const ConversationLocatePlan._({
    required this.target,
    required this.placement,
    required this.execution,
    required this.revision,
    required this.viewportSessionId,
    this.messageId,
  });

  const ConversationLocatePlan.latest({
    required ConversationLocatePlacement placement,
    required ConversationLocateExecution execution,
    required int revision,
    required int viewportSessionId,
  }) : this._(
         target: ConversationLocateTarget.latest,
         placement: placement,
         execution: execution,
         revision: revision,
         viewportSessionId: viewportSessionId,
       );

  const ConversationLocatePlan.message({
    required int messageId,
    required ConversationLocatePlacement placement,
    required ConversationLocateExecution execution,
    required int revision,
    required int viewportSessionId,
  }) : this._(
         target: ConversationLocateTarget.message,
         placement: placement,
         execution: execution,
         revision: revision,
         viewportSessionId: viewportSessionId,
         messageId: messageId,
       );

  final ConversationLocateTarget target;
  final ConversationLocatePlacement placement;
  final ConversationLocateExecution execution;
  final int revision;
  final int viewportSessionId;
  final int? messageId;
}

class ConversationTimelineState {
  const ConversationTimelineState({
    required this.entries,
    required this.windowStableKeys,
    required this.windowMode,
    required this.canLoadOlder,
    required this.canLoadNewer,
    this.isLoadingOlder = false,
    this.isLoadingNewer = false,
    this.pendingLiveCount = 0,
    this.highlightedMessageId,
    this.anchorMessageId,
    this.unreadMarkerMessageId,
    this.infoMessage,
    this.shouldRefreshChats = false,
    this.locatePlan,
  });

  final List<TimelineEntry> entries;
  final List<String> windowStableKeys;
  final ConversationWindowMode windowMode;
  final bool canLoadOlder;
  final bool canLoadNewer;
  final bool isLoadingOlder;
  final bool isLoadingNewer;
  final int pendingLiveCount;
  final int? highlightedMessageId;
  final int? anchorMessageId;
  final int? unreadMarkerMessageId;
  final String? infoMessage;
  final bool shouldRefreshChats;
  final ConversationLocatePlan? locatePlan;

  ConversationTimelineState copyWith({
    List<TimelineEntry>? entries,
    List<String>? windowStableKeys,
    ConversationWindowMode? windowMode,
    bool? canLoadOlder,
    bool? canLoadNewer,
    bool? isLoadingOlder,
    bool? isLoadingNewer,
    int? pendingLiveCount,
    Object? highlightedMessageId = _sentinel,
    Object? anchorMessageId = _sentinel,
    Object? unreadMarkerMessageId = _sentinel,
    Object? infoMessage = _sentinel,
    bool? shouldRefreshChats,
    Object? locatePlan = _sentinel,
  }) {
    return ConversationTimelineState(
      entries: entries ?? this.entries,
      windowStableKeys: windowStableKeys ?? this.windowStableKeys,
      windowMode: windowMode ?? this.windowMode,
      canLoadOlder: canLoadOlder ?? this.canLoadOlder,
      canLoadNewer: canLoadNewer ?? this.canLoadNewer,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      isLoadingNewer: isLoadingNewer ?? this.isLoadingNewer,
      pendingLiveCount: pendingLiveCount ?? this.pendingLiveCount,
      highlightedMessageId: highlightedMessageId == _sentinel
          ? this.highlightedMessageId
          : highlightedMessageId as int?,
      anchorMessageId: anchorMessageId == _sentinel
          ? this.anchorMessageId
          : anchorMessageId as int?,
      unreadMarkerMessageId: unreadMarkerMessageId == _sentinel
          ? this.unreadMarkerMessageId
          : unreadMarkerMessageId as int?,
      infoMessage: infoMessage == _sentinel
          ? this.infoMessage
          : infoMessage as String?,
      shouldRefreshChats: shouldRefreshChats ?? this.shouldRefreshChats,
      locatePlan: locatePlan == _sentinel
          ? this.locatePlan
          : locatePlan as ConversationLocatePlan?,
    );
  }
}

class ConversationTimelineViewModel
    extends
        FamilyAsyncNotifier<
          ConversationTimelineState,
          ConversationTimelineArgs
        > {
  static const int _windowSize = ConversationRepository.defaultWindowSize;
  static const int _pageSize = ConversationRepository.pageSize;

  late final ConversationRepository _repository;
  Timer? _readSyncDebounceTimer;
  Timer? _highlightTimer;
  int? _currentReadId;
  int? _lastSyncedReadId;
  int _locateRevision = 0;
  int _viewportSessionId = 0;
  bool _isDisposed = false;

  @override
  Future<ConversationTimelineState> build(ConversationTimelineArgs arg) async {
    _repository = ref.read(conversationRepositoryProvider(arg.scope));

    ref.listen<AsyncValue<ApiWsEvent>>(wsEventsProvider, (_, next) {
      final event = next.valueOrNull;
      if (event != null) {
        _handleRealtimeEvent(event);
      }
    });

    ref.onDispose(() {
      _isDisposed = true;
      _readSyncDebounceTimer?.cancel();
      _highlightTimer?.cancel();
    });

    return _loadInitial(arg.launchRequest);
  }

  Future<ConversationTimelineState> _loadInitial(
    LaunchRequest launchRequest,
  ) async {
    switch (launchRequest.intent) {
      case LaunchRequestIntent.latest:
        final messages = await _repository.loadLatestWindow(limit: _windowSize);
        return _buildState(
          windowStableKeys: messages.map((item) => item.stableKey).toList(),
          windowMode: ConversationWindowMode.liveLatest,
          locatePlan: _nextLatestLocatePlan(
            execution: ConversationLocateExecution.preparedViewport,
          ),
        );
      case LaunchRequestIntent.unread:
      case LaunchRequestIntent.message:
        final anchorId = launchRequest.messageId!;
        final messages = await _repository.loadAroundMessage(
          anchorId,
          before: _windowSize ~/ 2,
          after: _windowSize ~/ 2,
        );
        if (messages.isEmpty) {
          final latest = await _repository.loadLatestWindow(limit: _windowSize);
          return _buildState(
            windowStableKeys: latest.map((item) => item.stableKey).toList(),
            windowMode: ConversationWindowMode.liveLatest,
            infoMessage: 'Message unavailable',
            locatePlan: _nextLatestLocatePlan(
              execution: ConversationLocateExecution.preparedViewport,
            ),
          );
        }
        final nextState = _buildState(
          windowStableKeys: messages.map((item) => item.stableKey).toList(),
          windowMode: ConversationWindowMode.anchoredTarget,
          anchorMessageId: anchorId,
          unreadMarkerMessageId: launchRequest.isUnread ? anchorId : null,
          highlightedMessageId:
              launchRequest.intent == LaunchRequestIntent.message &&
                  launchRequest.highlight
              ? anchorId
              : null,
          locatePlan: _nextMessageLocatePlan(
            anchorId,
            execution: ConversationLocateExecution.preparedViewport,
          ),
        );
        if (launchRequest.highlight) {
          _scheduleHighlightClear();
        }
        return nextState;
    }
  }

  ConversationTimelineState _buildState({
    required List<String> windowStableKeys,
    required ConversationWindowMode windowMode,
    int? anchorMessageId,
    int? unreadMarkerMessageId,
    int? highlightedMessageId,
    String? infoMessage,
    bool shouldRefreshChats = false,
    int pendingLiveCount = 0,
    ConversationLocatePlan? locatePlan,
  }) {
    final trimmed = _repository.trimWindowAroundAnchor(
      windowStableKeys,
      anchorMessageId: anchorMessageId,
    );
    return ConversationTimelineState(
      entries: _buildEntries(
        _repository.messagesForWindow(trimmed),
        unreadMarkerMessageId: unreadMarkerMessageId,
      ),
      windowStableKeys: trimmed,
      windowMode: windowMode,
      canLoadOlder: _repository.hasOlderOutsideWindow(trimmed),
      canLoadNewer: _repository.hasNewerOutsideWindow(trimmed),
      pendingLiveCount: pendingLiveCount,
      highlightedMessageId: highlightedMessageId,
      anchorMessageId: anchorMessageId,
      unreadMarkerMessageId: unreadMarkerMessageId,
      infoMessage: infoMessage,
      shouldRefreshChats: shouldRefreshChats,
      locatePlan: locatePlan,
    );
  }

  List<TimelineEntry> _buildEntries(
    List<ConversationMessage> messages, {
    int? unreadMarkerMessageId,
  }) {
    final entries = <TimelineEntry>[];
    DateTime? currentDay;
    for (final message in messages) {
      final day = message.createdAt == null
          ? null
          : DateTime(
              message.createdAt!.year,
              message.createdAt!.month,
              message.createdAt!.day,
            );
      if (day != null && day != currentDay) {
        currentDay = day;
        entries.add(TimelineDateSeparatorEntry(day: day));
      }
      if (unreadMarkerMessageId != null &&
          message.serverMessageId == unreadMarkerMessageId) {
        entries.add(const TimelineUnreadMarkerEntry());
      }
      entries.add(TimelineMessageEntry(message));
    }
    return entries;
  }

  void _handleRealtimeEvent(ApiWsEvent event) {
    if (!_repository.applyRealtimeEvent(event) || !state.hasValue) {
      return;
    }

    final current = state.requireValue;
    final isAtLiveEdge =
        current.windowMode == ConversationWindowMode.liveLatest &&
        !current.canLoadNewer;
    if (isAtLiveEdge) {
      final latestWindow = _repository.latestWindowStableKeys(
        limit: _windowSize,
      );
      _setStateIfActive(
        AsyncData(
          _buildState(
            windowStableKeys: latestWindow,
            windowMode: ConversationWindowMode.liveLatest,
            shouldRefreshChats: true,
          ),
        ),
      );
      return;
    }

    _setStateIfActive(
      AsyncData(
        _buildState(
          windowStableKeys: current.windowStableKeys,
          windowMode: current.windowMode,
          anchorMessageId: current.anchorMessageId,
          unreadMarkerMessageId: current.unreadMarkerMessageId,
          highlightedMessageId: current.highlightedMessageId,
          shouldRefreshChats: true,
          pendingLiveCount: current.pendingLiveCount + 1,
        ),
      ),
    );
  }

  Future<bool> loadOlder() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingOlder || !current.canLoadOlder) {
      return false;
    }
    _setStateIfActive(AsyncData(current.copyWith(isLoadingOlder: true)));
    final oldestStableKey = current.windowStableKeys.firstOrNull;
    if (oldestStableKey == null) {
      _setStateIfActive(AsyncData(current.copyWith(isLoadingOlder: false)));
      return false;
    }

    try {
      await _repository.extendOlder(
        anchorStableKey: oldestStableKey,
        pageSize: _pageSize,
      );
      final nextWindow = _repository.prependWindowPage(
        current.windowStableKeys,
        oldestStableKey,
      );
      _setStateIfActive(
        AsyncData(
          _buildState(
            windowStableKeys: nextWindow,
            windowMode: current.windowMode == ConversationWindowMode.liveLatest
                ? ConversationWindowMode.historyBrowsing
                : current.windowMode,
            anchorMessageId: current.anchorMessageId,
            unreadMarkerMessageId: current.unreadMarkerMessageId,
            highlightedMessageId: current.highlightedMessageId,
            pendingLiveCount: current.pendingLiveCount,
            shouldRefreshChats: current.shouldRefreshChats,
          ),
        ),
      );
      return true;
    } finally {
      final latest = state.valueOrNull;
      if (latest != null) {
        _setStateIfActive(AsyncData(latest.copyWith(isLoadingOlder: false)));
      }
    }
  }

  Future<bool> loadNewer() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingNewer || !current.canLoadNewer) {
      return false;
    }
    _setStateIfActive(AsyncData(current.copyWith(isLoadingNewer: true)));
    final newestStableKey = current.windowStableKeys.lastOrNull;
    if (newestStableKey == null) {
      _setStateIfActive(AsyncData(current.copyWith(isLoadingNewer: false)));
      return false;
    }

    try {
      await _repository.extendNewer(
        anchorStableKey: newestStableKey,
        pageSize: _pageSize,
      );
      final nextWindow = _repository.appendWindowPage(
        current.windowStableKeys,
        newestStableKey,
      );
      final reachedLiveEdge = !_repository.hasNewerOutsideWindow(nextWindow);
      _setStateIfActive(
        AsyncData(
          _buildState(
            windowStableKeys: nextWindow,
            windowMode: reachedLiveEdge
                ? ConversationWindowMode.liveLatest
                : ConversationWindowMode.historyBrowsing,
            anchorMessageId: reachedLiveEdge ? null : current.anchorMessageId,
            unreadMarkerMessageId: current.unreadMarkerMessageId,
            highlightedMessageId: current.highlightedMessageId,
            pendingLiveCount: reachedLiveEdge ? 0 : current.pendingLiveCount,
            shouldRefreshChats: current.shouldRefreshChats,
          ),
        ),
      );
      return true;
    } finally {
      final latest = state.valueOrNull;
      if (latest != null) {
        _setStateIfActive(AsyncData(latest.copyWith(isLoadingNewer: false)));
      }
    }
  }

  Future<void> jumpToLatest() async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    if (!_repository.hasNewerOutsideWindow(current.windowStableKeys)) {
      _setStateIfActive(
        AsyncData(
          _buildState(
            windowStableKeys: current.windowStableKeys,
            windowMode: ConversationWindowMode.liveLatest,
            shouldRefreshChats: current.shouldRefreshChats,
            locatePlan: _nextLatestLocatePlan(
              execution: ConversationLocateExecution.interactiveViewport,
            ),
          ),
        ),
      );
      return;
    }
    final latest = await _repository.refreshLatestWindow(limit: _windowSize);
    _setStateIfActive(
      AsyncData(
        _buildState(
          windowStableKeys: latest.map((item) => item.stableKey).toList(),
          windowMode: ConversationWindowMode.liveLatest,
          locatePlan: _nextLatestLocatePlan(
            execution: ConversationLocateExecution.preparedViewport,
          ),
        ),
      ),
    );
  }

  Future<bool> jumpToMessage(int messageId, {bool highlight = true}) async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }
    final targetIndex = _repository.findWindowIndex(
      current.windowStableKeys,
      messageId,
    );
    if (targetIndex != null) {
      _setStateIfActive(
        AsyncData(
          _buildState(
            windowStableKeys: current.windowStableKeys,
            windowMode: ConversationWindowMode.anchoredTarget,
            anchorMessageId: messageId,
            highlightedMessageId: highlight ? messageId : null,
            shouldRefreshChats: current.shouldRefreshChats,
            pendingLiveCount: current.pendingLiveCount,
            locatePlan: _nextMessageLocatePlan(
              messageId,
              execution: ConversationLocateExecution.interactiveViewport,
            ),
          ),
        ),
      );
      if (highlight) {
        _scheduleHighlightClear();
      }
      return true;
    }
    final messages = await _repository.loadAroundMessage(
      messageId,
      before: _windowSize ~/ 2,
      after: _windowSize ~/ 2,
    );
    if (messages.isEmpty) {
      _setStateIfActive(
        AsyncData(current.copyWith(infoMessage: 'Message unavailable')),
      );
      return false;
    }
    _setStateIfActive(
      AsyncData(
        _buildState(
          windowStableKeys: messages.map((item) => item.stableKey).toList(),
          windowMode: ConversationWindowMode.anchoredTarget,
          anchorMessageId: messageId,
          highlightedMessageId: highlight ? messageId : null,
          shouldRefreshChats: current.shouldRefreshChats,
          locatePlan: _nextMessageLocatePlan(
            messageId,
            execution: ConversationLocateExecution.preparedViewport,
          ),
        ),
      ),
    );
    if (highlight) {
      _scheduleHighlightClear();
    }
    return true;
  }

  void onMessageVisible(ConversationMessage message) {
    final messageId = message.serverMessageId;
    if (messageId == null) {
      return;
    }
    if (_currentReadId == null || messageId > _currentReadId!) {
      _currentReadId = messageId;
      _readSyncDebounceTimer?.cancel();
      _readSyncDebounceTimer = Timer(
        const Duration(milliseconds: 100),
        () => unawaited(_syncReadStatus()),
      );
    }
  }

  Future<bool> flushReadStatus() async {
    _readSyncDebounceTimer?.cancel();
    return _syncReadStatus();
  }

  Future<bool> _syncReadStatus() async {
    if (_currentReadId == null || _currentReadId == _lastSyncedReadId) {
      return false;
    }
    final toSync = _currentReadId!;
    await _repository.markAsRead(toSync);
    if (_isDisposed) {
      return false;
    }
    _lastSyncedReadId = toSync;
    final current = state.valueOrNull;
    if (current != null) {
      _setStateIfActive(AsyncData(current.copyWith(shouldRefreshChats: true)));
    }
    return true;
  }

  bool get shouldRefreshChats => state.valueOrNull?.shouldRefreshChats ?? false;

  void clearInfoMessage() {
    final current = state.valueOrNull;
    if (current == null || current.infoMessage == null) {
      return;
    }
    _setStateIfActive(AsyncData(current.copyWith(infoMessage: null)));
  }

  void _scheduleHighlightClear() {
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      final current = state.valueOrNull;
      if (current != null) {
        _setStateIfActive(
          AsyncData(current.copyWith(highlightedMessageId: null)),
        );
      }
    });
  }

  void _setStateIfActive(AsyncValue<ConversationTimelineState> nextState) {
    if (_isDisposed) {
      return;
    }
    state = nextState;
  }

  ConversationLocatePlan _nextLatestLocatePlan({
    required ConversationLocateExecution execution,
  }) => ConversationLocatePlan.latest(
    placement: ConversationLocatePlacement.liveEdge,
    execution: execution,
    revision: ++_locateRevision,
    viewportSessionId: _nextViewportSessionId(execution),
  );

  ConversationLocatePlan _nextMessageLocatePlan(
    int messageId, {
    required ConversationLocateExecution execution,
  }) => ConversationLocatePlan.message(
    messageId: messageId,
    placement: ConversationLocatePlacement.topPreferred,
    execution: execution,
    revision: ++_locateRevision,
    viewportSessionId: _nextViewportSessionId(execution),
  );

  int _nextViewportSessionId(ConversationLocateExecution execution) {
    if (execution == ConversationLocateExecution.preparedViewport) {
      _viewportSessionId += 1;
    }
    return _viewportSessionId;
  }
}

const _sentinel = Object();

final conversationTimelineViewModelProvider =
    AsyncNotifierProvider.family<
      ConversationTimelineViewModel,
      ConversationTimelineState,
      ConversationTimelineArgs
    >(ConversationTimelineViewModel.new);
