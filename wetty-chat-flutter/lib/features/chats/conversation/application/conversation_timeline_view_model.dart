import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/websocket_api_models.dart';
import '../../list/data/chat_repository.dart';
import 'conversation_local_mutation_registry.dart';
import 'conversation_cache_revision_registry.dart';
import 'conversation_realtime_registry.dart';
import '../data/conversation_repository.dart';
import '../domain/conversation_message.dart';
import '../domain/conversation_scope.dart';
import '../domain/launch_request.dart';
import '../domain/timeline_entry.dart';
import '../domain/viewport_placement.dart';

typedef ConversationTimelineArgs = ({
  ConversationScope scope,
  LaunchRequest launchRequest,
});

enum ConversationWindowMode { liveLatest, anchoredTarget, historyBrowsing }

enum ConversationViewportCommandType {
  showLatest,
  bootstrapTarget,
  scrollToLoadedTarget,
  preserveOnPrepend,
  preserveOnAppend,
  settleAtBottomAfterMutation,
  settleAtBottomAfterViewportResize,
}

class ConversationViewportCommand {
  const ConversationViewportCommand._({
    required this.transactionId,
    required this.type,
    required this.placement,
    this.messageId,
    this.anchorStableKey,
    this.anchorDy,
  });

  const ConversationViewportCommand.showLatest({
    required int transactionId,
    required ConversationViewportPlacement placement,
  }) : this._(
         transactionId: transactionId,
         type: ConversationViewportCommandType.showLatest,
         placement: placement,
       );

  const ConversationViewportCommand.bootstrapTarget({
    required int transactionId,
    required int messageId,
    required ConversationViewportPlacement placement,
  }) : this._(
         transactionId: transactionId,
         type: ConversationViewportCommandType.bootstrapTarget,
         placement: placement,
         messageId: messageId,
       );

  const ConversationViewportCommand.scrollToLoadedTarget({
    required int transactionId,
    required int messageId,
    required ConversationViewportPlacement placement,
  }) : this._(
         transactionId: transactionId,
         type: ConversationViewportCommandType.scrollToLoadedTarget,
         placement: placement,
         messageId: messageId,
       );

  const ConversationViewportCommand.preserveOnPrepend({
    required int transactionId,
    required String anchorStableKey,
    required double anchorDy,
    required ConversationViewportPlacement placement,
  }) : this._(
         transactionId: transactionId,
         type: ConversationViewportCommandType.preserveOnPrepend,
         placement: placement,
         anchorStableKey: anchorStableKey,
         anchorDy: anchorDy,
       );

  const ConversationViewportCommand.preserveOnAppend({
    required int transactionId,
    required String anchorStableKey,
    required double anchorDy,
    required ConversationViewportPlacement placement,
  }) : this._(
         transactionId: transactionId,
         type: ConversationViewportCommandType.preserveOnAppend,
         placement: placement,
         anchorStableKey: anchorStableKey,
         anchorDy: anchorDy,
       );

  const ConversationViewportCommand.settleAtBottomAfterMutation({
    required int transactionId,
    required ConversationViewportPlacement placement,
  }) : this._(
         transactionId: transactionId,
         type: ConversationViewportCommandType.settleAtBottomAfterMutation,
         placement: placement,
       );

  const ConversationViewportCommand.settleAtBottomAfterViewportResize({
    required int transactionId,
    required ConversationViewportPlacement placement,
  }) : this._(
         transactionId: transactionId,
         type:
             ConversationViewportCommandType.settleAtBottomAfterViewportResize,
         placement: placement,
       );

  final int transactionId;
  final ConversationViewportCommandType type;
  final ConversationViewportPlacement placement;
  final int? messageId;
  final String? anchorStableKey;
  final double? anchorDy;

  bool get isBootstrap =>
      type == ConversationViewportCommandType.showLatest ||
      type == ConversationViewportCommandType.bootstrapTarget;
}

class ConversationTimelineState {
  const ConversationTimelineState({
    required this.entries,
    required this.windowStableKeys,
    required this.windowMode,
    required this.viewportPlacement,
    required this.canLoadOlder,
    required this.canLoadNewer,
    required this.anchorEntryIndex,
    this.isLoadingOlder = false,
    this.isLoadingNewer = false,
    this.pendingLiveCount = 0,
    this.highlightedMessageId,
    this.anchorMessageId,
    this.unreadMarkerMessageId,
    this.infoMessage,
    this.shouldRefreshChats = false,
    this.viewportCommand,
  });

  final List<TimelineEntry> entries;
  final List<String> windowStableKeys;
  final ConversationWindowMode windowMode;
  final ConversationViewportPlacement viewportPlacement;
  final bool canLoadOlder;
  final bool canLoadNewer;

  /// Index into [entries] for the scroll anchor.
  final int anchorEntryIndex;

  final bool isLoadingOlder;
  final bool isLoadingNewer;
  final int pendingLiveCount;
  final int? highlightedMessageId;
  final int? anchorMessageId;
  final int? unreadMarkerMessageId;
  final String? infoMessage;
  final bool shouldRefreshChats;
  final ConversationViewportCommand? viewportCommand;

