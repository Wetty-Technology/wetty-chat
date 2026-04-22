import 'dart:async';

import 'package:chahua/features/conversation/shared/data/conversation_canonical_message_store.dart';
import 'package:chahua/features/conversation/shared/data/conversation_timeline_v2_repository.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_timeline_v2_active_segment.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_identity.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:chahua/features/conversation/shared/domain/launch_request.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation_timeline_view_model.freezed.dart';

// ============ Private Types ============
@immutable
/// Internal policy for splitting messages into before and after segments.
class _TimelineRenderSplitPolicy {
  const _TimelineRenderSplitPolicy.none()
    : anchorServerMessageId = null,
      includeAnchorInAfter = false;

  const _TimelineRenderSplitPolicy.fromMessageInclusive(
    this.anchorServerMessageId,
  ) : includeAnchorInAfter = true;

  const _TimelineRenderSplitPolicy.afterMessage(this.anchorServerMessageId)
    : includeAnchorInAfter = false;

  final int? anchorServerMessageId;
  final bool includeAnchorInAfter;
}

// ============ Public Types ============

/// Commands issued by the timeline view model to the viewport controller.
enum ConversationTimelineViewportCommandKind {
  none,
  resetToCenterOrigin,
  scrollToBottom,
}

/// The preferred placement for the viewport command.
enum ConversationTimelineViewportPlacement { bottomPreferred, topPreferred }

/// A viewport command issued by the timeline view model to the viewport controller.
typedef ConversationTimelineViewportCommand = ({
  ConversationTimelineViewportCommandKind kind,
  ConversationTimelineViewportPlacement placement,
});

@freezed
/// The state of the timeline view model.
abstract class ConversationTimelineState with _$ConversationTimelineState {
  const factory ConversationTimelineState({
    @Default(<ConversationMessageV2>[])
    List<ConversationMessageV2> beforeMessages,
    @Default(<ConversationMessageV2>[])
    List<ConversationMessageV2> afterMessages,
    @Default(false) bool canLoadOlder,
    @Default(false) bool canLoadNewer,
    @Default(false) bool isLoadingOlder,
    @Default(false) bool isLoadingNewer,
    @Default(false) bool isResolvingJump,
    String? highlightedStableKey,
    @Default((
      kind: ConversationTimelineViewportCommandKind.none,
      placement: ConversationTimelineViewportPlacement.bottomPreferred,
    ))
    ConversationTimelineViewportCommand viewportCommand,
    @Default(0) int viewportCommandGeneration,
    @Default(true) bool isBootstrapping,
  }) = _ConversationTimelineState;
}

/// Facts about the viewport reported by view to the view model.
@freezed
abstract class TimelineViewportFacts with _$TimelineViewportFacts {
  const factory TimelineViewportFacts({
    @Default(false) bool isNearTop,
    @Default(true) bool isNearBottom,
  }) = _TimelineViewportFacts;
}

