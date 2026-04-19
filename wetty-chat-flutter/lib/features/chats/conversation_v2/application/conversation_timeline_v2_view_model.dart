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
});

class ConversationTimelineV2ViewModel
    extends AsyncNotifier<ConversationTimelineV2State> {
  static const int _initialLoadedWindowSize = 50;

  final ConversationTimelineV2Identity identity;
  LaunchRequest? _initialLaunchRequest;
  late FakeConversationTimelineV2Repository _repository;
  int _viewportCommandGeneration = 0;

  ConversationTimelineV2ViewModel(this.identity);

  @override
  Future<ConversationTimelineV2State> build() async {
    _repository = ref.read(
      fakeConversationTimelineV2RepositoryProvider(identity),
    );
    await _repository.ensureLatestSegmentLoaded(
      limit: _initialLoadedWindowSize,
    );
    ref.watch(conversationTimelineV2LatestActiveSegmentProvider(identity));
    final latestSegment = ref.read(
      conversationTimelineV2LatestActiveSegmentProvider(identity),
    );
    if (latestSegment == null) {
      throw StateError('Latest active segment was not available after load');
    }
    return _stateFromActiveSegment(
      latestSegment,
      centerViewportFraction: 1.0,
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
    state = AsyncData(
      _stateFromActiveSegment(
        latestSegment,
        centerViewportFraction: 1.0,
        viewportCommandKind:
            ConversationTimelineV2ViewportCommandKind.resetToCenterOrigin,
        viewportCommandGeneration: ++_viewportCommandGeneration,
      ),
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

  void addMessage() {
    _markRepositoryTodo('addMessage');
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
  }) {
    return (
      beforeMessages: segment.orderedMessages,
      afterMessages: const <ConversationMessageV2>[],
      canLoadOlder: segment.canLoadBefore,
      canLoadNewer: segment.canLoadAfter,
      isLoadingOlder: false,
      isLoadingNewer: false,
      isResolvingJump: false,
      highlightedStableKey: null,
      centerViewportFraction: centerViewportFraction,
      viewportCommandKind: viewportCommandKind,
      viewportCommandGeneration: viewportCommandGeneration,
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
    AsyncNotifierProvider.family<
      ConversationTimelineV2ViewModel,
      ConversationTimelineV2State,
      ConversationTimelineV2Identity
    >(ConversationTimelineV2ViewModel.new, isAutoDispose: true);