  ConversationTimelineState copyWith({
    List<TimelineEntry>? entries,
    List<String>? windowStableKeys,
    ConversationWindowMode? windowMode,
    ConversationViewportPlacement? viewportPlacement,
    bool? canLoadOlder,
    bool? canLoadNewer,
    int? anchorEntryIndex,
    bool? isLoadingOlder,
    bool? isLoadingNewer,
    int? pendingLiveCount,
    Object? highlightedMessageId = _sentinel,
    Object? anchorMessageId = _sentinel,
    Object? unreadMarkerMessageId = _sentinel,
    Object? infoMessage = _sentinel,
    bool? shouldRefreshChats,
    Object? viewportCommand = _sentinel,
  }) {
    return ConversationTimelineState(
      entries: entries ?? this.entries,
      windowStableKeys: windowStableKeys ?? this.windowStableKeys,
      windowMode: windowMode ?? this.windowMode,
      viewportPlacement: viewportPlacement ?? this.viewportPlacement,
      canLoadOlder: canLoadOlder ?? this.canLoadOlder,
      canLoadNewer: canLoadNewer ?? this.canLoadNewer,
      anchorEntryIndex: anchorEntryIndex ?? this.anchorEntryIndex,
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
      viewportCommand: viewportCommand == _sentinel
          ? this.viewportCommand
          : viewportCommand as ConversationViewportCommand?,
    );
  }
}

