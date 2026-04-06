import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/conversation_repository.dart';
import '../models/conversation_models.dart';

typedef ConversationTimelineArgs = ({
  ConversationScope scope,
  LaunchRequest launchRequest,
});

typedef ConversationTimelineState = ({
  List<TimelineEntry> entries,
  bool isLoadingOlder,
  bool isLoadingNewer,
  bool showJumpToLatest,
  String? errorMessage,
  int? highlightedMessageId,
  int? unreadAnchorMessageId,
  bool hasOlder,
  bool hasNewer,
  bool shouldRefreshChats,
  bool messageUnavailable,
  int pendingLiveCount,
});

enum ConversationWindowMode { liveLatest, anchoredTarget, historyBrowsing }

class ConversationTimelineViewModel
    extends
        FamilyAsyncNotifier<
          ConversationTimelineState,
          ConversationTimelineArgs
        > {
  static const int _windowLimit = 120;
  static const Duration _readSyncDebounce = Duration(milliseconds: 120);

  late final ConversationRepository _repository;
  late final ConversationTimelineArgs _args;
  StreamSubscription<void>? _repositorySubscription;
  Timer? _readSyncDebounceTimer;

  ConversationWindowMode _mode = ConversationWindowMode.liveLatest;
  List<ConversationMessage> _messages = const <ConversationMessage>[];
  int? _highlightedMessageId;
  int? _unreadAnchorMessageId;
  int? _anchorMessageId;
  int? _currentReadMessageId;
  int? _lastReadSyncedMessageId;
  bool _shouldRefreshChats = false;
  bool _isAtLiveEdge = true;
  int _pendingLiveCount = 0;

  @override
  Future<ConversationTimelineState> build(ConversationTimelineArgs arg) async {
    _args = arg;
    _repository = ref.read(conversationRepositoryProvider(arg.scope));
    _repositorySubscription = _repository.changes.listen((_) {
      _onRepositoryChanged();
    });
    ref.onDispose(() {
      _repositorySubscription?.cancel();
      _readSyncDebounceTimer?.cancel();
    });

    if (_repository.hasWarmWindow) {
      _messages = _repository.warmWindow(limit: _windowLimit);
      _anchorMessageId = _repository.viewportCache.anchorMessageId;
      _isAtLiveEdge = _repository.viewportCache.isAtLiveEdge;
      Future<void>(() async {
        await _loadLaunchRequest(arg.launchRequest, allowWarmStart: true);
      });
      return _buildState();
    }

    await _loadLaunchRequest(arg.launchRequest);
    return _buildState();
  }

  Future<void> _loadLaunchRequest(
    LaunchRequest request, {
    bool allowWarmStart = false,
  }) async {
    switch (request) {
      case LaunchLatestRequest():
        final window = allowWarmStart && _messages.isNotEmpty
            ? await _repository.refreshLatest(limit: _windowLimit)
            : await _repository.loadLatest(limit: _windowLimit);
        _messages = window.messages;
        _mode = ConversationWindowMode.liveLatest;
        _highlightedMessageId = null;
        _unreadAnchorMessageId = null;
        _anchorMessageId = null;
        _isAtLiveEdge = true;
        _pendingLiveCount = 0;
      case LaunchUnreadRequest(:final unreadMessageId):
        await _loadAnchored(
          AnchoredLoadSpec(
            anchorMessageId: unreadMessageId,
            insertUnreadMarker: true,
            highlightTarget: false,
          ),
        );
      case LaunchMessageRequest(:final messageId, :final highlight):
        await _loadAnchored(
          AnchoredLoadSpec(
            anchorMessageId: messageId,
            insertUnreadMarker: false,
            highlightTarget: highlight,
          ),
        );
    }
  }

  Future<void> _loadAnchored(AnchoredLoadSpec spec) async {
    final window = await _repository.loadAround(
      spec.anchorMessageId,
      before: _windowLimit ~/ 2,
      after: _windowLimit ~/ 2,
    );
    if (window.messages.isEmpty) {
      final latest = await _repository.loadLatest(limit: _windowLimit);
      _messages = latest.messages;
      _mode = ConversationWindowMode.liveLatest;
      _highlightedMessageId = null;
      _unreadAnchorMessageId = null;
      _anchorMessageId = null;
      _isAtLiveEdge = true;
      if (state.hasValue) {
        state = AsyncData(
          _buildState(
            errorMessage: 'message unavailable',
            messageUnavailable: true,
          ),
        );
      }
      return;
    }
    _messages = window.messages;
    _mode = ConversationWindowMode.anchoredTarget;
    _anchorMessageId = spec.anchorMessageId;
    _highlightedMessageId = spec.highlightTarget ? spec.anchorMessageId : null;
    _unreadAnchorMessageId = spec.insertUnreadMarker
        ? spec.anchorMessageId
        : null;
    _isAtLiveEdge = false;
    _pendingLiveCount = 0;
  }

  void _onRepositoryChanged() {
    if (!state.hasValue) {
      return;
    }
    final previousNewestId = _messages.firstOrNull?.serverId;
    if (_mode == ConversationWindowMode.liveLatest && _isAtLiveEdge) {
      _messages = _repository.latestSync(limit: _windowLimit);
      state = AsyncData(_buildState());
      return;
    }

    if (_anchorMessageId != null) {
      final window = _repository.currentAroundSync(
        _anchorMessageId!,
        before: _windowLimit ~/ 2,
        after: _windowLimit ~/ 2,
      );
      if (window.messages.isNotEmpty) {
        _messages = window.messages;
      }
    }

    final newestId = _messages.firstOrNull?.serverId;
    if (!_isAtLiveEdge &&
        newestId != null &&
        previousNewestId != null &&
        newestId > previousNewestId) {
      _pendingLiveCount++;
    }
    state = AsyncData(_buildState());
  }

  Future<bool> loadOlder() async {
    final oldestVisibleId = _messages.lastServerId;
    if (oldestVisibleId == null) {
      return false;
    }
    _mode = ConversationWindowMode.historyBrowsing;
    state = AsyncData(_buildState(isLoadingOlder: true));
    try {
      await _repository.loadOlder(oldestVisibleId);
      _messages = _windowAfterHistoryChange();
      state = AsyncData(_buildState());
      return true;
    } catch (error) {
      state = AsyncData(_buildState(errorMessage: '$error'));
      return false;
    }
  }

  Future<bool> loadNewer() async {
    final newestVisibleId = _messages.firstServerId;
    if (newestVisibleId == null) {
      return false;
    }
    _mode = ConversationWindowMode.historyBrowsing;
    state = AsyncData(_buildState(isLoadingNewer: true));
    try {
      await _repository.loadNewer(newestVisibleId);
      _messages = _windowAfterHistoryChange();
      if (_messages.firstServerId ==
          _repository.latestSync(limit: 1).firstOrNull?.serverId) {
        _mode = ConversationWindowMode.liveLatest;
        _isAtLiveEdge = true;
        _anchorMessageId = null;
        _pendingLiveCount = 0;
      }
      state = AsyncData(_buildState());
      return true;
    } catch (error) {
      state = AsyncData(_buildState(errorMessage: '$error'));
      return false;
    }
  }

  Future<void> jumpToLatest() async {
    final latest = await _repository.refreshLatest(limit: _windowLimit);
    _messages = latest.messages;
    _mode = ConversationWindowMode.liveLatest;
    _anchorMessageId = null;
    _highlightedMessageId = null;
    _unreadAnchorMessageId = null;
    _pendingLiveCount = 0;
    _isAtLiveEdge = true;
    state = AsyncData(_buildState());
  }

  Future<bool> jumpToMessage(int messageId, {bool highlight = true}) async {
    await _loadLaunchRequest(
      LaunchMessageRequest(messageId, highlight: highlight),
    );
    state = AsyncData(_buildState());
    return _messages.any((message) => message.serverId == messageId);
  }

  void updateLiveEdge(bool isAtLiveEdge) {
    _isAtLiveEdge = isAtLiveEdge;
    if (isAtLiveEdge) {
      _pendingLiveCount = 0;
      if (_mode == ConversationWindowMode.historyBrowsing) {
        _mode = ConversationWindowMode.liveLatest;
      }
    }
    if (state.hasValue) {
      state = AsyncData(_buildState());
    }
  }

  void cacheVisibleRange(List<int> visibleServerMessageIds) {
    _repository.cacheViewport(
      launchRequest: _args.launchRequest,
      anchorMessageId: _anchorMessageId,
      visibleMessageIds: visibleServerMessageIds,
      isAtLiveEdge: _isAtLiveEdge,
    );
  }

  void onMessageVisible(int? messageId) {
    if (messageId == null) {
      return;
    }
    if (_currentReadMessageId == null || messageId > _currentReadMessageId!) {
      _currentReadMessageId = messageId;
      _readSyncDebounceTimer?.cancel();
      _readSyncDebounceTimer = Timer(_readSyncDebounce, () {
        unawaited(flushReadStatus());
      });
    }
  }

  Future<bool> flushReadStatus() async {
    final messageId = _currentReadMessageId;
    if (messageId == null || messageId == _lastReadSyncedMessageId) {
      return false;
    }
    try {
      await _repository.markAsRead(messageId);
      _lastReadSyncedMessageId = messageId;
      _shouldRefreshChats = true;
      if (state.hasValue) {
        state = AsyncData(_buildState());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  List<ConversationMessage> _windowAfterHistoryChange() {
    if (_anchorMessageId != null) {
      final around = _repository.currentAroundSync(
        _anchorMessageId!,
        before: _windowLimit ~/ 2,
        after: _windowLimit ~/ 2,
      );
      if (around.messages.isNotEmpty) {
        return around.messages;
      }
    }
    return _repository.warmWindow(limit: _windowLimit);
  }

  ConversationTimelineState _buildState({
    bool isLoadingOlder = false,
    bool isLoadingNewer = false,
    String? errorMessage,
    bool messageUnavailable = false,
  }) {
    final oldestVisibleId = _messages.lastServerId;
    final newestVisibleId = _messages.firstServerId;
    final hasOlder = oldestVisibleId != null
        ? _repository.hasOlderAvailable(oldestVisibleId)
        : false;
    final hasNewer = newestVisibleId != null
        ? _repository.hasNewerAvailable(newestVisibleId)
        : false;
    return (
      entries: _repository.buildTimelineEntries(
        messages: _messages,
        unreadMarkerMessageId: _unreadAnchorMessageId,
        isLoadingOlder: isLoadingOlder,
        isLoadingNewer: isLoadingNewer,
        hasOlder: hasOlder,
        hasNewer: hasNewer && !_isAtLiveEdge,
      ),
      isLoadingOlder: isLoadingOlder,
      isLoadingNewer: isLoadingNewer,
      showJumpToLatest: !_isAtLiveEdge,
      errorMessage: errorMessage,
      highlightedMessageId: _highlightedMessageId,
      unreadAnchorMessageId: _unreadAnchorMessageId,
      hasOlder: hasOlder,
      hasNewer: hasNewer,
      shouldRefreshChats: _shouldRefreshChats,
      messageUnavailable: messageUnavailable,
      pendingLiveCount: _pendingLiveCount,
    );
  }
}

final conversationTimelineViewModelProvider =
    AsyncNotifierProvider.family<
      ConversationTimelineViewModel,
      ConversationTimelineState,
      ConversationTimelineArgs
    >(ConversationTimelineViewModel.new);

extension on List<ConversationMessage> {
  ConversationMessage? get firstOrNull => isEmpty ? null : first;

  int? get firstServerId =>
      firstWhereOrNull((message) => message.serverId != null)?.serverId;

  int? get lastServerId =>
      lastWhereOrNull((message) => message.serverId != null)?.serverId;

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
