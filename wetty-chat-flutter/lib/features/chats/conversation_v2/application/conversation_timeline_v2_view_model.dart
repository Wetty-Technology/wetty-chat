import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/application/timeline_viewport_facts.dart';
import 'package:chahua/features/chats/conversation_v2/application/timeline_viewport_effect.dart';
import 'package:chahua/features/chats/models/message_models.dart';

typedef ConversationTimelineV2Identity = ({
  String chatId,
  String? threadRootId,
});

enum ConversationTimelineV2Mode { live, anchored }

typedef ConversationTimelineV2State = ({
  ConversationTimelineV2Mode mode,
  List<ConversationMessageV2> beforeMessages,
  List<ConversationMessageV2> centerMessages,
  List<ConversationMessageV2> afterMessages,
  bool isLoadingOlder,
  bool isLoadingNewer,
  bool isResolvingJump,
  String? highlightedStableKey,
  double centerViewportFraction,
});

class ConversationTimelineV2ViewModel
    extends AsyncNotifier<ConversationTimelineV2State> {
  final ConversationTimelineV2Identity identity;
  LaunchRequest? _initialLaunchRequest;
  final StreamController<TimelineViewportEffect> _effectsController =
      StreamController<TimelineViewportEffect>.broadcast();
  late DateTime _baseNow;
  int _nextOlderSequence = -1;
  int _nextNewerSequence = 50;
  bool _isLoadingOlder = false;
  bool _isLoadingNewer = false;

  ConversationTimelineV2ViewModel(this.identity);

  Stream<TimelineViewportEffect> get effects => _effectsController.stream;

  @override
  Future<ConversationTimelineV2State> build() async {
    ref.onDispose(_effectsController.close);

    _baseNow = DateTime.now().toUtc();

    final initialMessages = List<ConversationMessageV2>.generate(
      50,
      (index) => _fakeMessage(index),
      growable: false,
    );

    return (
      mode: ConversationTimelineV2Mode.anchored,
      beforeMessages: const <ConversationMessageV2>[],
      centerMessages: initialMessages,
      afterMessages: const <ConversationMessageV2>[],
      isLoadingOlder: false,
      isLoadingNewer: false,
      isResolvingJump: false,
      highlightedStableKey: null,
      centerViewportFraction: 0.0,
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
    final currentState = state.asData?.value;
    if (currentState == null) {
      return;
    }

    _maybeLoadFromFacts(currentState, facts);
  }

  void jumpToLatest() {
    _updateState(
      mode: ConversationTimelineV2Mode.live,
      beforeMessages: const <ConversationMessageV2>[],
      centerMessages: _allMessages,
      afterMessages: const <ConversationMessageV2>[],
      isLoadingOlder: false,
      isLoadingNewer: false,
      isResolvingJump: false,
      highlightedStableKey: null,
      centerViewportFraction: 0.0,
    );
    _effectsController.add(const TimelineViewportEffect.revealBottom());
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
      _setResolvingJump(currentState, isResolvingJump: true);
      return;
    }

    _activateSingleMessageCenter(
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
      _setResolvingJump(currentState, isResolvingJump: true);
      return;
    }

    _activateSingleMessageCenter(
      messages,
      targetIndex,
      highlightedStableKey: highlight ? messages[targetIndex].stableKey : null,
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

    _activateSingleMessageCenter(
      messages,
      unreadIndex,
      highlightedStableKey: messages[unreadIndex].stableKey,
      centerViewportFraction: 0.0,
    );
  }

  Future<void> loadOlder() async {
    final currentState = state.asData?.value;
    if (currentState == null || _isLoadingOlder) {
      return;
    }
    _isLoadingOlder = true;

    _updateState(
      mode: currentState.mode,
      beforeMessages: currentState.beforeMessages,
      centerMessages: currentState.centerMessages,
      afterMessages: currentState.afterMessages,
      isLoadingOlder: true,
      isLoadingNewer: currentState.isLoadingNewer,
      isResolvingJump: currentState.isResolvingJump,
      highlightedStableKey: currentState.highlightedStableKey,
      centerViewportFraction: currentState.centerViewportFraction,
    );

    try {
      final latestState = state.asData?.value;
      if (latestState == null) {
        return;
      }

      final olderMessages = List<ConversationMessageV2>.generate(
        10,
        (_) => _fakeMessage(_nextOlderSequence--),
        growable: false,
      ).reversed.toList(growable: false);

      _updateState(
        mode: latestState.mode,
        beforeMessages: [...olderMessages, ...latestState.beforeMessages],
        centerMessages: latestState.centerMessages,
        afterMessages: latestState.afterMessages,
        isLoadingOlder: false,
        isLoadingNewer: latestState.isLoadingNewer,
        isResolvingJump: latestState.isResolvingJump,
        highlightedStableKey: latestState.highlightedStableKey,
        centerViewportFraction: latestState.centerViewportFraction,
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
      mode: currentState.mode,
      beforeMessages: currentState.beforeMessages,
      centerMessages: currentState.centerMessages,
      afterMessages: currentState.afterMessages,
      isLoadingOlder: currentState.isLoadingOlder,
      isLoadingNewer: true,
      isResolvingJump: currentState.isResolvingJump,
      highlightedStableKey: currentState.highlightedStableKey,
      centerViewportFraction: currentState.centerViewportFraction,
    );

    try {
      final latestState = state.asData?.value;
      if (latestState == null) {
        return;
      }

      final newerMessages = List<ConversationMessageV2>.generate(
        10,
        (_) => _fakeMessage(_nextNewerSequence++),
        growable: false,
      );

      _updateState(
        mode: latestState.mode,
        beforeMessages: latestState.beforeMessages,
        centerMessages: latestState.centerMessages,
        afterMessages: [...latestState.afterMessages, ...newerMessages],
        isLoadingOlder: latestState.isLoadingOlder,
        isLoadingNewer: false,
        isResolvingJump: latestState.isResolvingJump,
        highlightedStableKey: latestState.highlightedStableKey,
        centerViewportFraction: latestState.centerViewportFraction,
      );
    } finally {
      _isLoadingNewer = false;
    }
  }

  void _updateState({
    required ConversationTimelineV2Mode mode,
    required List<ConversationMessageV2> beforeMessages,
    required List<ConversationMessageV2> centerMessages,
    required List<ConversationMessageV2> afterMessages,
    required bool isLoadingOlder,
    required bool isLoadingNewer,
    required bool isResolvingJump,
    required String? highlightedStableKey,
    required double centerViewportFraction,
  }) {
    state = AsyncData((
      mode: mode,
      beforeMessages: beforeMessages,
      centerMessages: centerMessages,
      afterMessages: afterMessages,
      isLoadingOlder: isLoadingOlder,
      isLoadingNewer: isLoadingNewer,
      isResolvingJump: isResolvingJump,
      highlightedStableKey: highlightedStableKey,
      centerViewportFraction: centerViewportFraction,
    ));
  }

  void _maybeLoadFromFacts(
    ConversationTimelineV2State currentState,
    TimelineViewportFacts facts,
  ) {
    if (currentState.mode != ConversationTimelineV2Mode.anchored) {
      return;
    }

    if (facts.isNearTop && !currentState.isLoadingOlder) {
      unawaited(loadOlder());
    }
    if (facts.isNearBottom && !currentState.isLoadingNewer) {
      unawaited(loadNewer());
    }
  }

  List<ConversationMessageV2> get _allMessages {
    final currentState = state.asData?.value;
    if (currentState == null) {
      return const <ConversationMessageV2>[];
    }
    return _flattenMessages(currentState);
  }

  List<ConversationMessageV2> _flattenMessages(
    ConversationTimelineV2State state,
  ) {
    return <ConversationMessageV2>[
      ...state.beforeMessages,
      ...state.centerMessages,
      ...state.afterMessages,
    ];
  }

  void _activateSingleMessageCenter(
    List<ConversationMessageV2> messages,
    int targetIndex, {
    required String? highlightedStableKey,
    required double centerViewportFraction,
  }) {
    final targetMessage = messages[targetIndex];

    _updateState(
      mode: ConversationTimelineV2Mode.anchored,
      beforeMessages: messages.take(targetIndex).toList(growable: false),
      centerMessages: <ConversationMessageV2>[targetMessage],
      afterMessages: messages.skip(targetIndex + 1).toList(growable: false),
      isLoadingOlder: false,
      isLoadingNewer: false,
      isResolvingJump: false,
      highlightedStableKey: highlightedStableKey,
      centerViewportFraction: centerViewportFraction,
    );
    _effectsController.add(
      TimelineViewportEffect.resetToCenterOrigin(
        alignment: centerViewportFraction == 0.0
            ? TimelineViewportAlignment.top
            : TimelineViewportAlignment.center,
        highlight: highlightedStableKey != null,
      ),
    );
  }

  void _setResolvingJump(
    ConversationTimelineV2State currentState, {
    required bool isResolvingJump,
  }) {
    _updateState(
      mode: currentState.mode,
      beforeMessages: currentState.beforeMessages,
      centerMessages: currentState.centerMessages,
      afterMessages: currentState.afterMessages,
      isLoadingOlder: currentState.isLoadingOlder,
      isLoadingNewer: currentState.isLoadingNewer,
      isResolvingJump: isResolvingJump,
      highlightedStableKey: currentState.highlightedStableKey,
      centerViewportFraction: currentState.centerViewportFraction,
    );
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
      createdAt: _baseNow.subtract(Duration(minutes: (50 - sequence) * 3)),
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
