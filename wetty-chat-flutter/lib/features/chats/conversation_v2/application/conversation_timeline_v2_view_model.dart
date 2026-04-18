import 'dart:async';
import 'dart:developer';

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

typedef ConversationTimelineV2State = ({
  List<ConversationMessageV2> messages,
  bool isResolvingJump,
  String? highlightedStableKey,
  String? anchorStableKey,
  double? anchorViewportFraction,
});

class ConversationTimelineV2ViewModel
    extends AsyncNotifier<ConversationTimelineV2State> {
  final ConversationTimelineV2Identity identity;
  LaunchRequest? _initialLaunchRequest;
  TimelineViewportFacts? _lastViewportFacts;
  final StreamController<TimelineViewportEffect> _effectsController =
      StreamController<TimelineViewportEffect>.broadcast();
  late DateTime _baseNow;
  int _nextOlderSequence = -1;

  ConversationTimelineV2ViewModel(this.identity);

  Stream<TimelineViewportEffect> get effects => _effectsController.stream;

  @override
  Future<ConversationTimelineV2State> build() async {
    ref.onDispose(_effectsController.close);

    _baseNow = DateTime.now().toUtc();

    return (
      messages: List<ConversationMessageV2>.generate(
        50,
        (index) => _fakeMessage(index),
        growable: false,
      ),
      isResolvingJump: false,
      highlightedStableKey: null,
      anchorStableKey: null,
      anchorViewportFraction: null,
    );
  }

  void initialize(LaunchRequest launchRequest) {
    if (_initialLaunchRequest == launchRequest) {
      return;
    }
    _initialLaunchRequest = launchRequest;
  }

  void onViewportChanged(TimelineViewportFacts facts) {
    final previousFacts = _lastViewportFacts;
    _lastViewportFacts = facts;

    if (previousFacts == null) {
      return;
    }

    if (previousFacts.isNearTop != facts.isNearTop ||
        previousFacts.isNearBottom != facts.isNearBottom) {
      // Placeholder seam for future timeline policy:
      // loading older/newer, pending-live updates, and live-edge decisions.
    }
  }

  void jumpToLatest() {
    _updateState(
      isResolvingJump: false,
      highlightedStableKey: null,
      anchorStableKey: null,
      anchorViewportFraction: null,
    );
    _effectsController.add(const TimelineViewportEffect.revealBottom());
  }

  void jumpToMessage(String stableKey) {
    final currentState = state.asData?.value;
    if (currentState == null) {
      return;
    }

    final hasTargetInCurrentSlice = currentState.messages.any(
      (message) => message.stableKey == stableKey,
    );

    if (!hasTargetInCurrentSlice) {
      _updateState(
        isResolvingJump: true,
        highlightedStableKey: null,
        anchorStableKey: null,
        anchorViewportFraction: null,
      );
      return;
    }

    _updateState(
      isResolvingJump: false,
      highlightedStableKey: stableKey,
      anchorStableKey: stableKey,
      anchorViewportFraction: 0.5,
    );
    _effectsController.add(
      TimelineViewportEffect.revealMessage(
        stableKey,
        alignment: TimelineViewportAlignment.center,
        highlight: true,
      ),
    );
  }

  void loadOlderPreservingAnchor({
    required String? anchorStableKey,
    required double? anchorViewportFraction,
  }) {
    final currentState = state.asData?.value;
    if (currentState == null) {
      return;
    }

    final olderMessages = List<ConversationMessageV2>.generate(
      10,
      (_) => _fakeMessage(_nextOlderSequence--),
      growable: false,
    ).reversed.toList(growable: false);

    log("olderMessages ${olderMessages.map((e) => e.stableKey)}");

    state = AsyncData((
      messages: [...olderMessages, ...currentState.messages],
      isResolvingJump: currentState.isResolvingJump,
      highlightedStableKey: currentState.highlightedStableKey,
      anchorStableKey: anchorStableKey ?? currentState.anchorStableKey,
      anchorViewportFraction:
          anchorViewportFraction ?? currentState.anchorViewportFraction,
    ));
  }

  void _updateState({
    required bool isResolvingJump,
    required String? highlightedStableKey,
    required String? anchorStableKey,
    required double? anchorViewportFraction,
  }) {
    final currentState = state.asData?.value;
    if (currentState == null) {
      return;
    }

    state = AsyncData((
      messages: currentState.messages,
      isResolvingJump: isResolvingJump,
      highlightedStableKey: highlightedStableKey,
      anchorStableKey: anchorStableKey,
      anchorViewportFraction: anchorViewportFraction,
    ));
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
