import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/websocket_api_models.dart';
import '../../../../core/network/websocket_service.dart';
import '../../list/data/chat_repository.dart';
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

enum ConversationLocateTarget { latest, message }

class ConversationLocatePlan {
  const ConversationLocatePlan._({
    required this.target,
    required this.placement,
    this.messageId,
  });

  const ConversationLocatePlan.latest({
    required ConversationViewportPlacement placement,
  }) : this._(target: ConversationLocateTarget.latest, placement: placement);

  const ConversationLocatePlan.message({
    required int messageId,
    required ConversationViewportPlacement placement,
  }) : this._(
         target: ConversationLocateTarget.message,
         placement: placement,
         messageId: messageId,
       );

  final ConversationLocateTarget target;
  final ConversationViewportPlacement placement;
  final int? messageId;
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
    this.locatePlan,
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
  final ConversationLocatePlan? locatePlan;

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
    Object? locatePlan = _sentinel,
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
      locatePlan: locatePlan == _sentinel
          ? this.locatePlan
          : locatePlan as ConversationLocatePlan?,
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

  @override
  Future<ConversationTimelineState> build() async {
    _isDisposed = false;
    developer.log(
      'build() called — scope=${arg.scope}, '
      'launchRequest=${arg.launchRequest}',
      name: 'TimelineVM',
    );
    _repository = ref.read(conversationRepositoryProvider(arg.scope));

    ref.listen<AsyncValue<ApiWsEvent>>(wsEventsProvider, (_, next) {
      final event = next.value;
      if (event != null) {
        _handleRealtimeEvent(event);
      }
    });

    ref.onDispose(() {
      developer.log('disposed', name: 'TimelineVM');
      _isDisposed = true;
      _readSyncDebounceTimer?.cancel();
      _highlightTimer?.cancel();
    });

    return _loadInitial(arg.launchRequest);
  }

