import 'dart:async';

import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_message_store.dart';
import 'package:chahua/features/chats/conversation_v2/application/timeline_viewport_facts.dart';
import 'package:chahua/features/chats/conversation_v2/data/fake_conversation_timeline_v2_repository.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_active_segment.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:flutter/foundation.dart';
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
  bool isBootstrapping,
});

class ConversationTimelineV2ViewModel
    extends Notifier<ConversationTimelineV2State> {
  static const int _initialLoadedWindowSize = 50;

  final ConversationTimelineV2Identity identity;
  LaunchRequest? _initialLaunchRequest;
  late FakeConversationTimelineV2Repository _repository;
  int _viewportCommandGeneration = 0;
  TimelineViewportFacts? _latestViewportFacts;
  bool _scrollToBottomOnNextLatestUpdate = false;
  bool _bootstrapStarted = false;
  int? _splitAfterServerMessageId;

  ConversationTimelineV2ViewModel(this.identity);

  @override
  ConversationTimelineV2State build() {
    _repository = ref.read(
      fakeConversationTimelineV2RepositoryProvider(identity),
    );
    final latestSegment = ref.watch(
      conversationTimelineV2LatestActiveSegmentProvider(identity),
    );
    if (!_bootstrapStarted) {
      _bootstrapStarted = true;
      unawaited(_bootstrapLatestSegment());
    }
    if (latestSegment != null) {
      return _stateFromLatestSegment(latestSegment);
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
    // TODO(codex): Re-enable viewport-driven expansion once the repository can
    // expand the active segment before/after against the canonical store.
    assert(facts.isNearTop == facts.isNearTop);
  }

  Future<void> jumpToLatest() async {
    await _repository.ensureLatestSegmentLoaded(
      limit: _initialLoadedWindowSize,
    );
    final latestSegment = ref.read(
      conversationTimelineV2LatestActiveSegmentProvider(identity),
    );
    if (latestSegment == null) {
      return;
    }
    _splitAfterServerMessageId =
        latestSegment.orderedMessages.last.serverMessageId;
    state = _stateFromActiveSegment(
      latestSegment,
      centerViewportFraction: 1.0,
      viewportCommandKind:
          ConversationTimelineV2ViewportCommandKind.resetToCenterOrigin,
      viewportCommandGeneration: ++_viewportCommandGeneration,
      isBootstrapping: false,
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

  Future<void> addMessage() async {
    _scrollToBottomOnNextLatestUpdate =
        _latestViewportFacts?.isNearBottom ?? false;
    await _repository.addLatestFakeMessage();
  }

  Future<void> _bootstrapLatestSegment() async {
    try {
      await _repository.ensureLatestSegmentLoaded(
        limit: _initialLoadedWindowSize,
      );
      final latestSegment = ref.read(
        conversationTimelineV2LatestActiveSegmentProvider(identity),
      );
      if (latestSegment == null) {
        debugPrint('bootstrapLatestSegment: latest segment missing after load');
        state = _loadingState(isBootstrapping: false);
        return;
      }
      state = _stateFromLatestSegment(latestSegment);
    } catch (error) {
      debugPrint('bootstrapLatestSegment error: $error');
      state = _loadingState(isBootstrapping: false);
    }
  }

  ConversationTimelineV2State _stateFromLatestSegment(
    ConversationTimelineV2ActiveSegment segment,
  ) {
    final shouldScrollToBottom = _scrollToBottomOnNextLatestUpdate;
    final viewportCommandKind = shouldScrollToBottom
        ? ConversationTimelineV2ViewportCommandKind.scrollToBottom
        : ConversationTimelineV2ViewportCommandKind.none;
    final viewportCommandGeneration = shouldScrollToBottom
        ? ++_viewportCommandGeneration
        : _viewportCommandGeneration;
    _scrollToBottomOnNextLatestUpdate = false;
    return _stateFromActiveSegment(
      segment,
      centerViewportFraction: 1.0,
      viewportCommandKind: viewportCommandKind,
      viewportCommandGeneration: viewportCommandGeneration,
      isBootstrapping: false,
    );
  }

  Future<void> loadOlder() async {
    _markRepositoryTodo('loadOlder');
  }

  Future<void> loadNewer() async {
    _markRepositoryTodo('loadNewer');
  }

  ConversationTimelineV2State _stateFromActiveSegment(
    ConversationTimelineV2ActiveSegment segment, {
    required double centerViewportFraction,
    required ConversationTimelineV2ViewportCommandKind viewportCommandKind,
    required int viewportCommandGeneration,
    required bool isBootstrapping,
  }) {
    if (segment.orderedMessages.isNotEmpty &&
        _splitAfterServerMessageId == null) {
      _splitAfterServerMessageId = segment.orderedMessages.last.serverMessageId;
    }
    final splitAfterServerMessageId = _splitAfterServerMessageId;
    final beforeMessages = <ConversationMessageV2>[];
    final afterMessages = <ConversationMessageV2>[];

    if (splitAfterServerMessageId == null) {
      beforeMessages.addAll(segment.orderedMessages);
    } else {
      for (final message in segment.orderedMessages) {
        final serverMessageId = message.serverMessageId;
        if (serverMessageId != null &&
            serverMessageId > splitAfterServerMessageId) {
          afterMessages.add(message);
        } else {
          beforeMessages.add(message);
        }
      }
    }

    return (
      beforeMessages: beforeMessages,
      afterMessages: afterMessages,
      canLoadOlder: segment.canLoadBefore,
      canLoadNewer: segment.canLoadAfter,
      isLoadingOlder: false,
      isLoadingNewer: false,
      isResolvingJump: false,
      highlightedStableKey: null,
      centerViewportFraction: centerViewportFraction,
      viewportCommandKind: viewportCommandKind,
      viewportCommandGeneration: viewportCommandGeneration,
      isBootstrapping: isBootstrapping,
    );
  }

  ConversationTimelineV2State _loadingState({bool isBootstrapping = true}) {
    return (
      beforeMessages: const <ConversationMessageV2>[],
      afterMessages: const <ConversationMessageV2>[],
      canLoadOlder: false,
      canLoadNewer: false,
      isLoadingOlder: false,
      isLoadingNewer: false,
      isResolvingJump: false,
      highlightedStableKey: null,
      centerViewportFraction: 1.0,
      viewportCommandKind: ConversationTimelineV2ViewportCommandKind.none,
      viewportCommandGeneration: _viewportCommandGeneration,
      isBootstrapping: isBootstrapping,
    );
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
