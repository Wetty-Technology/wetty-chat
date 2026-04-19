import 'dart:async';

import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/application/timeline_viewport_facts.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/models/message_models.dart';
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
  static const int _fakeHistoryCount = 120;
  static const int _fakePageSize = 10;
  static const int _initialLoadedWindowSize = 50;

  final ConversationTimelineV2Identity identity;
  LaunchRequest? _initialLaunchRequest;
  late DateTime _baseNow;
  late List<ConversationMessageV2> _fakeHistory;
  bool _isLoadingOlder = false;
  bool _isLoadingNewer = false;
  TimelineViewportFacts? _latestViewportFacts;
  int _viewportCommandGeneration = 0;

  ConversationTimelineV2ViewModel(this.identity);

  @override
  Future<ConversationTimelineV2State> build() async {
    _baseNow = DateTime.now().toUtc();
    _fakeHistory = List<ConversationMessageV2>.generate(
      _fakeHistoryCount,
      _fakeMessage,
      growable: false,
    );

    return _buildAnchoredStateAroundHistoryIndex(
      _fakeHistoryCount ~/ 2,
      loadedWindowSize: _initialLoadedWindowSize,
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
    _updateState(
      beforeMessages: _latestWindow,
      afterMessages: const <ConversationMessageV2>[],
      canLoadOlder: _latestWindowStartIndex > 0,
      canLoadNewer: false,
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

    _jumpToCachedOrResolve(
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

    _jumpToCachedOrResolve(
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

    _jumpToCachedOrResolve(
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

    final nextSequence = _messageSequence(_fakeHistory.last) + 1;
    final newMessage = _fakeMessage(nextSequence);
    _fakeHistory = [..._fakeHistory, newMessage];

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

      final startIndex = _loadedStartIndex(latestState);
      final List<ConversationMessageV2> olderMessages;

      if (startIndex > 0) {
        final newStartIndex = (startIndex - _fakePageSize).clamp(
          0,
          _fakeHistory.length,
        );
        olderMessages = _fakeHistory.sublist(newStartIndex, startIndex);
      } else {
        final earliestLoadedMessage = latestState.beforeMessages.isNotEmpty
            ? latestState.beforeMessages.first
            : latestState.afterMessages.first;
        final earliestSequence = _messageSequence(earliestLoadedMessage);
        olderMessages = List<ConversationMessageV2>.generate(
          _fakePageSize,
          (index) => _fakeMessage(earliestSequence - _fakePageSize + index),
          growable: false,
        );
      }

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

      final endIndex = _loadedEndIndex(latestState);
      final newEndExclusive = (endIndex + 1 + _fakePageSize).clamp(
        0,
        _fakeHistory.length,
      );
      final newerMessages = _fakeHistory.sublist(endIndex + 1, newEndExclusive);

      _updateState(
        beforeMessages: latestState.beforeMessages,
        afterMessages: [...latestState.afterMessages, ...newerMessages],
        canLoadOlder: latestState.canLoadOlder,
        canLoadNewer: newEndExclusive < _fakeHistory.length,
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
    final historyIndex = _fakeHistory.indexOf(targetMessage);

    _updateState(
      beforeMessages: messages.take(targetIndex).toList(growable: false),
      afterMessages: messages.skip(targetIndex).toList(growable: false),
      canLoadOlder: true,
      canLoadNewer: historyIndex >= 0 && historyIndex < _fakeHistory.length - 1,
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

  void _jumpToCachedOrResolve(
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

  ConversationTimelineV2State _buildAnchoredStateAroundHistoryIndex(
    int historyIndex, {
    required int loadedWindowSize,
  }) {
    final windowRadius = loadedWindowSize ~/ 2;
    final startIndex = (historyIndex - windowRadius).clamp(
      0,
      _fakeHistory.length - 1,
    );
    final endExclusive = (startIndex + loadedWindowSize).clamp(
      0,
      _fakeHistory.length,
    );
    final correctedStartIndex = (endExclusive - loadedWindowSize).clamp(
      0,
      _fakeHistory.length - 1,
    );

    return (
      beforeMessages: _fakeHistory.sublist(correctedStartIndex, historyIndex),
      afterMessages: _fakeHistory.sublist(historyIndex, endExclusive),
      canLoadOlder: true,
      canLoadNewer: endExclusive < _fakeHistory.length,
      isLoadingOlder: false,
      isLoadingNewer: false,
      isResolvingJump: false,
      highlightedStableKey: null,
      centerViewportFraction: 0.5,
      viewportCommandKind: ConversationTimelineV2ViewportCommandKind.none,
      viewportCommandGeneration: _viewportCommandGeneration,
    );
  }

  int get _latestWindowStartIndex =>
      (_fakeHistory.length - _initialLoadedWindowSize).clamp(
        0,
        _fakeHistory.length,
      );

  List<ConversationMessageV2> get _latestWindow =>
      _fakeHistory.sublist(_latestWindowStartIndex);

  int _loadedStartIndex(ConversationTimelineV2State state) {
    if (state.beforeMessages.isNotEmpty) {
      final index = _fakeHistory.indexOf(state.beforeMessages.first);
      return index >= 0 ? index : 0;
    }
    if (state.afterMessages.isNotEmpty) {
      final index = _fakeHistory.indexOf(state.afterMessages.first);
      return index >= 0 ? index : 0;
    }
    return 0;
  }

  int _loadedEndIndex(ConversationTimelineV2State state) {
    if (state.afterMessages.isNotEmpty) {
      final index = _fakeHistory.indexOf(state.afterMessages.last);
      return index >= 0 ? index : _fakeHistory.length - 1;
    }
    if (state.beforeMessages.isNotEmpty) {
      final index = _fakeHistory.indexOf(state.beforeMessages.last);
      return index >= 0 ? index : _fakeHistory.length - 1;
    }
    return _fakeHistory.length - 1;
  }

  int _messageSequence(ConversationMessageV2 message) {
    final suffix = message.clientGeneratedId.split('-').last;
    return int.tryParse(suffix) ?? 0;
  }

  ConversationMessageV2 _fakeMessage(int sequence) {
    final isMe = sequence.isOdd;
    final sender = Sender(
      uid: isMe ? 1 : 2,
      name: isMe ? 'Me' : 'Alex',
      avatarUrl: null,
      gender: isMe ? 1 : 0,
    );

    final replyPreview = sequence % 9 == 0
        ? ReplyToMessage(
            id: 1000 + sequence,
            message: 'Earlier message preview',
            sender: const Sender(uid: 3, name: 'Taylor'),
          )
        : null;

    final reactions = sequence % 7 == 0
        ? const <ReactionSummary>[
            ReactionSummary(emoji: '👍', count: 2, reactedByMe: true),
          ]
        : const <ReactionSummary>[];

    final threadInfo = sequence % 8 == 0
        ? ThreadInfo(replyCount: 3 + (sequence % 4).abs())
        : null;

    return ConversationMessageV2(
      serverMessageId: sequence >= 0 ? sequence + 1 : null,
      clientGeneratedId:
          'fake-${identity.chatId}-${identity.threadRootId ?? 'chat'}-$sequence',
      sender: sender,
      createdAt: _baseNow.subtract(
        Duration(minutes: (_fakeHistoryCount - sequence) * 3),
      ),
      isEdited: sequence % 11 == 0,
      isDeleted: sequence == 17,
      replyToMessage: replyPreview,
      reactions: reactions,
      threadInfo: threadInfo,
      deliveryState: isMe && sequence > 46
          ? ConversationDeliveryState.confirmed
          : ConversationDeliveryState.sent,
      content: _fakeContent(sequence),
    );
  }

  MessageContent _fakeContent(int sequence) {
    return TextMessageContent(
      text: 'Placeholder v2 message #$sequence for chat ${identity.chatId}',
      mentions: sequence % 13 == 0
          ? const <MentionInfo>[MentionInfo(uid: 9, username: 'casey')]
          : const <MentionInfo>[],
    );
  }
}

final conversationTimelineV2ViewModelProvider =
    AsyncNotifierProvider.family<
      ConversationTimelineV2ViewModel,
      ConversationTimelineV2State,
      ConversationTimelineV2Identity
    >(ConversationTimelineV2ViewModel.new, isAutoDispose: true);
