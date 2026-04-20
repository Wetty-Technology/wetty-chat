import 'dart:async';

import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_message_store.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_state.dart';
import 'package:chahua/features/chats/conversation_v2/application/timeline_viewport_facts.dart';
import 'package:chahua/features/chats/conversation_v2/data/conversation_timeline_v2_repository.dart';
import 'package:chahua/features/chats/conversation_v2/data/conversation_timeline_v2_repository_impl.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_active_segment.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_identity.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationTimelineV2ViewModel
    extends Notifier<ConversationTimelineV2State> {
  // Mostly temproary, we will remove these later
  static const int _initialLoadedWindowSize = 50;
  static const int _farHistoryTargetServerMessageId = -1000;

  /// Identity (ChatID, threadID) for this VM
  final ConversationTimelineV2Identity identity;

  /// Repository for this VM
  late ConversationTimelineV2Repository _repository;

  LaunchRequest? _initialLaunchRequest;

  /// Active segment containing the messages and some metadata
  ConversationTimelineV2ActiveSegment? _activeSegment;

  bool _bootstrapStarted = false;
  int? _highlightedServerMessageId;

  /// Generation of the viewport command, incremented on each issuance
  int _viewportCommandGeneration = 0;
  ConversationTimelineV2ViewportCommand _pendingViewportCommand = (
    centerViewportFraction: 1.0,
    kind: ConversationTimelineV2ViewportCommandKind.none,
  );

  /// Latest viewport facts from the scroll controller
  TimelineViewportFacts? _latestViewportFacts;

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
      return _stateFromActiveSegment(_activeSegment!);
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

  Future<void> jumpToLatest() async {
    _setActiveSegmentMode(
      const ConversationTimelineV2ActiveSegmentMode.latest(),
    );
    _pendingViewportCommand = _viewportCommandForCurrentMode(
      ConversationTimelineV2ViewportCommandKind.resetToCenterOrigin,
    );
    _highlightedServerMessageId = null;
    await _repository.refreshLatestSegment(limit: _initialLoadedWindowSize);
    final latestSegment = _activeSegment;
    if (latestSegment == null) {
      return;
    }
    _activeSegmentMode = ConversationTimelineV2ActiveSegmentMode.latest(
      latestSplitAfterServerMessageId:
          latestSegment.orderedMessages.last.serverMessageId,
    );
  }

  void jumpToMessage(String stableKey) {
    _markRepositoryTodo('jumpToMessage(stableKey: $stableKey)');
  }

  void jumpToMessageServerId(int messageId, {bool highlight = true}) {
    _markRepositoryTodo(
      'jumpToMessageServerId(messageId: $messageId, highlight: $highlight)',
    );
  }

  void jumpToUnread(int lastReadMessageId) {
    _markRepositoryTodo('jumpToUnread(lastReadMessageId: $lastReadMessageId)');
  }

  Future<void> jumpToFarHistory() async {
    await _repository.refreshAroundServerMessageId(
      _farHistoryTargetServerMessageId,
      limit: _initialLoadedWindowSize,
    );
    _setActiveSegmentMode(
      const ConversationTimelineV2ActiveSegmentMode.around(
        _farHistoryTargetServerMessageId,
      ),
    );
    _highlightedServerMessageId = _farHistoryTargetServerMessageId;
    _pendingViewportCommand = _viewportCommandForCurrentMode(
      ConversationTimelineV2ViewportCommandKind.resetToCenterOrigin,
    );
  }

  Future<void> addMessage() async {
    if (_latestViewportFacts?.isNearBottom ?? false) {
      _pendingViewportCommand = _viewportCommandForCurrentMode(
        ConversationTimelineV2ViewportCommandKind.scrollToBottom,
      );
    }
    await _repository.addLatestFakeMessage();
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

    final anchorServerMessageId =
        _activeSegment!.orderedMessages.first.serverMessageId!;

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
    final anchorServerMessageId =
        _activeSegment!.orderedMessages.last.serverMessageId!;

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
    if (_activeSegmentMode.isLatest &&
        segment.orderedMessages.isNotEmpty &&
        _activeSegmentMode.splitAfterServerMessageId == null) {
      _activeSegmentMode = ConversationTimelineV2ActiveSegmentMode.latest(
        latestSplitAfterServerMessageId:
            segment.orderedMessages.last.serverMessageId,
      );
    }
    final splitAfterServerMessageId =
        _activeSegmentMode.splitAfterServerMessageId;
    final beforeMessages = <ConversationMessageV2>[];
    final afterMessages = <ConversationMessageV2>[];

    if (splitAfterServerMessageId == null) {
      beforeMessages.addAll(segment.orderedMessages);
    } else {
      for (final message in segment.orderedMessages) {
        final serverMessageId = message.serverMessageId!;
        if (serverMessageId > splitAfterServerMessageId) {
          afterMessages.add(message);
        } else {
          beforeMessages.add(message);
        }
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
    final viewportCommand = _takePendingViewportCommand(
      hasMessages: segment.orderedMessages.isNotEmpty,
    );

    return ConversationTimelineV2State(
      beforeMessages: beforeMessages,
      afterMessages: afterMessages,
      canLoadOlder: segment.canLoadBefore,
      canLoadNewer: segment.canLoadAfter,
      isLoadingOlder: isLoadingOlder ?? state.isLoadingOlder,
      isLoadingNewer: isLoadingNewer ?? state.isLoadingNewer,
      isResolvingJump: false,
      highlightedStableKey: highlightedStableKey,
      viewportCommand: viewportCommand.command,
      viewportCommandGeneration: viewportCommand.generation,
      isBootstrapping: false,
    );
  }

  ({ConversationTimelineV2ViewportCommand command, int generation})
  _takePendingViewportCommand({required bool hasMessages}) {
    if (!hasMessages) {
      return (
        command: _viewportCommandForCurrentMode(
          ConversationTimelineV2ViewportCommandKind.none,
        ),
        generation: _viewportCommandGeneration,
      );
    }

    final generation =
        _pendingViewportCommand.kind !=
            ConversationTimelineV2ViewportCommandKind.none
        ? ++_viewportCommandGeneration
        : _viewportCommandGeneration;
    final command = _pendingViewportCommand;
    _pendingViewportCommand = _viewportCommandForCurrentMode(
      ConversationTimelineV2ViewportCommandKind.none,
    );
    return (command: command, generation: generation);
  }

  ConversationTimelineV2ViewportCommand _viewportCommandForCurrentMode(
    ConversationTimelineV2ViewportCommandKind kind,
  ) {
    return (
      centerViewportFraction: _activeSegmentMode.isLatest ? 1.0 : 0.0,
      kind: kind,
    );
  }

  ConversationTimelineV2State _loadingState({bool isBootstrapping = true}) {
    return ConversationTimelineV2State(
      viewportCommand: _viewportCommandForCurrentMode(
        ConversationTimelineV2ViewportCommandKind.none,
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
      ConversationTimelineV2Identity
    >(ConversationTimelineV2ViewModel.new, isAutoDispose: true);
