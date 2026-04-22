import 'dart:async';

import 'package:chahua/features/conversation/shared/data/conversation_canonical_message_store.dart';
import 'package:chahua/features/conversation/timeline/presentation/conversation_timeline_v2_state.dart';
import 'package:chahua/features/conversation/timeline/presentation/timeline_viewport_facts.dart';
import 'package:chahua/features/conversation/shared/data/conversation_timeline_v2_repository.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_timeline_v2_active_segment.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_identity.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:chahua/features/conversation/shared/domain/launch_request.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationTimelineV2ViewModel
    extends Notifier<ConversationTimelineV2State> {
  // Mostly temproary, we will remove these later
  static const int _initialLoadedWindowSize = 50;

  /// Identity (ChatID, threadID) for this VM
  final ConversationIdentity identity;

  /// Repository for this VM
  late ConversationTimelineV2Repository _repository;

  LaunchRequest? _initialLaunchRequest;

  /// Active segment containing the messages and some metadata
  ConversationTimelineV2ActiveSegment? _activeSegment;

  bool _bootstrapStarted = false;
  int? _highlightedServerMessageId;
  TimelineViewportFacts? _latestViewportFacts;
  String? _lastRenderedTailStableKey;

  /// Generation of the viewport command, incremented on each issuance
  int _viewportCommandGeneration = 0;
  ConversationTimelineV2ViewportCommand? _pendingViewportCommand;
  ConversationTimelineV2ViewportCommand _lastViewportCommand = const (
    kind: ConversationTimelineV2ViewportCommandKind.none,
    placement: ConversationTimelineV2ViewportPlacement.bottomPreferred,
  );

  /// Make sure to use `_setActiveSegmentMode` instead of assigning directly
  /// to avoid forgetting `ref.invalidateSelf()`.
  ConversationTimelineV2ActiveSegmentMode _activeSegmentMode =
      const ConversationTimelineV2ActiveSegmentMode.latest();

  ConversationTimelineV2ViewModel(this.identity);

  @override
  ConversationTimelineV2State build() {
    _repository = ref.read(conversationTimelineV2RepositoryProvider(identity));
    _activeSegment = ref.watch(
      conversationTimelineV2ActiveSegmentProvider((
        identity: identity,
        mode: _activeSegmentMode,
      )),
    );
    if (!_bootstrapStarted) {
      _bootstrapStarted = true;
      Future<void>.microtask(() async {
        await _bootstrapLatestSegment();
      });
    }
    if (_activeSegment != null) {
      return _stateFromActiveSegment(
        _activeSegment!,
        isLoadingNewer: false,
        isLoadingOlder: false,
      );
    }
    return _loadingState();
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

    if (state.isBootstrapping) {
      return;
    }

    if (facts.isNearTop && state.canLoadOlder && !state.isLoadingOlder) {
      unawaited(loadOlder());
    }
    if (facts.isNearBottom && state.canLoadNewer && !state.isLoadingNewer) {
      unawaited(loadNewer());
    }
  }

  Future<void> toggleReaction(ConversationMessageV2 message, String emoji) {
    final messageId = message.serverMessageId;
    if (messageId == null ||
        message.content is StickerMessageContent ||
        message.isDeleted) {
      return Future<void>.value();
    }
    return _repository.toggleReaction(messageId: messageId, emoji: emoji);
  }

  Future<void> deleteMessage(ConversationMessageV2 message) {
    final messageId = message.serverMessageId;
    if (messageId == null || message.isDeleted) {
      return Future<void>.value();
    }
    return _repository.deleteMessage(messageId);
  }

  Future<void> jumpToLatest() async {
    unawaited(
      _repository.refreshLatestSegment(limit: _initialLoadedWindowSize),
    );
    _setActiveSegmentMode(
      const ConversationTimelineV2ActiveSegmentMode.latest(),
    );
    _issueViewportCommand(
      kind: ConversationTimelineV2ViewportCommandKind.resetToCenterOrigin,
      placement: ConversationTimelineV2ViewportPlacement.bottomPreferred,
    );
    _highlightedServerMessageId = null;
  }

  /// Ensures the viewport is anchored to the tail of the latest segment.
  /// No-op when the user is already on the latest slice near the bottom —
  /// the realtime applier's auto-scroll will handle surfacing the echo.
  void followLatestTailIfNeeded() {
    final isFollowingTail =
        (_activeSegment?.isLatestSlice ?? false) &&
        (_latestViewportFacts?.isNearBottom ?? false);
    if (isFollowingTail) {
      return;
    }
    unawaited(jumpToLatest());
  }

  Future<void> jumpToMessageServerId(
    int messageId, {
    bool highlight = true,
  }) async {
    unawaited(
      _repository.refreshAroundServerMessageId(
        messageId,
        limit: _initialLoadedWindowSize,
      ),
    );

    final aroundMode = ConversationTimelineV2ActiveSegmentMode.around(
      messageId,
    );
    _setActiveSegmentMode(aroundMode);
    _highlightedServerMessageId = highlight ? messageId : null;
    _issueViewportCommand(
      kind: ConversationTimelineV2ViewportCommandKind.resetToCenterOrigin,
      placement: ConversationTimelineV2ViewportPlacement.topPreferred,
    );
  }

  void jumpToUnread(int lastReadMessageId) {
    _markRepositoryTodo('jumpToUnread(lastReadMessageId: $lastReadMessageId)');
  }

  Future<void> _bootstrapLatestSegment() async {
    try {
      await _repository.refreshLatestSegment(limit: _initialLoadedWindowSize);
      final latestSegment = _activeSegment;
      if (latestSegment == null) {
        debugPrint('bootstrapLatestSegment: latest segment missing after load');
        state = _loadingState(isBootstrapping: false);
        return;
      }
      state = _stateFromActiveSegment(latestSegment);
    } catch (error) {
      debugPrint('bootstrapLatestSegment error: $error');
      state = _loadingState(isBootstrapping: false);
    }
  }

  Future<void> loadOlder() async {
    if (state.isLoadingOlder || state.isBootstrapping || !state.canLoadOlder) {
      return;
    }

    if (_activeSegment == null || _activeSegment!.orderedMessages.isEmpty) {
      return;
    }

    final anchorServerMessageId = _firstServerMessageId(
      _activeSegment!.orderedMessages,
    );
    if (anchorServerMessageId == null) {
      return;
    }

    state = state.copyWith(isLoadingOlder: true);

    try {
      await _repository.loadOlderBeforeAnchor(anchorServerMessageId, limit: 20);
    } finally {
      state = state.copyWith(isLoadingOlder: false);
    }
  }

  Future<void> loadNewer() async {
    if (state.isLoadingNewer || state.isBootstrapping || !state.canLoadNewer) {
      return;
    }

    if (_activeSegment == null || _activeSegment!.orderedMessages.isEmpty) {
      return;
    }
    final anchorServerMessageId = _lastServerMessageId(
      _activeSegment!.orderedMessages,
    );
    if (anchorServerMessageId == null) {
      return;
    }

    state = state.copyWith(isLoadingNewer: true);

    try {
      await _repository.loadNewerAfterAnchor(anchorServerMessageId, limit: 20);
    } finally {
      state = state.copyWith(isLoadingNewer: false);
    }
  }

  ConversationTimelineV2State _stateFromActiveSegment(
    ConversationTimelineV2ActiveSegment segment, {
    bool? isLoadingOlder,
    bool? isLoadingNewer,
  }) {
    final splitAfterServerMessageId =
        _activeSegmentMode.splitAfterServerMessageId;
    final beforeMessages = <ConversationMessageV2>[];
    final afterMessages = <ConversationMessageV2>[];

    // TODO: Fix this
    // This is currently a workaround to handle when new message arrives we properly
    // put them in the after segment.
    // I think there gotta be a better way to handle this.
    if (_activeSegmentMode.isLatest &&
        _activeSegmentMode.latestSplitAfterServerMessageId == null &&
        segment.orderedMessages.isNotEmpty) {
      _activeSegmentMode = ConversationTimelineV2ActiveSegmentMode.latest(
        latestSplitAfterServerMessageId:
            segment.orderedMessages.last.serverMessageId! + 1,
      );
    }

    if (splitAfterServerMessageId == null) {
      beforeMessages.addAll(segment.orderedMessages);
    } else {
      final splitIndex = segment.orderedMessages.indexWhere(
        (message) => message.serverMessageId == splitAfterServerMessageId,
      );
      if (splitIndex == -1) {
        beforeMessages.addAll(segment.orderedMessages);
      } else {
        beforeMessages.addAll(segment.orderedMessages.take(splitIndex));
        afterMessages.addAll(segment.orderedMessages.skip(splitIndex));
      }
    }
    String? highlightedStableKey;
    if (_highlightedServerMessageId != null) {
      for (final message in segment.orderedMessages) {
        if (message.serverMessageId == _highlightedServerMessageId) {
          highlightedStableKey = message.stableKey;
          break;
        }
      }
    }
    final currentTailStableKey = segment.orderedMessages.isEmpty
        ? null
        : segment.orderedMessages.last.stableKey;
    if (segment.isLatestSlice &&
        (_latestViewportFacts?.isNearBottom ?? false) &&
        _lastRenderedTailStableKey != null &&
        currentTailStableKey != null &&
        currentTailStableKey != _lastRenderedTailStableKey) {
      _issueViewportCommand(
        kind: ConversationTimelineV2ViewportCommandKind.scrollToBottom,
        placement: ConversationTimelineV2ViewportPlacement.bottomPreferred,
      );
    }
    final viewportCommand = _takePendingViewportCommand(
      hasMessages: segment.orderedMessages.isNotEmpty,
    );
    _lastRenderedTailStableKey = currentTailStableKey;

    return ConversationTimelineV2State(
      beforeMessages: beforeMessages,
      afterMessages: afterMessages,
      canLoadOlder: segment.canLoadBefore,
      canLoadNewer: segment.canLoadAfter,
      isLoadingOlder: isLoadingOlder ?? state.isLoadingOlder,
      isLoadingNewer: isLoadingNewer ?? state.isLoadingNewer,
      isResolvingJump: false,
      highlightedStableKey: highlightedStableKey,
      viewportCommand: viewportCommand?.command ?? _lastViewportCommand,
      viewportCommandGeneration:
          viewportCommand?.generation ?? _viewportCommandGeneration,
      isBootstrapping: false,
    );
  }

  ({ConversationTimelineV2ViewportCommand command, int generation})?
  _takePendingViewportCommand({required bool hasMessages}) {
    // We can execute a pending viewport command if we have messages.
    if ((_pendingViewportCommand != null) && hasMessages) {
      final command = _pendingViewportCommand!;
      _pendingViewportCommand = null;
      return (command: command, generation: ++_viewportCommandGeneration);
    }
    return null;
  }

  int? _firstServerMessageId(List<ConversationMessageV2> messages) {
    for (final message in messages) {
      final serverMessageId = message.serverMessageId;
      if (serverMessageId != null) {
        return serverMessageId;
      }
    }
    return null;
  }

  int? _lastServerMessageId(List<ConversationMessageV2> messages) {
    for (final message in messages.reversed) {
      final serverMessageId = message.serverMessageId;
      if (serverMessageId != null) {
        return serverMessageId;
      }
    }
    return null;
  }

  ConversationTimelineV2ViewportCommand _viewportCommand({
    required ConversationTimelineV2ViewportCommandKind kind,
    required ConversationTimelineV2ViewportPlacement placement,
  }) {
    return (kind: kind, placement: placement);
  }

  void _issueViewportCommand({
    required ConversationTimelineV2ViewportCommandKind kind,
    required ConversationTimelineV2ViewportPlacement placement,
  }) {
    final command = _viewportCommand(kind: kind, placement: placement);
    _pendingViewportCommand = command;
    _lastViewportCommand = command;
    ++_viewportCommandGeneration;
  }

  ConversationTimelineV2State _loadingState({bool isBootstrapping = true}) {
    return ConversationTimelineV2State(
      viewportCommand: _viewportCommand(
        kind: ConversationTimelineV2ViewportCommandKind.none,
        placement: ConversationTimelineV2ViewportPlacement.bottomPreferred,
      ),
      viewportCommandGeneration: _viewportCommandGeneration,
      isBootstrapping: isBootstrapping,
    );
  }

  /// Updates the active segment selection and invalidates this notifier so
  /// build() re-subscribes to the matching active-segment provider. Command
  /// paths should always use this helper instead of assigning `_activeSegmentMode`
  /// directly, to avoid forgetting `ref.invalidateSelf()`.
  void _setActiveSegmentMode(ConversationTimelineV2ActiveSegmentMode mode) {
    _activeSegmentMode = mode;
    ref.invalidateSelf();
  }

  void _markRepositoryTodo(String operation) {
    // TODO(codex): Reimplement this operation against the canonical message
    // store-backed repository and active-segment model.
    assert(operation.isNotEmpty);
    debugPrint('markRepositoryTodo: $operation');
    unawaited(
      Future<void>.microtask(() {
        ref.invalidateSelf();
      }),
    );
  }
}

final conversationTimelineV2ViewModelProvider =
    NotifierProvider.family<
      ConversationTimelineV2ViewModel,
      ConversationTimelineV2State,
      ConversationIdentity
    >(ConversationTimelineV2ViewModel.new, isAutoDispose: true);