  Future<ConversationTimelineState> _loadInitial(
    LaunchRequest launchRequest,
  ) async {
    _hasPendingEntryRefresh = false;
    switch (launchRequest) {
      case LatestLaunchRequest():
        final cachedKeys = _repository.latestWindowStableKeys(
          limit: _windowSize,
        );
        if (cachedKeys.isNotEmpty) {
          _hasPendingEntryRefresh = true;
          return _buildState(
            windowStableKeys: cachedKeys,
            windowMode: ConversationWindowMode.liveLatest,
            viewportPlacement: ConversationViewportPlacement.liveEdge,
            locatePlan: _latestLocatePlan(),
          );
        }
        final messages = await _repository.loadLatestWindow(limit: _windowSize);
        return _buildState(
          windowStableKeys: messages.map((item) => item.stableKey).toList(),
          windowMode: ConversationWindowMode.liveLatest,
          viewportPlacement: ConversationViewportPlacement.liveEdge,
          locatePlan: _latestLocatePlan(),
        );
      case UnreadLaunchRequest(:final unreadMessageId):
        final anchorId = unreadMessageId;
        final cachedMessages = _repository.cachedWindowAroundMessage(
          anchorId,
          before: _windowSize ~/ 2,
          after: _windowSize ~/ 2,
        );
        if (cachedMessages.isNotEmpty) {
          _hasPendingEntryRefresh = true;
          return _buildState(
            windowStableKeys: cachedMessages
                .map((item) => item.stableKey)
                .toList(),
            windowMode: ConversationWindowMode.anchoredTarget,
            viewportPlacement: ConversationViewportPlacement.topPreferred,
            anchorMessageId: anchorId,
            unreadMarkerMessageId: anchorId,
            locatePlan: _messageLocatePlan(anchorId),
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
            locatePlan: _latestLocatePlan(),
          );
        }
        return _buildState(
          windowStableKeys: messages.map((item) => item.stableKey).toList(),
          windowMode: ConversationWindowMode.anchoredTarget,
          viewportPlacement: ConversationViewportPlacement.topPreferred,
          anchorMessageId: anchorId,
          unreadMarkerMessageId: anchorId,
          locatePlan: _messageLocatePlan(anchorId),
        );
      case MessageLaunchRequest(:final messageId, :final highlight):
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
            locatePlan: _messageLocatePlan(anchorId),
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
            locatePlan: _latestLocatePlan(),
          );
        }
        final nextState = _buildState(
          windowStableKeys: messages.map((item) => item.stableKey).toList(),
          windowMode: ConversationWindowMode.anchoredTarget,
          viewportPlacement: ConversationViewportPlacement.topPreferred,
          anchorMessageId: anchorId,
          highlightedMessageId: highlight ? anchorId : null,
          locatePlan: _messageLocatePlan(anchorId),
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
    _hasPendingEntryRefresh = false;
    switch (arg.launchRequest) {
      case LatestLaunchRequest():
        await _refreshLatestOnOpen();
      case UnreadLaunchRequest(:final unreadMessageId):
        await _refreshAnchorOnOpen(unreadMessageId);
      case MessageLaunchRequest(:final messageId):
        await _refreshAnchorOnOpen(messageId);
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
            locatePlan: current.locatePlan,
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
          locatePlan: current.locatePlan ?? _latestLocatePlan(),
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
            locatePlan: current.locatePlan,
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
    ConversationLocatePlan? locatePlan,
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
      'locatePlan=${locatePlan?.placement}, '
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
      final nextState = _buildState(
        windowStableKeys: latestWindow,
        windowMode: ConversationWindowMode.liveLatest,
        viewportPlacement: ConversationViewportPlacement.liveEdge,
        shouldRefreshChats: true,
      );
      _setStateIfActive(
        AsyncData(
          nextState.copyWith(
            isLoadingOlder: current.isLoadingOlder,
            isLoadingNewer: current.isLoadingNewer,
          ),
        ),
      );
      return;
    }

    final nextState = _buildState(
      windowStableKeys: current.windowStableKeys,
      windowMode: current.windowMode,
      viewportPlacement: current.viewportPlacement,
      anchorMessageId: current.anchorMessageId,
      unreadMarkerMessageId: current.unreadMarkerMessageId,
      highlightedMessageId: current.highlightedMessageId,
      shouldRefreshChats: true,
      pendingLiveCount: current.pendingLiveCount + 1,
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

  Future<bool> loadOlder() async {
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

      // If window exceeds soft cap, trim around the anchor and transition
      // to topPreferred so older/newer content lives in separate slivers.
      // This lets the scroll extent grow on the older side while the newer
      // side (after-center) can be safely trimmed away.
      if (nextWindow.length > ConversationRepository.softWindowCap) {
        final anchorMsg = _repository.messageForStableKey(oldestStableKey);
        final anchorId = anchorMsg?.serverMessageId;
        final trimmed = _repository.trimWindowAroundKey(
          nextWindow,
          anchorKey: oldestStableKey,
        );
        if (trimmed != null && anchorId != null) {
          developer.log(
            'loadOlder: TRIM+TRANSITION ${nextWindow.length} → '
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
                locatePlan: _messageLocatePlan(anchorId),
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

  Future<bool> loadNewer() async {
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

      // Symmetric trim: if window exceeds soft cap while loading newer,
      // trim around the anchor and transition to topPreferred.
      if (nextWindow.length > ConversationRepository.softWindowCap) {
        final anchorMsg = _repository.messageForStableKey(newestStableKey);
        final anchorId = anchorMsg?.serverMessageId;
        final trimmed = _repository.trimWindowAroundKey(
          nextWindow,
          anchorKey: newestStableKey,
        );
        if (trimmed != null && anchorId != null) {
          developer.log(
            'loadNewer: TRIM+TRANSITION ${nextWindow.length} → '
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
                locatePlan: _messageLocatePlan(anchorId),
              ),
            ),
          );
          return true;
        }
      }

      final reachedLiveEdge = !_repository.hasNewerOutsideWindow(nextWindow);
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
    if (!_repository.hasNewerOutsideWindow(current.windowStableKeys)) {
      _setStateIfActive(
        AsyncData(
          _buildState(
            windowStableKeys: current.windowStableKeys,
            windowMode: ConversationWindowMode.liveLatest,
            viewportPlacement: ConversationViewportPlacement.liveEdge,
            shouldRefreshChats: current.shouldRefreshChats,
            locatePlan: _latestLocatePlan(),
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
          locatePlan: _latestLocatePlan(),
        ),
      ),
    );
  }

  Future<bool> jumpToMessage(int messageId, {bool highlight = true}) async {
    final current = state.value;
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
            viewportPlacement: ConversationViewportPlacement.topPreferred,
            anchorMessageId: messageId,
            highlightedMessageId: highlight ? messageId : null,
            shouldRefreshChats: current.shouldRefreshChats,
            pendingLiveCount: current.pendingLiveCount,
            locatePlan: _messageLocatePlan(messageId),
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
          viewportPlacement: ConversationViewportPlacement.topPreferred,
          anchorMessageId: messageId,
          highlightedMessageId: highlight ? messageId : null,
          shouldRefreshChats: current.shouldRefreshChats,
          locatePlan: _messageLocatePlan(messageId),
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

  /// Mark the current [locatePlan] as consumed so it is not re-applied
  /// when the widget rebuilds for unrelated state changes.
  void consumeLocatePlan() {
    final current = state.value;
    if (current == null || current.locatePlan == null) {
      developer.log(
        'consumeLocatePlan: nothing to consume '
        '(state=${current != null ? "present" : "null"}, '
        'plan=${current?.locatePlan})',
        name: 'TimelineVM',
      );
      return;
    }
    developer.log(
      'consumeLocatePlan: clearing ${current.locatePlan!.placement}',
      name: 'TimelineVM',
    );
    _setStateIfActive(AsyncData(current.copyWith(locatePlan: null)));
  }

  void _scheduleHighlightClear() {
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      final current = state.value;
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
      locatePlan: current.locatePlan,
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

  ConversationLocatePlan _latestLocatePlan() =>
      const ConversationLocatePlan.latest(
        placement: ConversationViewportPlacement.liveEdge,
      );

  ConversationLocatePlan _messageLocatePlan(int messageId) =>
      ConversationLocatePlan.message(
        messageId: messageId,
        placement: ConversationViewportPlacement.topPreferred,
      );
}

const _sentinel = Object();

final conversationTimelineViewModelProvider =
    AsyncNotifierProvider.family<
      ConversationTimelineViewModel,
      ConversationTimelineState,
      ConversationTimelineArgs
    >(ConversationTimelineViewModel.new, isAutoDispose: true);