class ConversationTimelineViewModel
    extends AsyncNotifier<ConversationTimelineState> {
  final ConversationTimelineArgs arg;

  ConversationTimelineViewModel(this.arg);
  static const int _windowSize = ConversationRepository.defaultWindowSize;
  static const int _pageSize = ConversationRepository.pageSize;

  late ConversationRepository _repository;
  Timer? _readSyncDebounceTimer;
  Timer? _highlightTimer;
  int? _currentReadId;
  int? _lastSyncedReadId;
  bool _isDisposed = false;
  bool _hasPendingEntryRefresh = false;
  bool _isViewportAtLiveEdge = false;
  bool _isResumeRefreshInFlight = false;
  final Set<int> _pendingLiveMessageIds = <int>{};
  int _nextViewportTransactionId = 1;

  @override
  Future<ConversationTimelineState> build() async {
    _isDisposed = false;
    ref.listen<int>(conversationCacheRevisionProvider(arg.scope), (previous, next) {
      _rebuildCurrentState();
    });
    developer.log(
      'build() called — scope=${arg.scope}, '
      'launchRequest=${arg.launchRequest}',
      name: 'TimelineVM',
    );
    _repository = ref.read(conversationRepositoryProvider(arg.scope));
    final realtimeRegistry = ref.read(conversationRealtimeRegistryProvider);
    final localMutationRegistry = ref.read(
      conversationLocalMutationRegistryProvider,
    );

    final realtimeListenerToken = realtimeRegistry.addListener(
      _handleRealtimeEvent,
    );
    final localMutationListenerToken = localMutationRegistry.addListener(
      _handleLocalMutation,
    );

    ref.onDispose(() {
      developer.log('disposed', name: 'TimelineVM');
      _isDisposed = true;
      _readSyncDebounceTimer?.cancel();
      _highlightTimer?.cancel();
      realtimeRegistry.removeListener(realtimeListenerToken);
      localMutationRegistry.removeListener(localMutationListenerToken);
    });

    return _loadInitial(arg.launchRequest);
  }

  Future<ConversationTimelineState> _loadInitial(
    LaunchRequest launchRequest,
  ) async {
    _hasPendingEntryRefresh = false;
    switch (launchRequest) {
      case LatestLaunchRequest():
        _isViewportAtLiveEdge = true;
        _pendingLiveMessageIds.clear();
        final cachedKeys = _repository.latestWindowStableKeys(
          limit: _windowSize,
        );
        if (cachedKeys.isNotEmpty) {
          _hasPendingEntryRefresh = true;
          return _buildState(
            windowStableKeys: cachedKeys,
            windowMode: ConversationWindowMode.liveLatest,
            viewportPlacement: ConversationViewportPlacement.liveEdge,
            viewportCommand: _showLatestCommand(),
          );
        }
        final messages = await _repository.loadLatestWindow(limit: _windowSize);
        return _buildState(
          windowStableKeys: messages.map((item) => item.stableKey).toList(),
          windowMode: ConversationWindowMode.liveLatest,
          viewportPlacement: ConversationViewportPlacement.liveEdge,
          viewportCommand: _showLatestCommand(),
        );
      case UnreadLaunchRequest(:final lastReadMessageId):
        _isViewportAtLiveEdge = false;
        _pendingLiveMessageIds.clear();
        final anchorId = await _repository.resolveUnreadAnchorMessageId(
          lastReadMessageId,
        );
        if (anchorId == null) {
          final latest = await _repository.loadLatestWindow(limit: _windowSize);
          return _buildState(
            windowStableKeys: latest.map((item) => item.stableKey).toList(),
            windowMode: ConversationWindowMode.liveLatest,
            viewportPlacement: ConversationViewportPlacement.liveEdge,
            viewportCommand: _showLatestCommand(),
          );
        }
        final hasCachedWindow = _repository.hasWindowAroundMessage(
          anchorId,
          before: _windowSize ~/ 2,
          after: _windowSize ~/ 2,
        );
        if (hasCachedWindow) {
          final cachedMessages = _repository.cachedWindowAroundMessage(
            anchorId,
            before: _windowSize ~/ 2,
            after: _windowSize ~/ 2,
          );
          _hasPendingEntryRefresh = true;
          return _buildState(
            windowStableKeys: cachedMessages
                .map((item) => item.stableKey)
                .toList(),
            windowMode: ConversationWindowMode.anchoredTarget,
            viewportPlacement: ConversationViewportPlacement.topPreferred,
            anchorMessageId: anchorId,
            unreadMarkerMessageId: anchorId,
            viewportCommand: _bootstrapTargetCommand(anchorId),
          );
        }
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
            viewportPlacement: ConversationViewportPlacement.liveEdge,
            infoMessage: 'Message unavailable',
            viewportCommand: _showLatestCommand(),
          );
        }
        return _buildState(
          windowStableKeys: messages.map((item) => item.stableKey).toList(),
          windowMode: ConversationWindowMode.anchoredTarget,
          viewportPlacement: ConversationViewportPlacement.topPreferred,
          anchorMessageId: anchorId,
          unreadMarkerMessageId: anchorId,
          viewportCommand: _bootstrapTargetCommand(anchorId),
        );
      case MessageLaunchRequest(:final messageId, :final highlight):
        _isViewportAtLiveEdge = false;
        _pendingLiveMessageIds.clear();
        final anchorId = messageId;
        final cachedMessages = _repository.cachedWindowAroundMessage(
          anchorId,
          before: _windowSize ~/ 2,
          after: _windowSize ~/ 2,
        );
        if (cachedMessages.isNotEmpty) {
          _hasPendingEntryRefresh = true;
          final nextState = _buildState(
            windowStableKeys: cachedMessages
                .map((item) => item.stableKey)
                .toList(),
            windowMode: ConversationWindowMode.anchoredTarget,
            viewportPlacement: ConversationViewportPlacement.topPreferred,
            anchorMessageId: anchorId,
            highlightedMessageId: highlight ? anchorId : null,
            viewportCommand: _bootstrapTargetCommand(anchorId),
          );
          if (highlight) {
            _scheduleHighlightClear();
          }
          return nextState;
        }
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
            viewportPlacement: ConversationViewportPlacement.liveEdge,
            infoMessage: 'Message unavailable',
            viewportCommand: _showLatestCommand(),
          );
        }
        final nextState = _buildState(
          windowStableKeys: messages.map((item) => item.stableKey).toList(),
          windowMode: ConversationWindowMode.anchoredTarget,
          viewportPlacement: ConversationViewportPlacement.topPreferred,
          anchorMessageId: anchorId,
          highlightedMessageId: highlight ? anchorId : null,
          viewportCommand: _bootstrapTargetCommand(anchorId),
        );
        if (highlight) {
          _scheduleHighlightClear();
        }
        return nextState;
    }
  }

  Future<void> refreshEntryOnOpenIfNeeded() async {
    if (!_hasPendingEntryRefresh) {
      return;
    }
    final current = state.value;
    if (current == null) {
      return;
    }
    _hasPendingEntryRefresh = false;
    switch (current.windowMode) {
      case ConversationWindowMode.liveLatest:
        await _refreshLatestOnOpen();
      case ConversationWindowMode.anchoredTarget:
        final anchorId = current.anchorMessageId;
        if (anchorId != null) {
          await _refreshAnchorOnOpen(anchorId);
        }
      case ConversationWindowMode.historyBrowsing:
        break;
    }
  }

  Future<void> refreshOnResume() async {
    final current = state.value;
    if (current == null || _isResumeRefreshInFlight) {
      return;
    }

    _isResumeRefreshInFlight = true;
    try {
      switch (current.windowMode) {
        case ConversationWindowMode.liveLatest:
          await _refreshLatestOnOpen();
        case ConversationWindowMode.anchoredTarget:
          final anchorId = current.anchorMessageId;
          if (anchorId != null) {
            await _refreshAnchorOnOpen(anchorId);
          }
        case ConversationWindowMode.historyBrowsing:
          break;
      }
    } finally {
      _isResumeRefreshInFlight = false;
    }
  }

  Future<void> _refreshLatestOnOpen() async {
    try {
      final latest = await _repository.refreshLatestWindow(limit: _windowSize);
      final current = state.value;
      if (current == null ||
          current.windowMode != ConversationWindowMode.liveLatest) {
        return;
      }
      _setStateIfActive(
        AsyncData(
          _buildState(
            windowStableKeys: latest.map((item) => item.stableKey).toList(),
            windowMode: ConversationWindowMode.liveLatest,
            viewportPlacement: ConversationViewportPlacement.liveEdge,
            highlightedMessageId: current.highlightedMessageId,
            infoMessage: current.infoMessage,
            shouldRefreshChats: current.shouldRefreshChats,
            pendingLiveCount: current.pendingLiveCount,
            viewportCommand: current.viewportCommand,
          ).copyWith(
            isLoadingOlder: current.isLoadingOlder,
            isLoadingNewer: current.isLoadingNewer,
          ),
        ),
      );
    } catch (error, stackTrace) {
      developer.log(
        'refresh latest on open failed',
        name: 'TimelineVM',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _refreshAnchorOnOpen(int anchorId) async {
    try {
      final messages = await _repository.refreshAroundMessage(
        anchorId,
        before: _windowSize ~/ 2,
        after: _windowSize ~/ 2,
      );
      final current = state.value;
      if (current == null ||
          current.windowMode != ConversationWindowMode.anchoredTarget ||
          current.anchorMessageId != anchorId) {
        return;
      }
      if (messages.isEmpty) {
        final latest = await _repository.refreshLatestWindow(
          limit: _windowSize,
        );
        final fallbackState = _buildState(
          windowStableKeys: latest.map((item) => item.stableKey).toList(),
          windowMode: ConversationWindowMode.liveLatest,
          viewportPlacement: ConversationViewportPlacement.liveEdge,
          infoMessage: 'Message unavailable',
          shouldRefreshChats: current.shouldRefreshChats,
          viewportCommand: current.viewportCommand ?? _showLatestCommand(),
        );
        _setStateIfActive(
          AsyncData(
            fallbackState.copyWith(
              isLoadingOlder: current.isLoadingOlder,
              isLoadingNewer: current.isLoadingNewer,
            ),
          ),
        );
        return;
      }
      _setStateIfActive(
        AsyncData(
          _buildState(
            windowStableKeys: messages.map((item) => item.stableKey).toList(),
            windowMode: ConversationWindowMode.anchoredTarget,
            viewportPlacement: ConversationViewportPlacement.topPreferred,
            anchorMessageId: anchorId,
            unreadMarkerMessageId: current.unreadMarkerMessageId,
            highlightedMessageId: current.highlightedMessageId,
            infoMessage: current.infoMessage,
            shouldRefreshChats: current.shouldRefreshChats,
            pendingLiveCount: current.pendingLiveCount,
            viewportCommand: current.viewportCommand,
          ).copyWith(
            isLoadingOlder: current.isLoadingOlder,
            isLoadingNewer: current.isLoadingNewer,
          ),
        ),
      );
    } catch (error, stackTrace) {
      developer.log(
        'refresh anchor on open failed',
        name: 'TimelineVM',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  ConversationTimelineState _buildState({
    required List<String> windowStableKeys,
    required ConversationWindowMode windowMode,
    required ConversationViewportPlacement viewportPlacement,
    int? anchorMessageId,
    int? unreadMarkerMessageId,
    int? highlightedMessageId,
    String? infoMessage,
    bool shouldRefreshChats = false,
    int pendingLiveCount = 0,
    ConversationViewportCommand? viewportCommand,
  }) {
    final trimmed = _repository.trimWindow(windowStableKeys);
    final entries = _buildEntries(
      _repository.messagesForWindow(trimmed),
      unreadMarkerMessageId: unreadMarkerMessageId,
    );

    // Compute anchor entry index for the view layer. The widget resolves the
    // feasible viewport alignment from rendered extents, but state still
    // carries the requested placement for mode transitions and re-keying.
    final anchorEntryIndex = _resolveAnchorEntryIndex(entries, anchorMessageId);

    developer.log(
      '_buildState: mode=$windowMode, '
      'anchorMsgId=$anchorMessageId, '
      'anchorIdx=$anchorEntryIndex/${entries.length}, '
      'placement=$viewportPlacement, '
      'viewportCommand=${viewportCommand?.type}, '
      'window=${trimmed.length} keys '
      '(first=${trimmed.firstOrNull}, last=${trimmed.lastOrNull})',
      name: 'TimelineVM',
    );

    return ConversationTimelineState(
      entries: entries,
      windowStableKeys: trimmed,
      windowMode: windowMode,
      viewportPlacement: viewportPlacement,
      canLoadOlder: _repository.hasOlderOutsideWindow(trimmed),
      canLoadNewer: _repository.hasNewerOutsideWindow(trimmed),
      anchorEntryIndex: anchorEntryIndex,
      pendingLiveCount: pendingLiveCount,
      highlightedMessageId: highlightedMessageId,
      anchorMessageId: anchorMessageId,
      unreadMarkerMessageId: unreadMarkerMessageId,
      infoMessage: infoMessage,
      shouldRefreshChats: shouldRefreshChats,
      viewportCommand: viewportCommand,
    );
  }

  List<TimelineEntry> _buildEntries(
    List<ConversationMessage> messages, {
    int? unreadMarkerMessageId,
  }) {
    final entries = <TimelineEntry>[];
    DateTime? currentDay;
    for (final message in messages) {
      final localCreatedAt = message.createdAt?.toLocal();
      final day = localCreatedAt == null
          ? null
          : DateTime(
              localCreatedAt.year,
              localCreatedAt.month,
              localCreatedAt.day,
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

  /// Find the entry index for [anchorMessageId]. Falls back to last entry
  /// (liveEdge default) when no anchor is specified or not found.
  int _resolveAnchorEntryIndex(
    List<TimelineEntry> entries,
    int? anchorMessageId,
  ) {
    if (entries.isEmpty) return 0;
    if (anchorMessageId != null) {
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        if (entry is TimelineMessageEntry &&
            entry.message.serverMessageId == anchorMessageId) {
          return i;
        }
      }
    }
    // Default: anchor at the last entry (bottom / live edge).
    return entries.length - 1;
  }

  void _handleRealtimeEvent(ApiWsEvent event) {
    if (!state.hasValue || !_repository.matchesRealtimeEvent(event)) {
      return;
    }

    final current = state.requireValue;
    final pendingLiveCount = _applyPendingLiveMutation(event);
    final nextWindowStableKeys = current.windowMode ==
            ConversationWindowMode.liveLatest
        ? _repository.latestWindowStableKeys(limit: _windowSize)
        : current.windowStableKeys;
    final nextViewportCommand =
        _isViewportAtLiveEdge &&
            event is MessageCreatedWsEvent &&
            !current.canLoadNewer
        ? _settleAtBottomAfterMutationCommand()
        : current.viewportCommand;
    final nextState = _buildState(
      windowStableKeys: nextWindowStableKeys,
      windowMode: current.windowMode,
      viewportPlacement: current.viewportPlacement,
      anchorMessageId: current.anchorMessageId,
      unreadMarkerMessageId: current.unreadMarkerMessageId,
      highlightedMessageId: current.highlightedMessageId,
      shouldRefreshChats: true,
      pendingLiveCount: pendingLiveCount,
      viewportCommand: nextViewportCommand,
    );
    if (_isViewportAtLiveEdge && !current.canLoadNewer) {
      _pendingLiveMessageIds.clear();
    }
    _setStateIfActive(
      AsyncData(
        nextState.copyWith(
          isLoadingOlder: current.isLoadingOlder,
          isLoadingNewer: current.isLoadingNewer,
        ),
      ),
    );
  }

  void _handleLocalMutation(ConversationLocalMutation mutation) {
    if (mutation.scope.storageKey != arg.scope.storageKey || !state.hasValue) {
      return;
    }

    final current = state.requireValue;
    final shouldTrackLatestWindow =
        current.windowMode == ConversationWindowMode.liveLatest ||
        _isViewportAtLiveEdge;
    final nextWindowStableKeys = switch (mutation.kind) {
      ConversationLocalMutationKind.inserted ||
      ConversationLocalMutationKind.removed when shouldTrackLatestWindow =>
        _repository.latestWindowStableKeys(limit: _windowSize),
      _ => current.windowStableKeys,
    };
    final nextViewportCommand = switch (mutation.kind) {
      ConversationLocalMutationKind.inserted when shouldTrackLatestWindow =>
        _settleAtBottomAfterMutationCommand(),
      _ => current.viewportCommand,
    };
    developer.log(
      'local mutation: kind=${mutation.kind}, '
      'currentHighlight=${current.highlightedMessageId}, '
      'preserveHighlight=${current.highlightedMessageId}',
      name: 'TimelineVM',
    );

    final nextState = _buildState(
      windowStableKeys: nextWindowStableKeys,
      windowMode: current.windowMode,
      viewportPlacement: current.viewportPlacement,
      anchorMessageId: current.anchorMessageId,
      unreadMarkerMessageId: current.unreadMarkerMessageId,
      highlightedMessageId: current.highlightedMessageId,
      infoMessage: current.infoMessage,
      shouldRefreshChats: true,
      pendingLiveCount: current.pendingLiveCount,
      viewportCommand: nextViewportCommand,
    );
    _setStateIfActive(
      AsyncData(
        nextState.copyWith(
          isLoadingOlder: current.isLoadingOlder,
          isLoadingNewer: current.isLoadingNewer,
        ),
      ),
    );
  }

  Future<bool> loadOlder({
    String? preserveAnchorStableKey,
    double? preserveAnchorDy,
    int? rebaseAnchorMessageId,
  }) async {
    final current = state.value;
    if (current == null || current.isLoadingOlder || !current.canLoadOlder) {
      developer.log(
        'loadOlder: SKIPPED '
        'null=${current == null}, '
        'loading=${current?.isLoadingOlder}, '
        'canLoad=${current?.canLoadOlder}',
        name: 'TimelineVM',
      );
      return false;
    }
    developer.log(
      'loadOlder: START window=${current.windowStableKeys.length}, '
      'first=${current.windowStableKeys.firstOrNull}',
      name: 'TimelineVM',
    );
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
      var nextWindow = _repository.prependWindowPage(
        current.windowStableKeys,
        oldestStableKey,
      );

      if (nextWindow.length > ConversationRepository.softWindowCap) {
        final anchorId = rebaseAnchorMessageId;
        final anchorStableKey = anchorId == null
            ? null
            : _repository.messageForServerId(anchorId)?.stableKey;
        final trimmed = _repository.trimWindowAroundKey(
          nextWindow,
          anchorKey: anchorStableKey ?? oldestStableKey,
        );
        if (trimmed != null && anchorId != null) {
          developer.log(
            'loadOlder: TRIM+REBASE ${nextWindow.length} → '
            '${trimmed.length}, anchor=$anchorId',
            name: 'TimelineVM',
          );
          _setStateIfActive(
            AsyncData(
              _buildState(
                windowStableKeys: trimmed,
                windowMode: ConversationWindowMode.historyBrowsing,
                viewportPlacement: ConversationViewportPlacement.topPreferred,
                anchorMessageId: anchorId,
                unreadMarkerMessageId: current.unreadMarkerMessageId,
                highlightedMessageId: current.highlightedMessageId,
                pendingLiveCount: current.pendingLiveCount,
                shouldRefreshChats: current.shouldRefreshChats,
                viewportCommand: _bootstrapTargetCommand(anchorId),
              ),
            ),
          );
          return true;
        }
      }

      developer.log(
        'loadOlder: DONE window=${nextWindow.length}, '
        'first=${nextWindow.firstOrNull}, last=${nextWindow.lastOrNull}',
        name: 'TimelineVM',
      );
      _setStateIfActive(
        AsyncData(
          _buildState(
            windowStableKeys: nextWindow,
            windowMode: current.windowMode == ConversationWindowMode.liveLatest
                ? ConversationWindowMode.historyBrowsing
                : current.windowMode,
            viewportPlacement: current.viewportPlacement,
            anchorMessageId: current.anchorMessageId,
            unreadMarkerMessageId: current.unreadMarkerMessageId,
            highlightedMessageId: current.highlightedMessageId,
            pendingLiveCount: current.pendingLiveCount,
            shouldRefreshChats: current.shouldRefreshChats,
            viewportCommand:
                preserveAnchorStableKey != null && preserveAnchorDy != null
                ? _preserveOnPrependCommand(
                    anchorStableKey: preserveAnchorStableKey,
                    anchorDy: preserveAnchorDy,
                    placement: current.viewportPlacement,
                  )
                : current.viewportCommand,
          ),
        ),
      );
      return true;
    } catch (_) {
      final latest = state.value;
      if (latest != null) {
        _setStateIfActive(AsyncData(latest.copyWith(isLoadingOlder: false)));
      }
      rethrow;
    }
  }

  Future<bool> loadNewer({
    String? preserveAnchorStableKey,
    double? preserveAnchorDy,
    int? rebaseAnchorMessageId,
  }) async {
    final current = state.value;
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
      var nextWindow = _repository.appendWindowPage(
        current.windowStableKeys,
        newestStableKey,
      );

      if (nextWindow.length > ConversationRepository.softWindowCap) {
        final anchorId = rebaseAnchorMessageId;
        final anchorStableKey = anchorId == null
            ? null
            : _repository.messageForServerId(anchorId)?.stableKey;
        final trimmed = _repository.trimWindowAroundKey(
          nextWindow,
          anchorKey: anchorStableKey ?? newestStableKey,
        );
        if (trimmed != null && anchorId != null) {
          developer.log(
            'loadNewer: TRIM+REBASE ${nextWindow.length} → '
            '${trimmed.length}, anchor=$anchorId',
            name: 'TimelineVM',
          );
          _setStateIfActive(
            AsyncData(
              _buildState(
                windowStableKeys: trimmed,
                windowMode: ConversationWindowMode.historyBrowsing,
                viewportPlacement: ConversationViewportPlacement.topPreferred,
                anchorMessageId: anchorId,
                unreadMarkerMessageId: current.unreadMarkerMessageId,
                highlightedMessageId: current.highlightedMessageId,
                pendingLiveCount: current.pendingLiveCount,
                shouldRefreshChats: current.shouldRefreshChats,
                viewportCommand: _bootstrapTargetCommand(anchorId),
              ),
            ),
          );
          return true;
        }
      }

      final reachedLiveEdge = !_repository.hasNewerOutsideWindow(nextWindow);
      if (reachedLiveEdge) {
        _pendingLiveMessageIds.clear();
      }
      _setStateIfActive(
        AsyncData(
          _buildState(
            windowStableKeys: nextWindow,
            windowMode: reachedLiveEdge
                ? ConversationWindowMode.liveLatest
                : ConversationWindowMode.historyBrowsing,
            viewportPlacement: reachedLiveEdge
                ? ConversationViewportPlacement.liveEdge
                : current.viewportPlacement,
            anchorMessageId: reachedLiveEdge ? null : current.anchorMessageId,
            unreadMarkerMessageId: current.unreadMarkerMessageId,
            highlightedMessageId: current.highlightedMessageId,
            pendingLiveCount: reachedLiveEdge ? 0 : current.pendingLiveCount,
            shouldRefreshChats: current.shouldRefreshChats,
            viewportCommand: reachedLiveEdge
                ? _settleAtBottomAfterMutationCommand()
                : preserveAnchorStableKey != null && preserveAnchorDy != null
                ? _preserveOnAppendCommand(
                    anchorStableKey: preserveAnchorStableKey,
                    anchorDy: preserveAnchorDy,
                    placement: current.viewportPlacement,
                  )
                : current.viewportCommand,
          ),
        ),
      );
      return true;
    } catch (_) {
      final latest = state.value;
      if (latest != null) {
        _setStateIfActive(AsyncData(latest.copyWith(isLoadingNewer: false)));
      }
      rethrow;
    }
  }

  Future<void> jumpToLatest() async {
    final current = state.value;
    if (current == null) {
      return;
    }
    developer.log(
      'jumpToLatest: currentHighlight=${current.highlightedMessageId}, '
      'canLoadNewer=${current.canLoadNewer}, '
      'windowMode=${current.windowMode}',
      name: 'TimelineVM',
    );
    _isViewportAtLiveEdge = true;
    _pendingLiveMessageIds.clear();
    if (!_repository.hasNewerOutsideWindow(current.windowStableKeys)) {
      _setStateIfActive(
        AsyncData(
          _buildState(
            windowStableKeys: current.windowStableKeys,
            windowMode: ConversationWindowMode.liveLatest,
            viewportPlacement: ConversationViewportPlacement.liveEdge,
            shouldRefreshChats: current.shouldRefreshChats,
            pendingLiveCount: 0,
            viewportCommand: _settleAtBottomAfterMutationCommand(),
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
          viewportPlacement: ConversationViewportPlacement.liveEdge,
          pendingLiveCount: 0,
          viewportCommand: _showLatestCommand(),
        ),
      ),
    );
  }

  Future<bool> jumpToMessage(int messageId, {bool highlight = true}) async {
    final current = state.value;
    if (current == null) {
      return false;
    }
    developer.log(
      'jumpToMessage: messageId=$messageId, '
      'highlight=$highlight, '
      'currentHighlight=${current.highlightedMessageId}',
      name: 'TimelineVM',
    );
    _isViewportAtLiveEdge = false;
    final targetIndex = _repository.findWindowIndex(
      current.windowStableKeys,
      messageId,
    );
    if (targetIndex != null) {
      _setStateIfActive(
        AsyncData(
          _buildState(
            windowStableKeys: current.windowStableKeys,
            windowMode: current.windowMode == ConversationWindowMode.liveLatest
                ? ConversationWindowMode.historyBrowsing
                : current.windowMode,
            viewportPlacement:
                current.windowMode == ConversationWindowMode.liveLatest
                ? ConversationViewportPlacement.topPreferred
                : current.viewportPlacement,
            anchorMessageId: current.anchorMessageId ?? messageId,
            highlightedMessageId: highlight ? messageId : null,
            shouldRefreshChats: current.shouldRefreshChats,
            pendingLiveCount: current.pendingLiveCount,
            unreadMarkerMessageId: current.unreadMarkerMessageId,
            viewportCommand: _scrollToLoadedTargetCommand(messageId),
          ),
        ),
      );
      developer.log(
        'jumpToMessage: applied cached target, '
        'newHighlight=${highlight ? messageId : null}',
        name: 'TimelineVM',
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
          viewportPlacement: ConversationViewportPlacement.topPreferred,
          anchorMessageId: messageId,
          highlightedMessageId: highlight ? messageId : null,
          shouldRefreshChats: current.shouldRefreshChats,
          unreadMarkerMessageId: current.unreadMarkerMessageId,
          pendingLiveCount: current.pendingLiveCount,
          viewportCommand: _bootstrapTargetCommand(messageId),
        ),
      ),
    );
    developer.log(
      'jumpToMessage: applied fetched target, '
      'newHighlight=${highlight ? messageId : null}',
      name: 'TimelineVM',
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

  Future<void> toggleReaction(ConversationMessage message, String emoji) async {
    final messageId = message.serverMessageId;
    if (messageId == null ||
        state.value == null ||
        message.messageType == 'sticker' ||
        message.isDeleted) {
      return;
    }

    final operation = _repository.toggleReaction(
      messageId: messageId,
      emoji: emoji,
    );
    _rebuildCurrentState();
    try {
      await operation;
    } catch (_) {
      _rebuildCurrentState();
      rethrow;
    }
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
    ref
        .read(chatListStateProvider.notifier)
        .markChatRead(chatId: arg.scope.chatId, messageId: toSync);
    final current = state.value;
    if (current != null) {
      _setStateIfActive(AsyncData(current.copyWith(shouldRefreshChats: true)));
    }
    return true;
  }

  bool get shouldRefreshChats => state.value?.shouldRefreshChats ?? false;

  void clearInfoMessage() {
    final current = state.value;
    if (current == null || current.infoMessage == null) {
      return;
    }
    _setStateIfActive(AsyncData(current.copyWith(infoMessage: null)));
  }

  /// Mark the current [viewportCommand] as consumed so it is not re-applied
  /// when the widget rebuilds for unrelated state changes.
  void consumeViewportCommand(int transactionId) {
    final current = state.value;
    if (current == null || current.viewportCommand == null) {
      developer.log(
        'consumeViewportCommand: nothing to consume '
        '(state=${current != null ? "present" : "null"}, '
        'command=${current?.viewportCommand})',
        name: 'TimelineVM',
      );
      return;
    }
    if (current.viewportCommand!.transactionId != transactionId) {
      return;
    }
    developer.log(
      'consumeViewportCommand: clearing '
      '${current.viewportCommand!.type}#${current.viewportCommand!.transactionId}',
      name: 'TimelineVM',
    );
    _setStateIfActive(AsyncData(current.copyWith(viewportCommand: null)));
  }

  void onViewportResized() {
    final current = state.value;
    if (current == null ||
        current.windowMode != ConversationWindowMode.liveLatest) {
      return;
    }
    _setStateIfActive(
      AsyncData(
        current.copyWith(
          viewportCommand: _settleAtBottomAfterViewportResizeCommand(),
        ),
      ),
    );
  }

  void onViewportLiveEdgeChanged(bool isAtLiveEdge) {
    _isViewportAtLiveEdge = isAtLiveEdge;
    if (!isAtLiveEdge) {
      return;
    }
    final current = state.value;
    if (current == null || current.pendingLiveCount == 0) {
      return;
    }
    _pendingLiveMessageIds.clear();
    _setStateIfActive(
      AsyncData(
        current.copyWith(
          pendingLiveCount: 0,
          viewportCommand: current.viewportCommand,
        ),
      ),
    );
  }

  int _applyPendingLiveMutation(ApiWsEvent event) {
    switch (event) {
      case MessageCreatedWsEvent(:final payload):
        _pendingLiveMessageIds.add(payload.id);
      case MessageDeletedWsEvent(:final payload):
        _pendingLiveMessageIds.remove(payload.id);
      case MessageUpdatedWsEvent():
      case ReactionUpdatedWsEvent():
      case ThreadUpdatedWsEvent():
      case StickerPackOrderUpdatedWsEvent():
      case PongWsEvent():
        break;
    }
    return _pendingLiveMessageIds.length;
  }

  void _scheduleHighlightClear() {
    _highlightTimer?.cancel();
    developer.log(
      'scheduleHighlightClear: currentHighlight=${state.value?.highlightedMessageId}',
      name: 'TimelineVM',
    );
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      final current = state.value;
      if (current != null) {
        developer.log(
          'scheduleHighlightClear: clearing highlight=${current.highlightedMessageId}',
          name: 'TimelineVM',
        );
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

  void _rebuildCurrentState() {
    final current = state.value;
    if (current == null) {
      return;
    }
    final nextState = _buildState(
      windowStableKeys: current.windowStableKeys,
      windowMode: current.windowMode,
      viewportPlacement: current.viewportPlacement,
      anchorMessageId: current.anchorMessageId,
      unreadMarkerMessageId: current.unreadMarkerMessageId,
      highlightedMessageId: current.highlightedMessageId,
      infoMessage: current.infoMessage,
      shouldRefreshChats: current.shouldRefreshChats,
      pendingLiveCount: current.pendingLiveCount,
      viewportCommand: current.viewportCommand,
    );
    _setStateIfActive(
      AsyncData(
        nextState.copyWith(
          isLoadingOlder: current.isLoadingOlder,
          isLoadingNewer: current.isLoadingNewer,
        ),
      ),
    );
  }

  int _nextViewportTransaction() => _nextViewportTransactionId++;

  ConversationViewportCommand _showLatestCommand() =>
      ConversationViewportCommand.showLatest(
        transactionId: _nextViewportTransaction(),
        placement: ConversationViewportPlacement.liveEdge,
      );

  ConversationViewportCommand _bootstrapTargetCommand(int messageId) =>
      ConversationViewportCommand.bootstrapTarget(
        transactionId: _nextViewportTransaction(),
        messageId: messageId,
        placement: ConversationViewportPlacement.topPreferred,
      );

  ConversationViewportCommand _scrollToLoadedTargetCommand(int messageId) =>
      ConversationViewportCommand.scrollToLoadedTarget(
        transactionId: _nextViewportTransaction(),
        messageId: messageId,
        placement: ConversationViewportPlacement.topPreferred,
      );

  ConversationViewportCommand _preserveOnPrependCommand({
    required String anchorStableKey,
    required double anchorDy,
    required ConversationViewportPlacement placement,
  }) => ConversationViewportCommand.preserveOnPrepend(
    transactionId: _nextViewportTransaction(),
    anchorStableKey: anchorStableKey,
    anchorDy: anchorDy,
    placement: placement,
  );

  ConversationViewportCommand _preserveOnAppendCommand({
    required String anchorStableKey,
    required double anchorDy,
    required ConversationViewportPlacement placement,
  }) => ConversationViewportCommand.preserveOnAppend(
    transactionId: _nextViewportTransaction(),
    anchorStableKey: anchorStableKey,
    anchorDy: anchorDy,
    placement: placement,
  );

  ConversationViewportCommand _settleAtBottomAfterMutationCommand() =>
      ConversationViewportCommand.settleAtBottomAfterMutation(
        transactionId: _nextViewportTransaction(),
        placement: ConversationViewportPlacement.liveEdge,
      );

  ConversationViewportCommand _settleAtBottomAfterViewportResizeCommand() =>
      ConversationViewportCommand.settleAtBottomAfterViewportResize(
        transactionId: _nextViewportTransaction(),
        placement: ConversationViewportPlacement.liveEdge,
      );
}

const _sentinel = Object();

final conversationTimelineViewModelProvider =
    AsyncNotifierProvider.family<
      ConversationTimelineViewModel,
      ConversationTimelineState,
      ConversationTimelineArgs
    >(ConversationTimelineViewModel.new, isAutoDispose: true);