// ============ View Model ============
class ConversationTimelineViewModel
    extends Notifier<ConversationTimelineState> {
  // Mostly temproary, we will remove these later
  static const int _initialLoadedWindowSize = 50;

  /// Identity (ChatID, threadID) for this VM
  final ConversationIdentity identity;

  /// Repository for this VM
  late ConversationTimelineV2Repository _repository;

  LaunchRequest? _initialLaunchRequest;

  /// Active segment containing the messages and some metadata
  ConversationTimelineActiveSegment? _activeSegment;

  bool _bootstrapStarted = false;
  int? _highlightedServerMessageId;
  TimelineViewportFacts? _latestViewportFacts;
  String? _lastRenderedTailStableKey;
  _TimelineRenderSplitPolicy _renderSplitPolicy =
      const _TimelineRenderSplitPolicy.none();

  /// Generation of the viewport command, incremented on each issuance
  int _viewportCommandGeneration = 0;
  ConversationTimelineViewportCommand? _pendingViewportCommand;
  ConversationTimelineViewportCommand _lastViewportCommand = const (
    kind: ConversationTimelineViewportCommandKind.none,
    placement: ConversationTimelineViewportPlacement.bottomPreferred,
  );

  /// Make sure to use `_setActiveSegmentMode` instead of assigning directly
  /// to avoid forgetting `ref.invalidateSelf()`.
  ConversationTimelineActiveSegmentMode _activeSegmentMode =
      const ConversationTimelineActiveSegmentMode.latest();

  ConversationTimelineViewModel(this.identity);

  @override
  ConversationTimelineState build() {
    _repository = ref.read(conversationTimelineV2RepositoryProvider(identity));
    _activeSegment = ref.watch(
      conversationTimelineActiveSegmentProvider((
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
    _setActiveSegmentMode(const ConversationTimelineActiveSegmentMode.latest());
    _issueViewportCommand(
      kind: ConversationTimelineViewportCommandKind.resetToCenterOrigin,
      placement: ConversationTimelineViewportPlacement.bottomPreferred,
    );
    _highlightedServerMessageId = null;
    _renderSplitPolicy = const _TimelineRenderSplitPolicy.none();
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

    final aroundMode = ConversationTimelineActiveSegmentMode.around(messageId);
    _setActiveSegmentMode(aroundMode);
    _highlightedServerMessageId = highlight ? messageId : null;
    _renderSplitPolicy = _TimelineRenderSplitPolicy.fromMessageInclusive(
      messageId,
    );
    _issueViewportCommand(
      kind: ConversationTimelineViewportCommandKind.resetToCenterOrigin,
      placement: ConversationTimelineViewportPlacement.topPreferred,
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

  ConversationTimelineState _stateFromActiveSegment(
    ConversationTimelineActiveSegment segment, {
    bool? isLoadingOlder,
    bool? isLoadingNewer,
  }) {
    _captureLatestTailSplitIfNeeded(segment);

    final beforeMessages = <ConversationMessageV2>[];
    final afterMessages = <ConversationMessageV2>[];
    final splitAnchorServerMessageId = _renderSplitPolicy.anchorServerMessageId;
    if (splitAnchorServerMessageId == null) {
      beforeMessages.addAll(segment.orderedMessages);
    } else {
      _splitMessages(
        segment.orderedMessages,
        policy: _renderSplitPolicy,
        beforeMessages: beforeMessages,
        afterMessages: afterMessages,
      );
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
        kind: ConversationTimelineViewportCommandKind.scrollToBottom,
        placement: ConversationTimelineViewportPlacement.bottomPreferred,
      );
    }
    final viewportCommand = _takePendingViewportCommand(
      hasMessages: segment.orderedMessages.isNotEmpty,
    );
    _lastRenderedTailStableKey = currentTailStableKey;

    return ConversationTimelineState(
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

  ({ConversationTimelineViewportCommand command, int generation})?
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

  ConversationTimelineViewportCommand _viewportCommand({
    required ConversationTimelineViewportCommandKind kind,
    required ConversationTimelineViewportPlacement placement,
  }) {
    return (kind: kind, placement: placement);
  }

  void _issueViewportCommand({
    required ConversationTimelineViewportCommandKind kind,
    required ConversationTimelineViewportPlacement placement,
  }) {
    final command = _viewportCommand(kind: kind, placement: placement);
    _pendingViewportCommand = command;
    _lastViewportCommand = command;
    ++_viewportCommandGeneration;
  }

  ConversationTimelineState _loadingState({bool isBootstrapping = true}) {
    return ConversationTimelineState(
      viewportCommand: _viewportCommand(
        kind: ConversationTimelineViewportCommandKind.none,
        placement: ConversationTimelineViewportPlacement.bottomPreferred,
      ),
      viewportCommandGeneration: _viewportCommandGeneration,
      isBootstrapping: isBootstrapping,
    );
  }

  /// Updates the active segment selection and invalidates this notifier so
  /// build() re-subscribes to the matching active-segment provider. Command
  /// paths should always use this helper instead of assigning `_activeSegmentMode`
  /// directly, to avoid forgetting `ref.invalidateSelf()`.
  void _setActiveSegmentMode(ConversationTimelineActiveSegmentMode mode) {
    _activeSegmentMode = mode;
    ref.invalidateSelf();
  }

  void _captureLatestTailSplitIfNeeded(
    ConversationTimelineActiveSegment segment,
  ) {
    if (!_activeSegmentMode.isLatest ||
        _renderSplitPolicy.anchorServerMessageId != null) {
      return;
    }

    final tailServerMessageId = _lastServerMessageId(segment.orderedMessages);
    if (tailServerMessageId == null) {
      return;
    }

    _renderSplitPolicy = _TimelineRenderSplitPolicy.afterMessage(
      tailServerMessageId,
    );
  }

  void _splitMessages(
    List<ConversationMessageV2> messages, {
    required _TimelineRenderSplitPolicy policy,
    required List<ConversationMessageV2> beforeMessages,
    required List<ConversationMessageV2> afterMessages,
  }) {
    final anchorServerMessageId = policy.anchorServerMessageId;
    if (anchorServerMessageId == null) {
      beforeMessages.addAll(messages);
      return;
    }

    for (final message in messages) {
      final serverMessageId = message.serverMessageId;
      if (serverMessageId == null) {
        afterMessages.add(message);
        continue;
      }

      final belongsAfter = policy.includeAnchorInAfter
          ? serverMessageId >= anchorServerMessageId
          : serverMessageId > anchorServerMessageId;
      if (belongsAfter) {
        afterMessages.add(message);
      } else {
        beforeMessages.add(message);
      }
    }
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

final conversationTimelineViewModelProvider =
    NotifierProvider.family<
      ConversationTimelineViewModel,
      ConversationTimelineState,
      ConversationIdentity
    >(ConversationTimelineViewModel.new, isAutoDispose: true);
