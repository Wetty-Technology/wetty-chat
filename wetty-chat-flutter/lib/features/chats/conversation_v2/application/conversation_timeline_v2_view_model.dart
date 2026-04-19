import 'dart:async';

import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/application/timeline_viewport_facts.dart';
import 'package:chahua/features/chats/conversation_v2/data/fake_conversation_timeline_v2_repository.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ConversationTimelineV2Identity = ({
  String chatId,
  String? threadRootId,
});

enum ConversationTimelineV2ViewportCommandKind {
  none,
  resetToCenterOrigin,
  scrollToBottom,
}

typedef ConversationTimelineV2State = ({
  List<ConversationMessageV2> beforeMessages,
  List<ConversationMessageV2> afterMessages,
  bool canLoadOlder,
  bool canLoadNewer,
  bool isLoadingOlder,
  bool isLoadingNewer,
  bool isResolvingJump,
  String? highlightedStableKey,
  double centerViewportFraction,
  ConversationTimelineV2ViewportCommandKind viewportCommandKind,
  int viewportCommandGeneration,
});

class ConversationTimelineV2ViewModel
    extends AsyncNotifier<ConversationTimelineV2State> {
  static const int _fakePageSize = 10;
  static const int _initialLoadedWindowSize = 50;

  final ConversationTimelineV2Identity identity;
  LaunchRequest? _initialLaunchRequest;
  late FakeConversationTimelineV2Repository _repository;
  bool _isLoadingOlder = false;
  bool _isLoadingNewer = false;
  TimelineViewportFacts? _latestViewportFacts;
  int _viewportCommandGeneration = 0;

  ConversationTimelineV2ViewModel(this.identity);

  @override
  Future<ConversationTimelineV2State> build() async {
    _repository = ref.read(
      fakeConversationTimelineV2RepositoryProvider(identity),
    );
    final initialWindow = _repository.buildInitialAnchoredWindow(
      loadedWindowSize: _initialLoadedWindowSize,
    );
    return (
      beforeMessages: initialWindow.beforeMessages,
      afterMessages: initialWindow.afterMessages,
      canLoadOlder: initialWindow.canLoadOlder,
      canLoadNewer: initialWindow.canLoadNewer,
      isLoadingOlder: false,
      isLoadingNewer: false,
      isResolvingJump: false,
      highlightedStableKey: null,
      centerViewportFraction: 0.5,
      viewportCommandKind: ConversationTimelineV2ViewportCommandKind.none,
      viewportCommandGeneration: _viewportCommandGeneration,
    );
  }

  void initialize(LaunchRequest launchRequest) {
    if (_initialLaunchRequest == launchRequest) {
      return;
    }
    _initialLaunchRequest = launchRequest;

    switch (launchRequest) {
      case LatestLaunchRequest():
        jumpToLatest();
      case UnreadLaunchRequest(:final lastReadMessageId):
        jumpToUnread(lastReadMessageId);
      case MessageLaunchRequest(:final messageId, :final highlight):
        jumpToMessageServerId(messageId, highlight: highlight);
    }
  }

  void onViewportChanged(TimelineViewportFacts facts) {
    _latestViewportFacts = facts;

    final currentState = state.asData?.value;
    if (currentState == null) {
      return;
    }

    _maybeLoadFromFacts(currentState, facts);
  }

  void jumpToLatest() {
    final latestWindow = _repository.latestWindow(
      limit: _initialLoadedWindowSize,
    );
    _updateState(
      beforeMessages: latestWindow.beforeMessages,
      afterMessages: latestWindow.afterMessages,
      canLoadOlder: latestWindow.canLoadOlder,
      canLoadNewer: latestWindow.canLoadNewer,
      isLoadingOlder: false,
      isLoadingNewer: false,
      isResolvingJump: false,
      highlightedStableKey: null,
      centerViewportFraction: 1.0,
      viewportCommandKind:
          ConversationTimelineV2ViewportCommandKind.resetToCenterOrigin,
      viewportCommandGeneration: ++_viewportCommandGeneration,
    );
  }

  void jumpToMessage(String stableKey) {
    final currentState = state.asData?.value;
    if (currentState == null) {
      return;
    }

    final messages = _flattenMessages(currentState);
    final targetIndex = messages.indexWhere(
      (message) => message.stableKey == stableKey,
    );
    if (targetIndex < 0) {
      final cachedWindow = _repository.windowAroundStableKey(
        stableKey,
        loadedWindowSize: _initialLoadedWindowSize,
      );
      if (cachedWindow != null) {
        _activateRepositoryWindow(
          cachedWindow,
          highlightedStableKey: stableKey,
          centerViewportFraction: 0.5,
        );
        return;
      }
    }

    _jumpWithinRenderedWindowOrResolve(
      currentState,
      messages,
      targetIndex,
      highlightedStableKey: stableKey,
      centerViewportFraction: 0.5,
    );
  }

  void jumpToMessageServerId(int messageId, {bool highlight = true}) {
    final currentState = state.asData?.value;
    if (currentState == null) {
      return;
    }

    final messages = _flattenMessages(currentState);
    final targetIndex = messages.indexWhere(
      (message) => message.serverMessageId == messageId,
    );
    if (targetIndex < 0) {
      final cachedWindow = _repository.windowAroundServerMessageId(
        messageId,
        loadedWindowSize: _initialLoadedWindowSize,
      );
      if (cachedWindow != null) {
        _activateRepositoryWindow(
          cachedWindow,
          highlightedStableKey: highlight
              ? cachedWindow.afterMessages.firstOrNull?.stableKey
              : null,
          centerViewportFraction: 0.5,
        );
        return;
      }
    }

    _jumpWithinRenderedWindowOrResolve(
      currentState,
      messages,
      targetIndex,
      highlightedStableKey: targetIndex >= 0 && highlight
          ? messages[targetIndex].stableKey
          : null,
      centerViewportFraction: 0.5,
    );
  }

  void jumpToUnread(int lastReadMessageId) {
    final currentState = state.asData?.value;
    if (currentState == null) {
      return;
    }

    final messages = _flattenMessages(currentState);
    final unreadIndex = messages.indexWhere(
      (message) =>
          message.serverMessageId != null &&
          message.serverMessageId! > lastReadMessageId,
    );

    if (unreadIndex < 0) {
      jumpToLatest();
      return;
    }

    _jumpWithinRenderedWindowOrResolve(
      currentState,
      messages,
      unreadIndex,
      highlightedStableKey: messages[unreadIndex].stableKey,
      centerViewportFraction: 0.0,
    );
  }

  void addMessage() {
    final currentState = state.asData?.value;
    if (currentState == null) {
      return;
    }

    final newMessage = _repository.appendLatest();

    _updateState(
      beforeMessages: currentState.beforeMessages,
      afterMessages: [...currentState.afterMessages, newMessage],
      canLoadOlder: currentState.canLoadOlder,
      canLoadNewer: currentState.canLoadNewer,
      isLoadingOlder: currentState.isLoadingOlder,
      isLoadingNewer: currentState.isLoadingNewer,
      isResolvingJump: currentState.isResolvingJump,
      highlightedStableKey: currentState.highlightedStableKey,
      centerViewportFraction: currentState.centerViewportFraction,
      viewportCommandKind: _latestViewportFacts?.isNearBottom ?? false
          ? ConversationTimelineV2ViewportCommandKind.scrollToBottom
          : ConversationTimelineV2ViewportCommandKind.none,
      viewportCommandGeneration: _latestViewportFacts?.isNearBottom ?? false
          ? ++_viewportCommandGeneration
          : currentState.viewportCommandGeneration,
    );
  }

  Future<void> loadOlder() async {
    final currentState = state.asData?.value;
    if (currentState == null || _isLoadingOlder) {
      return;
    }
    _isLoadingOlder = true;

    _updateState(
      beforeMessages: currentState.beforeMessages,
      afterMessages: currentState.afterMessages,
      canLoadOlder: currentState.canLoadOlder,
      canLoadNewer: currentState.canLoadNewer,
      isLoadingOlder: true,
      isLoadingNewer: currentState.isLoadingNewer,
      isResolvingJump: currentState.isResolvingJump,
      highlightedStableKey: currentState.highlightedStableKey,
      centerViewportFraction: currentState.centerViewportFraction,
      viewportCommandKind: currentState.viewportCommandKind,
      viewportCommandGeneration: currentState.viewportCommandGeneration,
    );

    try {
      final latestState = state.asData?.value;
      if (latestState == null) {
        return;
      }

      final earliestLoadedMessage = latestState.beforeMessages.isNotEmpty
          ? latestState.beforeMessages.first
          : latestState.afterMessages.first;
      final olderMessages = _repository.loadOlderPage(
        earliestLoadedMessage: earliestLoadedMessage,
        pageSize: _fakePageSize,
      );

      _updateState(
        beforeMessages: [...olderMessages, ...latestState.beforeMessages],
        afterMessages: latestState.afterMessages,
        canLoadOlder: true,
        canLoadNewer: latestState.canLoadNewer,
        isLoadingOlder: false,
        isLoadingNewer: latestState.isLoadingNewer,
        isResolvingJump: latestState.isResolvingJump,
        highlightedStableKey: latestState.highlightedStableKey,
        centerViewportFraction: latestState.centerViewportFraction,
        viewportCommandKind: latestState.viewportCommandKind,
        viewportCommandGeneration: latestState.viewportCommandGeneration,
      );
    } finally {
      _isLoadingOlder = false;
    }
  }

  Future<void> loadNewer() async {
    final currentState = state.asData?.value;
    if (currentState == null || _isLoadingNewer) {
      return;
    }
    _isLoadingNewer = true;

    _updateState(
      beforeMessages: currentState.beforeMessages,
      afterMessages: currentState.afterMessages,
      canLoadOlder: currentState.canLoadOlder,
      canLoadNewer: currentState.canLoadNewer,
      isLoadingOlder: currentState.isLoadingOlder,
      isLoadingNewer: true,
      isResolvingJump: currentState.isResolvingJump,
      highlightedStableKey: currentState.highlightedStableKey,
      centerViewportFraction: currentState.centerViewportFraction,
      viewportCommandKind: currentState.viewportCommandKind,
      viewportCommandGeneration: currentState.viewportCommandGeneration,
    );

    try {
      final latestState = state.asData?.value;
      if (latestState == null) {
        return;
      }

      final latestLoadedMessage = latestState.afterMessages.isNotEmpty
          ? latestState.afterMessages.last
          : latestState.beforeMessages.last;
      final newerMessages = _repository.loadNewerPage(
        latestLoadedMessage: latestLoadedMessage,
        pageSize: _fakePageSize,
      );

      _updateState(
        beforeMessages: latestState.beforeMessages,
        afterMessages: [...latestState.afterMessages, ...newerMessages],
        canLoadOlder: latestState.canLoadOlder,
        canLoadNewer: newerMessages.length == _fakePageSize,
        isLoadingOlder: latestState.isLoadingOlder,
        isLoadingNewer: false,
        isResolvingJump: latestState.isResolvingJump,
        highlightedStableKey: latestState.highlightedStableKey,
        centerViewportFraction: latestState.centerViewportFraction,
        viewportCommandKind: latestState.viewportCommandKind,
        viewportCommandGeneration: latestState.viewportCommandGeneration,
      );
    } finally {
      _isLoadingNewer = false;
    }
  }

  void _updateState({
    required List<ConversationMessageV2> beforeMessages,
    required List<ConversationMessageV2> afterMessages,
    required bool canLoadOlder,
    required bool canLoadNewer,
    required bool isLoadingOlder,
    required bool isLoadingNewer,
    required bool isResolvingJump,
    required String? highlightedStableKey,
    required double centerViewportFraction,
    required ConversationTimelineV2ViewportCommandKind viewportCommandKind,
    required int viewportCommandGeneration,
  }) {
    state = AsyncData((
      beforeMessages: beforeMessages,
      afterMessages: afterMessages,
      canLoadOlder: canLoadOlder,
      canLoadNewer: canLoadNewer,
      isLoadingOlder: isLoadingOlder,
      isLoadingNewer: isLoadingNewer,
      isResolvingJump: isResolvingJump,
      highlightedStableKey: highlightedStableKey,
      centerViewportFraction: centerViewportFraction,
      viewportCommandKind: viewportCommandKind,
      viewportCommandGeneration: viewportCommandGeneration,
    ));
  }

  void _maybeLoadFromFacts(
    ConversationTimelineV2State currentState,
    TimelineViewportFacts facts,
  ) {
    if (currentState.isResolvingJump) {
      return;
    }

    if (facts.isNearBottom &&
        currentState.canLoadNewer &&
        !currentState.isLoadingNewer) {
      unawaited(loadNewer());
    }

    if (facts.isNearTop &&
        currentState.canLoadOlder &&
        !currentState.isLoadingOlder) {
      unawaited(loadOlder());
    }
  }

  List<ConversationMessageV2> _flattenMessages(
    ConversationTimelineV2State state,
  ) {
    return <ConversationMessageV2>[
      ...state.beforeMessages,
      ...state.afterMessages,
    ];
  }

  void _activateTargetAfterCenter(
    List<ConversationMessageV2> messages,
    int targetIndex, {
    required String? highlightedStableKey,
    required double centerViewportFraction,
  }) {
    final targetMessage = messages[targetIndex];
    _activateWindow(
      beforeMessages: messages.take(targetIndex).toList(growable: false),
      afterMessages: messages.skip(targetIndex).toList(growable: false),
      canLoadOlder: true,
      canLoadNewer: _repository.hasNewerThan(targetMessage),
      highlightedStableKey: highlightedStableKey,
      centerViewportFraction: centerViewportFraction,
    );
  }

  void _jumpWithinRenderedWindowOrResolve(
    ConversationTimelineV2State currentState,
    List<ConversationMessageV2> messages,
    int targetIndex, {
    required String? highlightedStableKey,
    required double centerViewportFraction,
  }) {
    if (!_hasCachedAnchorContext(messages, targetIndex)) {
      _beginResolvingJump(currentState);
      return;
    }

    _activateTargetAfterCenter(
      messages,
      targetIndex,
      highlightedStableKey: highlightedStableKey,
      centerViewportFraction: centerViewportFraction,
    );
  }

  bool _hasCachedAnchorContext(
    List<ConversationMessageV2> messages,
    int targetIndex,
  ) {
    if (targetIndex < 0) {
      return false;
    }

    return targetIndex < messages.length;
  }

  void _beginResolvingJump(ConversationTimelineV2State currentState) {
    _setResolvingJump(currentState, isResolvingJump: true);
  }

  void _activateRepositoryWindow(
    FakeConversationTimelineV2Window window, {
    required String? highlightedStableKey,
    required double centerViewportFraction,
  }) {
    _activateWindow(
      beforeMessages: window.beforeMessages,
      afterMessages: window.afterMessages,
      canLoadOlder: window.canLoadOlder,
      canLoadNewer: window.canLoadNewer,
      highlightedStableKey: highlightedStableKey,
      centerViewportFraction: centerViewportFraction,
    );
  }

  void _activateWindow({
    required List<ConversationMessageV2> beforeMessages,
    required List<ConversationMessageV2> afterMessages,
    required bool canLoadOlder,
    required bool canLoadNewer,
    required String? highlightedStableKey,
    required double centerViewportFraction,
  }) {
    _updateState(
      beforeMessages: beforeMessages,
      afterMessages: afterMessages,
      canLoadOlder: canLoadOlder,
      canLoadNewer: canLoadNewer,
      isLoadingOlder: false,
      isLoadingNewer: false,
      isResolvingJump: false,
      highlightedStableKey: highlightedStableKey,
      centerViewportFraction: centerViewportFraction,
      viewportCommandKind:
          ConversationTimelineV2ViewportCommandKind.resetToCenterOrigin,
      viewportCommandGeneration: ++_viewportCommandGeneration,
    );
  }

  void _setResolvingJump(
    ConversationTimelineV2State currentState, {
    required bool isResolvingJump,
  }) {
    _updateState(
      beforeMessages: currentState.beforeMessages,
      afterMessages: currentState.afterMessages,
      canLoadOlder: currentState.canLoadOlder,
      canLoadNewer: currentState.canLoadNewer,
      isLoadingOlder: currentState.isLoadingOlder,
      isLoadingNewer: currentState.isLoadingNewer,
      isResolvingJump: isResolvingJump,
      highlightedStableKey: currentState.highlightedStableKey,
      centerViewportFraction: currentState.centerViewportFraction,
      viewportCommandKind: currentState.viewportCommandKind,
      viewportCommandGeneration: currentState.viewportCommandGeneration,
    );
  }
}

final conversationTimelineV2ViewModelProvider =
    AsyncNotifierProvider.family<
      ConversationTimelineV2ViewModel,
      ConversationTimelineV2State,
      ConversationTimelineV2Identity
    >(ConversationTimelineV2ViewModel.new, isAutoDispose: true);
